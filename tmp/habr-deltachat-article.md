# Поднимаем Delta Chat-сервер с блэк-джеком и вебхуками

Telegram долгое время был стандартом де-факто для рабочих уведомлений,
дежурных чатов и мониторинга. После известных событий часть команд
начала искать альтернативы. Я работаю в телекоме, и у нас этот вопрос
встал практически: нужен мессенджер для NOC-дежурств, алертов из
Grafana и внутренней коммуникации, который не зависит от одного вендора
и не блокируется вместе с ним.

Централизованные сервисы — VK Teams, Discord, Slack — решают только
часть проблемы. Правила меняются, аккаунты блокируются, данные лежат
не у вас. Федеративные протоколы интереснее: Matrix, XMPP, и — менее
очевидный выбор — Delta Chat.

В этой статье покажу, как поднять собственный chatmail-сервер на базе
Delta Chat, настроить его в режиме invite-only для организации, и
подключить HTTP webhook для отправки уведомлений из любого сервиса.
Всё это упаковано в Makefile с age-шифрованием секретов.

Код на GitHub: [lazarus-net/delta-notify](https://github.com/lazarus-net/delta-notify).
MIT license.

---

## Почему Delta Chat

Delta Chat работает поверх обычной электронной почты — IMAP и SMTP.
Никакого своего протокола, никакого центрального сервера вендора.
Ваши сообщения идут через почтовый сервер, который контролируете вы.

Для ISP-инженера это важно по одной практической причине: SMTP на
портах 465 и 993 проходит там, где многое другое не проходит.
Это не теоретическое соображение.

E2E шифрование через Autocrypt — не опция, а требование chatmail-сервера.
Сервер просто отклонит незашифрованное сообщение. Ключевой обмен
происходит автоматически при первом контакте через SecureJoin.

Регистрация — без номера телефона. Аккаунт создаётся при первом
подключении Delta Chat к серверу. Можно настроить invite-only:
только по токену.

Upstream: [github.com/chatmail/relay](https://github.com/chatmail/relay).
Активно поддерживается командой DINO — тех же людей, что делают
Gajim и Dino для XMPP. Не заброшенный проект.

---

## Что поднимаем

```
[chatmail relay]  ←── IMAP/SMTP ───→  [Delta Chat клиент]
                                               ↑
[мониторинг]  ──→  POST /webhook  ──→  [delta-notify]  ──→  [DC группа]
[Grafana]
[CI/CD]
```

Два компонента:

**chatmail/relay** — сам почтовый/мессенджер-сервер. Разворачивает
полный стек: Postfix, Dovecot, filtermail (E2EE enforcement),
OpenDKIM, nginx, acmetool (TLS), Iroh relay (P2P), push notifications.
Одна команда — полный деплой.

**delta-notify** — Go-бинарник, принимает HTTP POST и отправляет
сообщение в Delta Chat группу. Несколько сервисов, у каждого свой
токен и своя группа. Написан с нуля, нет внешних зависимостей.

Управление обоими через Makefile.

---

## Разворачиваем chatmail/relay

### Требования

- Debian 12. Другие дистрибутивы — на свой страх.
- VPS с публичным IP. Минимум 1 GB RAM, 10 GB диска.
- Домен. DNS управляется через Cloudflare — автоматизация заточена
  под CF API. Если у вас другой DNS-провайдер, попросите Claude
  адаптировать `chatmail_create_dns` и `chatmail_setup_zone` под ваш API.
  Там несколько десятков строк shell, ничего сложного.

**Порт 25.** Проверьте до покупки VPS. Большинство хостеров закрывают
исходящий порт 25 по умолчанию. Chatmail/relay требует открытый 25.
Проверка с сервера:

```sh
telnet smtp.gmail.com 25
```

Если не отвечает — нужен внешний outbound SMTP relay. chatmail.ini
это поддерживает, но это отдельная настройка.

**PTR-запись.** Обязательно. Без reverse DNS крупные провайдеры
(Gmail в первую очередь) обращаются с вашими письмами с низким доверием.
Ставится в панели управления хостера. Значение — hostname сервера.
Проверка: `dig -x YOUR_SERVER_IP +short`.

### Первоначальная настройка

Клонируем репозиторий, создаём файл настроек:

```sh
git clone https://github.com/lazarus-net/delta-notify
cd delta-notify
cp settings/example/server_settings.mk settings/myserver/server_settings.mk
```

Редактируем `settings/myserver/server_settings.mk`:

```makefile
export deploy_host          := chat.your-domain.example
export deploy_user          := root
export deploy_ssh_identity  := ~/.ssh/id_ed25519
```

Запустите `make` без параметров чтобы увидеть список всех команд.

Дальше — три шага:

```sh
# 1. Клонировать chatmail/relay, создать Python venv
make settings=myserver chatmail_setup_env

# 2. Сгенерировать chatmail.ini для вашего домена
make settings=myserver chatmail_init
# -> копируем chatmail.ini в settings/myserver/chatmail.ini
# -> редактируем: mail_domain, privacy_mail

# 3. Создать все DNS-записи в Cloudflare + задеплоить на сервер
make settings=myserver chatmail_setup_zone
make settings=myserver deploy_chatmail
```

`chatmail_setup_zone` создаёт в Cloudflare все нужные записи:
A, MX, DKIM, SPF, DMARC, SRV, CNAME для mta-sts. Вручную это
минут 20 и гарантированная ошибка где-нибудь в DMARC.

После деплоя — проверка:

```sh
make settings=myserver chatmail_status   # статус сервисов
make settings=myserver chatmail_test     # функциональный тест
```

`chatmail_test` отправляет тестовое письмо через ваш сервер.
Если прошло — всё работает.

### Подводные камни

**resolv.conf после перезагрузки.**
Chatmail/relay в процессе настройки останавливает systemd-resolved
чтобы освободить порт 53. Если после этого `/etc/resolv.conf`
остался симлинком на `/run/systemd/resolve/resolv.conf` — при
следующей загрузке `filtermail-incoming` падает с ошибкой
`Resolve(NotFound)`. Симптом неочевидный: все сервисы запущены,
но входящая почта не доставляется.

Фикс:

```sh
rm /etc/resolv.conf
printf 'nameserver 127.0.0.1\n' > /etc/resolv.conf
```

В нашей версии Makefile это исправлено: `chatmail_disable_resolved_stub`
пишет статичный файл вместо симлинка.

**Старый аккаунт Delta Chat на Gmail.**
Тестировали входящие приглашения через Gmail-аккаунт. Письмо
приходило в Gmail (видно в веб-интерфейсе), но Delta Chat на
iPhone его не показывал. SecureJoin не начинался.

Причина: в Delta Chat есть настройка «Only fetch from DeltaChat folder».
Когда она включена, клиент читает только папку `DeltaChat`. Письма
с нового сервера могут туда не попасть, если Gmail ещё не создал фильтр.

Фикс: Delta Chat → Настройки → Дополнительно → выключить
«Only fetch from DeltaChat folder». После этого клиент находит
письмо в обычном инбоксе. Когда всё заработает — настройку
можно включить обратно.

Разбирались с Claude — симптом неочевидный, в документации
chatmail/relay этот случай не описан.

---

## Invite-only: организационный режим

По умолчанию chatmail-сервер регистрирует аккаунты автоматически
при первом подключении — любой, кто знает адрес сервера, может
создать аккаунт.

Для закрытого использования внутри организации нужен invite-only.
Механизм: CGI-эндпоинт `/new?token=XXX`, токен одноразовый.

Добавляем пользователей в `settings/myserver/chatmail_users.txt`:

```
alice
bob
charlie
```

Генерируем токены и деплоим:

```sh
make settings=myserver generate_chatmail_tokens
make settings=myserver deploy_chatmail_users
```

Показываем invite-URL пользователю:

```sh
make settings=myserver show_chatmail_invite USERNAME=alice
# -> URL: https://chat.your-domain.example/new?token=xxxxx
# -> QR-код для Delta Chat
```

Пользователь открывает URL в Delta Chat (через браузер на телефоне,
не вставкой в чат) → аккаунт создан. Токен больше не работает.

Секреты хранятся age-шифрованными. Скомпрометированный токен
не даёт доступ к уже созданным аккаунтам — каждый токен одноразовый
и генерируется независимо.

---

## delta-notify: HTTP webhook → Delta Chat группа

### Зачем

Хочется слать алерты в Delta Chat группу из Grafana, CI/CD, cron.
Руками неудобно. Нужен HTTP endpoint, который принимает POST и
пересылает текст в группу.

Chatmail/relay — почтовый сервер, у него нет такого API.
Решение: отдельный процесс с аккаунтом бота, который умеет
принимать вебхуки и отправлять сообщения.

### Установка

```sh
cd delta-notify
make settings=myserver build_webhook
# -> собирает бинарник src/deltachat-webhook/deltachat-webhook
#    для linux/amd64
```

### Настройка аккаунтов

Нужны два аккаунта на chatmail-сервере:

- **Бот** — отправляет сообщения и создаёт группы.
- **Админ** — добавляется в каждую группу. Ваш личный аккаунт
  для наблюдения за всеми группами.

```sh
# Вводим credentials бота (аккаунт на вашем chatmail-сервере)
make settings=myserver create_webhook_bot

# Вводим credentials вашего личного аккаунта
make settings=myserver create_deltachat_admin
```

Credentials сохраняются зашифрованными в `settings/myserver/`.

### Регистрация сервиса

Добавляем имя сервиса в `settings/myserver/webhook_services.txt`:

```
grafana
```

Регистрируем:

```sh
make settings=myserver register_webhook_service SERVICE=grafana
# -> генерирует Bearer-токен
# -> создаёт Delta Chat группу на сервере
# -> выводит group_id и invite-ссылку
```

Смотрим токен:

```sh
make settings=myserver show_webhook_token SERVICE=grafana
# -> Service: grafana
# -> Token:   abc123def456...
# -> Usage: curl -X POST ...
```

Получаем QR-код для вступления в группу:

```sh
make settings=myserver webhook_qr SERVICE=grafana
```

Сканируем QR в Delta Chat → попадаем в группу. SecureJoin
завершается автоматически за несколько секунд.

### Деплой

```sh
make settings=myserver deploy_webhook
```

Команда устанавливает `deltachat-rpc-server` на сервер, копирует
бинарник, деплоит конфиги, создаёт и запускает systemd-сервис,
добавляет nginx location block для `/webhook`.

### Отправка уведомлений

```sh
curl -X POST https://chat.your-domain.example/webhook \
  -H "Authorization: Bearer abc123def456..." \
  -H "Content-Type: application/json" \
  -d '{"text": "Deploy на прод завершён"}'
```

Ответ `204 No Content` — сообщение доставлено.

**Интеграция с Grafana:** Contact Point → Webhook → URL и
Authorization header. Payload через template:
`{"text": "{{ $labels.alertname }}: {{ $values.B }}"}`.

### Подводные камни

**Ссылка-приглашение не открывается вставкой.**
URL вида `https://i.delta.chat/#...` вставленный в поле Delta Chat
не работает. Нужно открывать в браузере телефона (deep link в приложение)
или использовать `make webhook_qr` и сканировать QR.

**Блокировка директории аккаунтов.**
Пока `deltachat-webhook serve` запущен, `deltachat-rpc-server`
держит эксклюзивную блокировку на директорию аккаунтов. Параллельно
запустить `create-group` или `invite` нельзя — получите
«Delta Chat is already running».

`make register_webhook_service` и `make webhook_qr` автоматически
останавливают сервис перед командой и запускают обратно. Пауза ~2 секунды.

**Бинарник нельзя скопировать поверх запущенного процесса.**
Linux не позволяет перезаписать исполняемый файл пока он запущен.
`make deploy_webhook` сначала останавливает сервис, потом копирует
бинарник. Если деплоите вручную — не забывайте об этом.

---

## Про архитектуру секретов

Токены, credentials бота, credentials пользователей — всё хранится
в файлах `.age` в директории `settings/`. Их можно коммитить в Git.

[age](https://age-encryption.org) — простая асимметричная криптография.
Публичный ключ (recipients) лежит в репозитории. Приватный ключ —
только у администратора, никуда не коммитится.

```sh
# Генерируем ключ (один раз)
make settings=myserver check_age_ident

# Публичный ключ автоматически попадает в server_age_recipients.txt
make settings=myserver check_age_recipients
```

Приватный ключ нужен только при деплое и при `show_webhook_token`.
На самом сервере plaintext появляется только в момент запуска сервиса —
во временном файле, который удаляется через trap.

Это не паранойя. Это стандартная практика когда в репозитории
несколько человек с разным уровнем доступа.

---

## Что не сделано

Честно: это stripped version. Полная версия работает в продакшене
на нашем сервере. Эта — не тестировалась отдельно от неё.

Что отсутствует:

- **nginx-конфиг в репозитории:** chatmail/relay ставит свой nginx,
  `deploy_webhook` добавляет location block скриптом. Работает если
  nginx уже настроен chatmail/relay. На чистом nginx — нужна ручная
  правка.

- **Мониторинг самого relay:** `make chatmail_status` и внешний
  uptime-монитор настраивайте сами.

- **High availability:** один сервер. Для NOC-алертов нормально.
  Для критической операционной коммуникации — нет.

- **Масштаб:** chatmail/relay не рассчитан на тысячи пользователей.
  Для команды 20-100 человек — работает. Больше — нужны другие решения.

- **Chatmail без Cloudflare:** DNS-автоматизация заточена под CF API.
  Адаптация под другие провайдеры — несложно, но руками.

Если что-то не работает на вашей конфигурации — скорее всего я знаю
почему. Пишите в комментарии.

---

## Про Claude

Код написан с помощью Claude. Я не скрываю этого и не считаю нужным.

Практически это выглядело так: описываешь задачу, получаешь
реализацию, тестируешь, находишь баг (accounts dir lock, stdin pipe
в ssh, resolv.conf после reboot), объясняешь Claude что пошло не так,
получаешь фикс. Итераций пять-шесть на всю систему.

ADR-документация (Architecture Decision Records) сгенерирована вместе
с кодом — каждое архитектурное решение зафиксировано в отдельном файле
с контекстом и альтернативами. Это не для красоты: следующий раз когда
открываешь проект через три месяца или объясняешь коллеге — там написано
почему сделано именно так, а не иначе.

Если вы используете AI-ассистентов в разработке — такой формат
документации сильно сокращает время на введение в контекст.

---

**Репозиторий:** [github.com/lazarus-net/delta-notify](https://github.com/lazarus-net/delta-notify)
MIT license.

Документация chatmail/relay: [chatmail.at/doc/relay](https://chatmail.at/doc/relay)
