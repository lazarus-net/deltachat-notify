# Staging Structure Examples

Author: vld.lazar@proton.me
Generated/edited with Claude
Copyright: vld.lazar@proton.me
Related: ADR #0003

## Typical Server Deployment Stages

```
a001-system-init/       # Hostname, timezone, locale, users
a010-swap/              # Swap file configuration
b020-network/           # Network interfaces, routing
b030-wireguard/         # VPN setup
c040-firewall/          # UFW, iptables rules
c050-ssh-hardening/     # SSH configuration, key-only auth
d060-build-tools/       # gcc, make, development libraries
e070-docker/            # Docker engine (if needed)
e080-nginx/             # Web server
e090-postgresql/        # Database
f100-matrix-synapse/    # Matrix server application
g110-database-init/     # Database schema, initial data
h120-tuning/            # Kernel parameters, limits
z990-monitoring/        # Prometheus, alerting
z995-validation/        # Health checks, smoke tests
```

## Minimal VPS Setup

```
a001-system-init/
a010-swap/
b020-network/
c040-firewall/
c050-ssh-hardening/
e060-nginx/
z990-monitoring/
```

## Complex Multi-Service Server

```
a001-system-init/
  ├── a00-set_hostname.sh
  ├── a10-set_timezone.sh
  └── a20-create_users.sh
a010-swap/
  └── a00-configure_swap.sh
a020-filesystem/
  └── a00-mount_volumes.sh
b030-network/
  ├── a00-configure_interfaces.sh
  └── a10-setup_routing.sh
b040-wireguard/
  └── a00-setup_wireguard.sh
c050-firewall/
  └── a00-configure_ufw.sh
c060-ssh-hardening/
  └── a00-harden_ssh.sh
c070-fail2ban/
  └── a00-install_fail2ban.sh
d080-python/
  └── a00-install_python.sh
d090-nodejs/
  └── a00-install_nodejs.sh
e100-postgresql/
  ├── a00-install_postgresql.sh
  └── a10-configure_postgresql.sh
e110-redis/
  └── a00-install_redis.sh
e120-nginx/
  ├── a00-install_nginx.sh
  └── a10-configure_vhosts.sh
e130-certbot/
  └── a00-setup_ssl_certs.sh
f140-api-backend/
  ├── a00-deploy_api.sh
  └── a10-configure_api.sh
f150-frontend/
  └── a00-deploy_frontend.sh
g160-database-migrate/
  └── a00-run_migrations.sh
g170-data-seed/
  └── a00-seed_initial_data.sh
h180-performance-tuning/
  ├── a00-tune_sysctl.sh
  └── a10-tune_limits.sh
z990-prometheus/
  └── a00-setup_prometheus.sh
z991-grafana/
  └── a00-setup_grafana.sh
z995-backup-config/
  └── a00-configure_backups.sh
z999-health-check/
  └── a00-run_health_checks.sh
```

## Directory Structure Example

```
out/my_chatmail_server/
├── a001-system-init/
│   ├── a00-set_hostname.sh
│   ├── a10-set_timezone.sh
│   └── a20-set_locale.sh
├── a010-swap/
│   └── a00-configure_swap.sh
├── b020-network/
│   ├── a00-configure_interfaces.sh
│   └── a10-setup_dns.sh
├── b030-wireguard/
│   ├── a00-install_wireguard.sh
│   └── a10-configure_wg0.sh
├── c040-firewall/
│   ├── a00-setup_ufw.sh
│   └── a10-configure_rules.sh
├── c050-ssh-hardening/
│   └── a00-harden_ssh.sh
├── e060-nginx/
│   ├── a00-install_nginx.sh
│   └── a10-configure_vhosts.sh
├── f070-matrix/
│   ├── a00-install_synapse.sh
│   └── a10-configure_matrix.sh
└── z990-monitoring/
    └── a00-setup_monitoring.sh
```
