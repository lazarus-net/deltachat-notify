# Feature-Based Generation Examples

Author: vld.lazar@proton.me
Generated/edited with Claude
Copyright: vld.lazar@proton.me
Related: ADR #0004

## Adding a New Feature

**1. Create feature directory:**
```bash
mkdir -p templates/postgresql/e100-postgresql
```

**2. Add templates:**
```bash
# templates/postgresql/e100-postgresql/a00-install_postgresql.sh
# templates/postgresql/e100-postgresql/a10-configure_postgresql.sh
```

**3. Add feature flag:**
```makefile
# In server_settings.mk
export ENABLE_POSTGRESQL := 1
```

**4. Add conditional to Makefile:**
```makefile
ifeq ($(ENABLE_POSTGRESQL),1)
	$(MAKE) _generate_feature FEATURE=postgresql
endif
```

## Foundation Feature Contents

Foundation should include only essential, always-needed setup:

```
templates/foundation/
├── a001-system-init/     # Hostname, timezone, locale, users
├── a010-swap/            # Swap configuration (if ENABLE_SWAP=1)
├── b020-network/         # Basic network interfaces
└── c040-firewall/        # Basic firewall setup
```

Or alternatively, move swap to its own feature if truly optional.

## Feature Categories

Recommended feature organization:

| Feature Directory | Purpose                      | Example Flag        | Stage Range |
|-------------------|------------------------------|---------------------|-------------|
| foundation        | Core system (always)         | N/A (always on)     | a*, b*, c*  |
| swap              | Swap configuration           | ENABLE_SWAP         | a010        |
| nginx             | Web server                   | ENABLE_NGINX        | e060        |
| postgresql        | Database                     | ENABLE_POSTGRESQL   | e100        |
| matrix            | Matrix chat server           | ENABLE_MATRIX       | f070        |
| monitoring        | Prometheus, Grafana          | ENABLE_MONITORING   | z990        |

## Complex Server Example

Server with multiple features enabled:

```makefile
# server_settings.mk
export ENABLE_SWAP       := 1
export ENABLE_NGINX      := 1
export ENABLE_POSTGRESQL := 1
export ENABLE_MATRIX     := 1
export ENABLE_MONITORING := 1
```

Generated output structure:
```
out/my_chatmail_server/
├── a001-system-init/        # foundation
├── a010-swap/               # swap feature
├── b020-network/            # foundation
├── c040-firewall/           # foundation
├── e060-nginx/              # nginx feature
├── e100-postgresql/         # postgresql feature
├── f070-matrix/             # matrix feature
└── z990-monitoring/         # monitoring feature
```

All scripts execute in stage order (a->b->c->e->f->z), regardless of which feature they came from.

## Example Output Structure

For a server with `ENABLE_SWAP=1`, `ENABLE_NGINX=1`, `ENABLE_MATRIX=0`:

```
out/my_chatmail_server/
├── a001-system-init/         # From foundation/
│   ├── a00-set_hostname.sh
│   ├── a10-set_timezone.sh
│   └── a20-set_locale.sh
├── a010-swap/                # From foundation/ (if ENABLE_SWAP=1)
│   └── a00-configure_swap.sh
├── b020-network/             # From foundation/
│   ├── a00-configure_interfaces.sh
│   └── a10-setup_dns.sh
└── e060-nginx/               # From nginx/ (because ENABLE_NGINX=1)
    ├── a00-install_nginx.sh
    └── a10-configure_vhosts.sh

# Note: No f070-matrix/ because ENABLE_MATRIX=0
```
