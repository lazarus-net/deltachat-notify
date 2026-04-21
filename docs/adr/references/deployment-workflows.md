# Remote Deployment Workflows

Author: vld.lazar@proton.me
Generated/edited with Claude
Copyright: vld.lazar@proton.me
Related: ADR #0010

## Basic Deployment Workflow

```bash
# 1. Generate scripts for server
make settings=my_chatmail_server generate_all_scripts

# 2. Preview what would be deployed (dry-run on remote)
make settings=my_chatmail_server deploy_check

# 3. Full deployment (copy + execute)
make settings=my_chatmail_server deploy
```

## Manual Deployment Control

```bash
# Copy scripts only
make settings=my_chatmail_server deploy_copy

# SSH to server and inspect
ssh -i /path/to/key root@server
cd /root/mdist-deploy
ls -la

# Run with dry-run first
./a001-run-all/run-all.sh --dry-run

# Execute full deployment
./a001-run-all/run-all.sh

# Or execute specific stage
./a001-run-all/run-all.sh --stage e060-nginx

# Or resume from specific stage
./a001-run-all/run-all.sh --from e060-nginx
```

## Deployment Settings Example

```makefile
# settings/my_chatmail_server/extended_settings.mk

# Deployment parameters
export deploy_ssh_identity := /root/.ssh/id_ed25519
export deploy_user := root
export deploy_host := $(HOST_IP)  # Inherits from server_settings.mk
export deploy_path := /root/mdist-deploy
```

## SSH Key Setup

```bash
# Generate SSH key for server
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_s03 -C "mdist-s03"

# Copy public key to server
ssh-copy-id -i ~/.ssh/id_ed25519_s03 root@203.0.113.1

# Test connection
ssh -i ~/.ssh/id_ed25519_s03 root@203.0.113.1 'echo "Connection OK"'
```

## Deployment Log Example

```
=========================================
MDIST Deployment Script
=========================================
[INFO] Started: 2025-11-03 20:50:00
[INFO] Deploy directory: /root/mdist-deploy
[INFO] Log file: /root/mdist-deploy/deployment-20251103-205000.log
=========================================

>>> Stage: a010-swap
[INFO] Executing: a00-configure_swap.sh
[INFO] OK a00-configure_swap.sh completed successfully

>>> Stage: e060-nginx
[INFO] Executing: a00-install_nginx.sh
[INFO] OK a00-install_nginx.sh completed successfully
[INFO] Executing: a05-request_letsencrypt.sh
[INFO] OK a05-request_letsencrypt.sh completed successfully
[INFO] Executing: a10-configure_nginx.sh
[INFO] OK a10-configure_nginx.sh completed successfully

=========================================
MDIST Deployment Summary
=========================================
[INFO] Stages processed: 2
[INFO] Scripts executed: 4
[INFO] Completed: 2025-11-03 20:55:30
[INFO] Deployment completed successfully!
```
