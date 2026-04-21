# Swap File Configuration Template

Author: vld.lazar@proton.me
Copyright (C) 2026 example.org
Generated/edited with Claude Code

## Overview

This template provides an idempotent script to configure swap files on Linux servers. The script can be run multiple times safely without causing issues if swap is already properly configured.

## Files

- `a00-configure_swap.sh` - Main swap configuration script (template)

## Template Variables

The following variables are substituted from `extended_settings.mk`:

| Variable    | Description              | Example Values    | Required |
|-------------|--------------------------|-------------------|----------|
| `swap_size` | Size of the swap file    | `1G`, `2G`, `512M`| Yes      |

## Usage

### 1. Configure Settings

Edit your server's `extended_settings.mk` file:

```makefile
export swap_size := 1G
```

### 2. Generate Script

Use the MDIST generation mechanism to generate scripts for all enabled features:

```bash
make settings=my_chatmail_server generate_all_scripts
```

This will generate the swap script (and other enabled features) to:
```
out/my_chatmail_server/a010-swap/a00-configure_swap.sh
```

### 3. Deploy and Execute

Copy the generated script to the target server and run as root:

```bash
sudo ./a00-configure_swap.sh
```

**Options**:
- `--force` - Force recreation of swap file even if current size is larger than requested

```bash
# Force exact size (recreate even if current swap is larger)
sudo ./a00-configure_swap.sh --force
```

## Script Behavior

### Idempotent Operation

The script performs the following checks before making changes:

1. **Swap file existence** - Checks if `/swapfile` exists
2. **Swap activation** - Verifies swap is active in the system
3. **Size verification** - Compares current size with desired size
4. **fstab entry** - Ensures swap is configured to persist across reboots

**Size Verification Logic** (Safe Mode):
- If current swap **< desired size**: Recreate (expand)
- If current swap **> desired size**: Keep existing (safe, warns about mismatch)
- If current swap **== desired size**: No action needed
- With `--force` flag: Always recreate to exact size

This "safe mode" behavior prevents accidentally destroying a larger swap file that may be in use.
To force exact size match, use the `--force` option.

If all checks pass, the script exits without making changes.

### Actions Performed

When configuration is needed, the script will:

1. **Deactivate** existing swap (if active)
2. **Remove** old swap file (if size mismatch or corrupted)
3. **Create** new swap file with `fallocate`
4. **Set permissions** to `0600` for security
5. **Format** with `mkswap`
6. **Activate** with `swapon`
7. **Persist** by adding entry to `/etc/fstab`
8. **Verify** final configuration

### Safety Features

- Requires root privileges
- Checks for required commands before execution
- Uses `set -euo pipefail` for strict error handling
- Validates size parameters before creating files
- Color-coded output for easy monitoring
- Graceful handling of existing configurations

## Requirements

### System Commands

The script requires the following commands to be available:

- `fallocate` - Efficient file allocation
- `mkswap` - Format swap space
- `swapon` - Enable swap
- `swapoff` - Disable swap
- `bc` - Size calculation
- `stat` - File size verification
- `grep`, `sed` - Text processing

These are typically available on all modern Linux distributions.

### Permissions

- Must be run as root or with sudo
- Requires write access to `/swapfile`
- Requires write access to `/etc/fstab`

## Configuration Details

### Swap File Location

Default: `/swapfile`

This is a standard location used by most Linux distributions. The location is hardcoded in the script but can be modified if needed.

### Size Format

Supported formats:
- `512M` or `512MB` - Megabytes
- `1G` or `1GB` - Gigabytes
- `2048K` or `2048KB` - Kilobytes

Examples:
```makefile
export swap_size := 512M   # 512 megabytes
export swap_size := 1G     # 1 gigabyte
export swap_size := 2G     # 2 gigabytes
```

### Recommended Sizes

| RAM Size | Recommended Swap | Use Case                    |
|----------|------------------|-----------------------------|
| < 2 GB   | 2x RAM          | Systems with limited RAM    |
| 2-8 GB   | = RAM           | General purpose servers      |
| > 8 GB   | 0.5x RAM        | High memory servers          |
| Any      | 2 GB minimum    | Minimum for stability        |

For the Matrix server with limited RAM, 1G-2G is recommended.

## fstab Entry

The script adds the following entry to `/etc/fstab`:

```
/swapfile none swap sw 0 0
```

Fields explanation:
- `/swapfile` - Device/file to mount
- `none` - Mount point (N/A for swap)
- `swap` - Filesystem type
- `sw` - Mount options
- `0` - Dump frequency (disabled)
- `0` - fsck pass number (not checked)

## Verification

After running the script, verify with:

```bash
# Check swap status
swapon --show

# Check memory and swap
free -h

# Verify fstab entry
grep swap /etc/fstab
```

Expected output:
```
NAME      TYPE SIZE USED PRIO
/swapfile file   1G   0B   -2
```

## Troubleshooting

### Error: "This script must be run as root"

**Solution**: Run with sudo:
```bash
sudo ./a00-configure_swap.sh
```

### Error: "Required command 'fallocate' not found"

**Solution**: Install required packages:
```bash
# Debian/Ubuntu
sudo apt-get install util-linux bc

# RHEL/CentOS
sudo yum install util-linux bc
```

### Warning: "Swap file exists but is not active"

The script will automatically reactivate the swap file.

### Warning: "Swap file size mismatch"

The script will recreate the swap file with the correct size.

## Integration with MDIST

### Directory Structure

Following ADR #0003 (Output folder staging structure) and ADR #0004 (Feature-based conditional script generation):

```
templates/foundation/a010-swap/
├── a00-configure_swap.sh    # Template script
└── README.md                # This documentation

# Generated output:
out/SERVER_ID/a010-swap/
└── a00-configure_swap.sh    # Expanded script ready to deploy
```

### Feature Flag

Swap is part of the foundation feature, which is always generated. However, individual swap configuration
can be controlled via the ENABLE_SWAP flag in `server_settings.mk`:

```makefile
# Feature flags - set to 1 to enable, 0 to disable
export ENABLE_SWAP := 1
```

### Generation Process

The swap script is automatically generated when running:

```bash
make settings=SERVER_ID generate_all_scripts
```

The generation process:
1. Reads `extended_settings.mk` for `swap_size` variable
2. Expands template using `template_subst.sh`
3. Creates output in `out/SERVER_ID/a010-swap/a00-configure_swap.sh`
4. Makes script executable

## Security Considerations

1. **File Permissions**: Swap file is set to `0600` (read/write for root only)
2. **Root Required**: Script must run as root to modify system configuration
3. **No Encryption**: Standard swap is not encrypted. Consider encrypted swap for sensitive data
4. **Memory Exposure**: Swap may contain sensitive data from RAM

## Performance Notes

- `fallocate` is faster than `dd` for creating swap files
- Swap performance is slower than RAM (obviously)
- SSD-based swap is faster than HDD-based swap
- Excessive swapping ("thrashing") indicates insufficient RAM

## References

- Linux swap space: https://www.kernel.org/doc/html/latest/admin-guide/mm/concepts.html
- fstab format: `man 5 fstab`
- swapon command: `man 8 swapon`
- Swap recommendations: https://help.ubuntu.com/community/SwapFaq

## Changelog

### 2025-10-31 (v1.1)
- Added `--force` flag for explicit recreation
- Implemented safe mode: keeps larger swap files by default
- Only expands swap automatically, never shrinks without `--force`
- Enhanced safety for production systems

### 2025-10-31 (v1.0)
- Initial version created
- Idempotent design with comprehensive checks
- Color-coded logging
- Size verification and comparison
