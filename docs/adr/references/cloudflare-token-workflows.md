# Cloudflare Token Workflows and Security

Author: vld.lazar@proton.me
Generated/edited with Claude
Copyright: vld.lazar@proton.me
Related: ADR #0011

## Complete Workflow: First-time Setup

```bash
# 1. Check if Age identity and recipients are set up
make settings=my_chatmail_server check_age_ident
make settings=my_chatmail_server check_age_recipients

# 2. Create encrypted Cloudflare token
make settings=my_chatmail_server create_cloudflare_token
# Prompts for token, encrypts, validates

# 3. Verify token was created correctly
make settings=my_chatmail_server check_cloudflare_token

# 4. View token content (for debugging)
make settings=my_chatmail_server show_cloudflare_token
```

## Workflow: Update Existing Token

```bash
# Recreate token (will prompt for overwrite confirmation)
make settings=my_chatmail_server create_cloudflare_token
# Answer 'y' to overwrite prompt
# Enter new token value

# Verify new token works
make settings=my_chatmail_server check_cloudflare_token
```

## Workflow: Debug Token Issues

```bash
# Check if token exists and can be decrypted
make settings=my_chatmail_server check_cloudflare_token

# If decryption fails, check recipients file
cat settings/my_chatmail_server/server_age_recipients.txt

# Regenerate recipients if empty (now automatic)
make settings=my_chatmail_server check_age_recipients

# Recreate token with correct recipients
make settings=my_chatmail_server create_cloudflare_token
```

## Scripting: Extract Token Value

```bash
# Extract just the token value for use in scripts
TOKEN=$(make settings=my_chatmail_server show_cloudflare_token | \
        cut -d= -f2 | \
        xargs)

echo "Token: $TOKEN"
```

## Integration with Deployment

```bash
# Full deployment workflow
make settings=my_chatmail_server check_age_ident
make settings=my_chatmail_server check_age_recipients
make settings=my_chatmail_server check_cloudflare_token
make settings=my_chatmail_server generate_all_scripts
make settings=my_chatmail_server deploy
```

## Security Considerations

### Token Input Security
- Token typed with `stty -echo` (input hidden from terminal)
- No echo to terminal history (readline disabled during input)
- Token stored in shell variable (process memory only)
- Memory cleared when make process exits

### Temporary File Security
- Created with `mktemp` (unique, unpredictable name)
- Permissions set to 0600 (owner read/write only)
- Created with `umask 077` (no group/other permissions)
- Trap handler ensures cleanup on exit, interrupt, or termination
- Explicit `rm -f` after encryption completes
- No temporary files left in /tmp after execution

### Encrypted File Security
- Encrypted with Age using server-specific recipient public key
- File stored in `settings/SERVER_ID/` (under version control)
- Can be safely committed to git (encrypted at rest)
- Only decryptable with matching Age identity file
- Identity file stored outside repository in `$(LOCAL_SECRET_PATH)`

### Display Security
- `show_cloudflare_token` outputs to stdout (can be logged)
- Operators should use caution when running in shared/recorded sessions
- Consider: Don't run in screen recordings or shared terminals
- Errors go to stderr to prevent accidental logging with `> file.txt`
