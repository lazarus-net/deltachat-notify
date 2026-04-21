# Feature Flag Examples

Author: vld.lazar@proton.me
Generated/edited with Claude
Copyright: vld.lazar@proton.me
Related: ADR #0005

## Complete Server Settings

```makefile
# Server settings for S03-Dev-Nul-Matrix
# Author: vld.lazar@proton.me
# Copyright (C) 2026 example.org

export SERVER_ID=my_chatmail_server
export HOST_NAME=matrix.example.org
export HOST_IP=203.0.113.1
export ADMIN_EMAIL=vld.lazar@proton.me

export LOCAL_SECRET_PATH=/home/a2/pswd/mdist/$(SERVER_ID)
export LOCAL_AGE_IDENTITY_FN=$(LOCAL_SECRET_PATH)/age_key_$(SERVER_ID).txt

# Feature flags - set to 1 to enable, 0 to disable
# Foundation features
export ENABLE_SWAP       := 1

# Web services
export ENABLE_NGINX      := 0
export ENABLE_APACHE     := 0

# Application servers
export ENABLE_MATRIX     := 1

# Databases
export ENABLE_POSTGRESQL := 0
export ENABLE_MYSQL      := 0
export ENABLE_REDIS      := 0

# Monitoring
export ENABLE_PROMETHEUS := 0
export ENABLE_GRAFANA    := 0
```

## Adding a New Feature

**Step 1**: Create feature template directory
```bash
mkdir -p templates/redis/e090-redis
```

**Step 2**: Add feature flag to all server settings
```makefile
# In settings/*/server_settings.mk
export ENABLE_REDIS := 0  # Default: disabled
```

**Step 3**: Add conditional to Makefile (if optional)
```makefile
ifeq ($(ENABLE_REDIS),1)
	$(MAKE) _generate_feature FEATURE=redis
endif
```

**Step 4**: Enable for specific servers
```makefile
# In settings/production_server/server_settings.mk
export ENABLE_REDIS := 1  # Enable for production
```

## Validation Script (Future)

```bash
#!/bin/sh
# scripts/validate_feature_flags.sh

for settings in settings/*/server_settings.mk; do
    echo "Checking $settings..."

    # Check all ENABLE_* flags have valid values
    invalid=$(grep '^export ENABLE_' "$settings" | \
              grep -v ':= [01]$')

    if [ -n "$invalid" ]; then
        echo "ERROR: Invalid feature flags:"
        echo "$invalid"
        exit 1
    fi
done

echo "All feature flags valid"
```

## Common Defaults Pattern (Future Enhancement)

```makefile
# settings/common_defaults.mk
# Default feature flags for all servers

export ENABLE_SWAP       ?= 1  # Usually want swap
export ENABLE_NGINX      ?= 0
export ENABLE_MATRIX     ?= 0
export ENABLE_POSTGRESQL ?= 0

# Then in server_settings.mk:
-include ../common_defaults.mk

# Override specific flags
export ENABLE_MATRIX := 1  # This server needs Matrix
```
