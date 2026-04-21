#!/usr/bin/make
#
# MDIST - make base simplified CDIST
ROOT_PATH := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

SETTINGS_PATH := $(ROOT_PATH)/settings
SCRIPTS       := $(ROOT_PATH)/scripts
TEMPLATES     := $(ROOT_PATH)/templates

SERVER_ID ?= my_chatmail_server

SETTINGS ?= $(SERVER_ID)
settings ?= UNDEFINED
Settings ?= UNDEFINED

ifneq ("$(settings)","UNDEFINED")
	SETTINGS := $(settings)
endif

ifneq ("$(Settings)","UNDEFINED")
	SETTINGS := $(Settings)
endif

SERVER_SETTINGS_PATH        := $(SETTINGS_PATH)/$(SETTINGS)
SERVER_SETTINGS_FN          := $(SERVER_SETTINGS_PATH)/server_settings.mk
SERVER_EXTENDED_SETTINGS_FN := $(SERVER_SETTINGS_PATH)/extended_settings.mk
SERVER_AGE_RECIPIENTS_FN    ?= $(SERVER_SETTINGS_PATH)/server_age_recipients.txt
SERVER_CLOUDFLAIR_ZONE_EDIT_TOKEN_AGE_FN ?= $(SERVER_SETTINGS_PATH)/cloudflare_token.age
SERVER_CLOUDFLARE_KV_TOKEN_AGE_FN       ?= $(SERVER_SETTINGS_PATH)/cloudflare_kv_token.age

# Shared (account-level) secrets - not per-server
CF_SHARED_SETTINGS_PATH     := $(SETTINGS_PATH)/shared
CF_SHARED_AGE_RECIPIENTS_FN := $(CF_SHARED_SETTINGS_PATH)/age_recipients.txt
CF_PURGE_ALL_TOKEN_AGE_FN   := $(CF_SHARED_SETTINGS_PATH)/cloudflare_purge_all_token.age
CF_PAGES_TOKEN_AGE_FN       := $(CF_SHARED_SETTINGS_PATH)/cloudflare_pages_token.age
CF_DNS_TOKEN_AGE_FN         := $(CF_SHARED_SETTINGS_PATH)/cloudflare_dns_token.age
LOCAL_SHARED_AGE_IDENTITY_FN := $(HOME)/pswd/mdist/shared/age_key_shared.txt
OUT_PATH                    := $(ROOT_PATH)/out/$(SETTINGS)

# Local secrets path (not committed to version control)
# Defined before includes so server_settings.mk can reference it
LOCAL_SECRET_PATH           ?= $(HOME)/pswd/mdist/$(SETTINGS)
LOCAL_AGE_IDENTITY_FN       ?= $(LOCAL_SECRET_PATH)/age_key_$(SETTINGS).txt
letsencrypt_age_identity_path ?= /root/.config/age/mdist-identity.txt

# Include server settings to get feature flags
-include $(SERVER_SETTINGS_FN)
-include $(SERVER_EXTENDED_SETTINGS_FN)

## Rules

.PHONY: all help help_all dummy

all:: check_all help

### Check preconditions. Ensure that all needed path and files are created.
check_all:: check_deps  check_age_ident check_age_recipients

## ---: Check configurations
## ---

.ONESHELL:
## Show configured servers (use as settings parameter value)
ls_servers::
	@echo "Known server configurations:"
	@ls -1 $(SETTINGS_PATH)

.ONESHELL:
## Show settings data for the specific server: make settings=XXXX ls_settings
ls_settings::
	@echo "========================================="
	echo "==> Server Configuration: $(SETTINGS)"
	echo "========================================="
	echo "Settings file: $(SERVER_SETTINGS_FN)"
	echo ""
	echo "Exported variables:"
	echo "-------------------"
	@grep '^export' $(SERVER_SETTINGS_FN) | sed 's/^export /  /' | sed 's/:=/=/'
	echo ""

.ONESHELL:
## List all available features
ls_features::
	@echo "Available features:"
	echo ""
	for feature_dir in $(TEMPLATES)/*/; do
		[ -d "$$feature_dir" ] || continue
		feature=$$(basename "$$feature_dir")
		echo "  $$feature"
		# Show stages in this feature
		for stage_dir in $$feature_dir/*/; do
			[ -d "$$stage_dir" ] || continue
			stage=$$(basename "$$stage_dir")
			case "$$stage" in
				[a-z][0-9][0-9][0-9]-*)
					echo "    - $$stage"
			;;
			esac
		done
		echo ""
	done

.ONESHELL:
## Show enabled features for the server: make settings=XXXX ls_enabled_features
ls_enabled_features::
	@echo "========================================="
	echo "==> Enabled features for: $(SETTINGS)"
	echo "========================================="
	echo ""
	echo "Feature flags:"
	echo "--------------"
	grep '^export ENABLE_' $(SERVER_SETTINGS_FN) | sed 's/^export /  /' | sed 's/:=/=/'
	echo ""

## ---
## ---: Control Claudflare Tokens
## ---

.ONESHELL:
# Create Age-encrypted Cloudflare API token interactively: settings=XXXX
create_cloudflare_token:: check_age_ident check_age_recipients
	@cloudflare_token_file="$(SERVER_CLOUDFLAIR_ZONE_EDIT_TOKEN_AGE_FN)"
	echo "========================================="
	echo "==> Create Cloudflare API Token File"
	echo "========================================="
	echo ""
	echo "This will create an Age-encrypted Cloudflare API token (plain format)."
	echo "A certbot-formatted version is generated during 'make generate_all_scripts'."
	echo ""
	echo "Prerequisites:"
	echo "  1. Go to https://dash.cloudflare.com/profile/api-tokens"
	echo "  2. Create token with 'Zone:DNS:Edit' permissions for your domain"
	echo "  3. Copy the token value"
	echo ""
	if [ -f "$$cloudflare_token_file" ]; then
		echo "WARNING: File already exists: $$cloudflare_token_file"
		printf "Overwrite? [y/N]: "
		read confirm
		if [ "$$confirm" != "y" ] && [ "$$confirm" != "Y" ]; then
			echo "Cancelled."
			exit 0
		fi
		echo ""
	fi
	echo "Enter your Cloudflare API token (input will be hidden):"
	stty -echo
	read token
	stty echo
	echo ""
	if [ -z "$$token" ]; then
		echo "ERROR: Token cannot be empty"
		exit 1
	fi
	echo "Creating encrypted token file..."
	temp_file=$$(mktemp)
	trap 'rm -f $$temp_file' EXIT INT TERM
	printf "%s" "$$token" > "$$temp_file"
	chmod 600 "$$temp_file"
	umask 077
	age -R "$(SERVER_AGE_RECIPIENTS_FN)" -o "$$cloudflare_token_file" "$$temp_file"
	rm -f "$$temp_file"
	echo ""
	echo "========================================="
	echo "Success!"
	echo "========================================="
	echo "Encrypted token saved to: $$cloudflare_token_file"
	echo ""
	echo "Testing decryption..."
	if age -d -i "$(LOCAL_AGE_IDENTITY_FN)" "$$cloudflare_token_file" >/dev/null 2>&1; then
		echo "Decryption test: PASSED"
	else
		echo "WARNING: Decryption test FAILED - check your Age identity"
	fi
	echo ""
	echo "Note: Run 'make settings=$(SETTINGS) generate_all_scripts' to generate"
	echo "      the certbot-formatted version for Let's Encrypt automation."
	echo ""

.ONESHELL:
## Show decrypted Cloudflare token content: settings=XXXX
show_cloudflare_token:: check_age_ident check_age_recipients
	@cloudflare_token_file="$(SERVER_SETTINGS_PATH)/cloudflare_token.age"
	if [ ! -f "$$cloudflare_token_file" ]; then
		echo "ERROR: Cloudflare token file not found: $$cloudflare_token_file" >&2
		exit 1
	fi
	if ! age -d -i "$(LOCAL_AGE_IDENTITY_FN)" "$$cloudflare_token_file"; then
		echo "" >&2
		echo "ERROR: Failed to decrypt Cloudflare token file" >&2
		echo "File: $$cloudflare_token_file" >&2
		echo "Identity: $(LOCAL_AGE_IDENTITY_FN)" >&2
		exit 1
	fi
	echo ""

.ONESHELL:
## Create Age-encrypted Cloudflare KV API token (Workers KV Storage:Edit): settings=XXXX
create_cloudflare_kv_token:: check_age_ident check_age_recipients
	@kv_token_file="$(SERVER_CLOUDFLARE_KV_TOKEN_AGE_FN)"
	echo "========================================="
	echo "==> Create Cloudflare KV API Token File"
	echo "========================================="
	echo ""
	echo "Prerequisites:"
	echo "  1. Go to https://dash.cloudflare.com/profile/api-tokens"
	echo "  2. Create token with 'Account: Workers KV Storage: Edit' permission"
	echo "  3. Copy the token value"
	echo ""
	if [ -f "$$kv_token_file" ]; then
		echo "WARNING: File already exists: $$kv_token_file"
		printf "Overwrite? [y/N]: "
		read confirm
		if [ "$$confirm" != "y" ] && [ "$$confirm" != "Y" ]; then
			echo "Cancelled."
			exit 0
		fi
		echo ""
	fi
	echo "Enter your Cloudflare KV API token (input will be hidden):"
	stty -echo
	read token
	stty echo
	echo ""
	if [ -z "$$token" ]; then
		echo "ERROR: Token cannot be empty"
		exit 1
	fi
	echo "Creating encrypted token file..."
	temp_file=$$(mktemp)
	trap 'rm -f $$temp_file' EXIT INT TERM
	printf "%s" "$$token" > "$$temp_file"
	chmod 600 "$$temp_file"
	umask 077
	age -R "$(SERVER_AGE_RECIPIENTS_FN)" -o "$$kv_token_file" "$$temp_file"
	rm -f "$$temp_file"
	echo ""
	echo "========================================="
	echo "Success!"
	echo "========================================="
	echo "Encrypted token saved to: $$kv_token_file"
	echo ""
	echo "Testing decryption..."
	if age -d -i "$(LOCAL_AGE_IDENTITY_FN)" "$$kv_token_file" >/dev/null 2>&1; then
		echo "Decryption test: PASSED"
	else
		echo "WARNING: Decryption test FAILED - check your Age identity"
	fi
	echo ""

.ONESHELL:
## Show decrypted Cloudflare KV token content: settings=XXXX
show_cloudflare_kv_token:: check_age_ident
	@kv_token_file="$(SERVER_CLOUDFLARE_KV_TOKEN_AGE_FN)"
	if [ ! -f "$$kv_token_file" ]; then
		echo "ERROR: KV token file not found: $$kv_token_file" >&2
		exit 1
	fi
	if ! age -d -i "$(LOCAL_AGE_IDENTITY_FN)" "$$kv_token_file"; then
		echo "" >&2
		echo "ERROR: Failed to decrypt KV token file" >&2
		echo "File: $$kv_token_file" >&2
		echo "Identity: $(LOCAL_AGE_IDENTITY_FN)" >&2
		exit 1
	fi
	echo ""

.ONESHELL:
## Store encrypted Cloudflare cache-purge-all token (account-wide, no settings= needed)
create_cf_purge_all_token:
	@token_file="$(CF_PURGE_ALL_TOKEN_AGE_FN)"
	recipients_file="$(CF_SHARED_AGE_RECIPIENTS_FN)"
	identity_file="$(LOCAL_SHARED_AGE_IDENTITY_FN)"
	echo "========================================="
	echo "==> Store CF Cache Purge All Token"
	echo "========================================="
	echo ""
	if [ ! -f "$$recipients_file" ]; then
		echo "ERROR: Recipients file not found: $$recipients_file" >&2
		exit 1
	fi
	if [ ! -f "$$identity_file" ]; then
		echo "ERROR: Age identity not found: $$identity_file" >&2
		exit 1
	fi
	if [ -f "$$token_file" ]; then
		echo "WARNING: File already exists: $$token_file"
		printf "Overwrite? [y/N] "
		read answer
		[ "$$answer" = "y" ] || [ "$$answer" = "Y" ] || { echo "Aborted."; exit 0; }
	fi
	temp_file=$$(mktemp)
	trap "rm -f $$temp_file" EXIT
	printf "Paste Cloudflare API token (input hidden): "
	stty -echo
	read cf_token
	stty echo
	printf "\n"
	[ -n "$$cf_token" ] || { echo "ERROR: Token cannot be empty" >&2; exit 1; }
	printf "%s" "$$cf_token" > "$$temp_file"
	age -R "$$recipients_file" -o "$$token_file" "$$temp_file"
	echo "Encrypted token saved to: $$token_file"
	echo ""
	echo "Verifying decryption..."
	if age -d -i "$$identity_file" "$$token_file" >/dev/null 2>&1; then
		echo "OK: Decryption verified."
	else
		echo "WARNING: Decryption test FAILED - check your Age identity"
	fi
	echo ""

.ONESHELL:
## Show decrypted Cloudflare cache-purge-all token (no settings= needed)
show_cf_purge_all_token:
	@token_file="$(CF_PURGE_ALL_TOKEN_AGE_FN)"
	identity_file="$(LOCAL_SHARED_AGE_IDENTITY_FN)"
	if [ ! -f "$$token_file" ]; then
		echo "ERROR: Token file not found: $$token_file" >&2
		exit 1
	fi
	if ! age -d -i "$$identity_file" "$$token_file"; then
		echo "" >&2
		echo "ERROR: Failed to decrypt token file" >&2
		echo "File: $$token_file" >&2
		echo "Identity: $$identity_file" >&2
		exit 1
	fi
	echo ""

.ONESHELL:
## Store encrypted Cloudflare Pages token (account-wide, no settings= needed)
create_cf_pages_token:
	@token_file="$(CF_PAGES_TOKEN_AGE_FN)"
	recipients_file="$(CF_SHARED_AGE_RECIPIENTS_FN)"
	identity_file="$(LOCAL_SHARED_AGE_IDENTITY_FN)"
	echo "========================================="
	echo "==> Store CF Pages Token (account-wide)"
	echo "========================================="
	echo ""
	if [ ! -f "$$recipients_file" ]; then
		echo "ERROR: Recipients file not found: $$recipients_file" >&2
		exit 1
	fi
	if [ ! -f "$$identity_file" ]; then
		echo "ERROR: Age identity not found: $$identity_file" >&2
		exit 1
	fi
	if [ -f "$$token_file" ]; then
		echo "WARNING: File already exists: $$token_file"
		printf "Overwrite? [y/N] "
		read answer
		[ "$$answer" = "y" ] || [ "$$answer" = "Y" ] || { echo "Aborted."; exit 0; }
	fi
	temp_file=$$(mktemp)
	trap "rm -f $$temp_file" EXIT
	printf "Paste Cloudflare Pages token (input hidden): "
	stty -echo
	read cf_token
	stty echo
	printf "\n"
	[ -n "$$cf_token" ] || { echo "ERROR: Token cannot be empty" >&2; exit 1; }
	printf "%s" "$$cf_token" > "$$temp_file"
	age -R "$$recipients_file" -o "$$token_file" "$$temp_file"
	echo "Encrypted token saved to: $$token_file"
	echo ""
	echo "Verifying decryption..."
	if age -d -i "$$identity_file" "$$token_file" >/dev/null 2>&1; then
		echo "OK: Decryption verified."
	else
		echo "WARNING: Decryption test FAILED - check your Age identity"
	fi
	echo ""

.ONESHELL:
## Show decrypted Cloudflare Pages token (no settings= needed)
show_cf_pages_token:
	@token_file="$(CF_PAGES_TOKEN_AGE_FN)"
	identity_file="$(LOCAL_SHARED_AGE_IDENTITY_FN)"
	if [ ! -f "$$token_file" ]; then
		echo "ERROR: Token file not found: $$token_file" >&2
		exit 1
	fi
	if ! age -d -i "$$identity_file" "$$token_file"; then
		echo "" >&2
		echo "ERROR: Failed to decrypt token file" >&2
		echo "File: $$token_file" >&2
		echo "Identity: $$identity_file" >&2
		exit 1
	fi
	echo ""

.ONESHELL:
## Store encrypted Cloudflare DNS token (account-wide DNS:Edit, no settings= needed)
create_cf_dns_token:
	@token_file="$(CF_DNS_TOKEN_AGE_FN)"
	recipients_file="$(CF_SHARED_AGE_RECIPIENTS_FN)"
	identity_file="$(LOCAL_SHARED_AGE_IDENTITY_FN)"
	echo "========================================="
	echo "==> Store CF DNS Token (account-wide)"
	echo "========================================="
	echo ""
	if [ ! -f "$$recipients_file" ]; then
		echo "ERROR: Recipients file not found: $$recipients_file" >&2; exit 1
	fi
	if [ ! -f "$$identity_file" ]; then
		echo "ERROR: Age identity not found: $$identity_file" >&2; exit 1
	fi
	if [ -f "$$token_file" ]; then
		echo "WARNING: File already exists: $$token_file"
		printf "Overwrite? [y/N] "
		read answer
		[ "$$answer" = "y" ] || [ "$$answer" = "Y" ] || { echo "Aborted."; exit 0; }
	fi
	temp_file=$$(mktemp)
	trap "rm -f $$temp_file" EXIT
	printf "Paste Cloudflare DNS token (input hidden): "
	stty -echo
	read cf_token
	stty echo
	printf "\n"
	[ -n "$$cf_token" ] || { echo "ERROR: Token cannot be empty" >&2; exit 1; }
	printf "%s" "$$cf_token" > "$$temp_file"
	age -R "$$recipients_file" -o "$$token_file" "$$temp_file"
	echo "Encrypted token saved to: $$token_file"
	echo ""
	echo "Verifying decryption..."
	if age -d -i "$$identity_file" "$$token_file" >/dev/null 2>&1; then
		echo "OK: Decryption verified."
	else
		echo "WARNING: Decryption test FAILED - check your Age identity"
	fi
	echo ""

.ONESHELL:
## Show decrypted Cloudflare DNS token (no settings= needed)
show_cf_dns_token:
	@token_file="$(CF_DNS_TOKEN_AGE_FN)"
	identity_file="$(LOCAL_SHARED_AGE_IDENTITY_FN)"
	if [ ! -f "$$token_file" ]; then
		echo "ERROR: Token file not found: $$token_file" >&2; exit 1
	fi
	if ! age -d -i "$$identity_file" "$$token_file"; then
		echo "" >&2
		echo "ERROR: Failed to decrypt token" >&2
		echo "File: $$token_file" >&2
		echo "Identity: $$identity_file" >&2
		exit 1
	fi
	echo ""

.ONESHELL:
## Validate Cloudflare token Age-encrypted file exists and can be decrypted
check_cloudflare_token::
	@cloudflare_token_file="$(SERVER_CLOUDFLAIR_ZONE_EDIT_TOKEN_AGE_FN)"
	echo "==> Checking Cloudflare API token file for NGINX..."
	echo "    Token file: $$cloudflare_token_file"
	echo "    Identity: $(LOCAL_AGE_IDENTITY_FN)"
	echo ""
	if [ ! -f "$$cloudflare_token_file" ]; then
		echo "ERROR: Cloudflare token file not found!"
		echo ""
		echo "Expected location: $$cloudflare_token_file"
		echo ""
		echo "To create the encrypted token file, run:"
		echo "  make settings=$(SETTINGS) create_cloudflare_token"
		echo ""
		echo "This will interactively prompt you for your Cloudflare API token."
		echo ""
		echo "The token needs 'Zone:DNS:Edit' permissions and can be obtained from:"
		echo "  https://dash.cloudflare.com/profile/api-tokens"
		echo ""
		exit 1
	fi
	echo "    File exists: YES"
	echo "    Testing decryption..."
	if ! age -d -i "$(LOCAL_AGE_IDENTITY_FN)" "$$cloudflare_token_file" >/dev/null 2>&1; then
		echo "    Decryption: FAILED"
		echo ""
		echo "ERROR: Cannot decrypt Cloudflare token file!"
		echo ""
		echo "Possible causes:"
		echo "  - File was encrypted with wrong recipient key"
		echo "  - Identity file $(LOCAL_AGE_IDENTITY_FN) is incorrect"
		echo "  - File is corrupted"
		echo ""
		echo "To recreate the token file, run:"
		echo "  make settings=$(SETTINGS) create_cloudflare_token"
		echo ""
		exit 1
	fi
	echo "    Decryption: SUCCESS"
	echo ""
	echo "Cloudflare token validation passed."
	echo ""

## ---
.ONESHELL:

## Add custom domain to CF Pages project (idempotent): settings=XXXX
cf_pages_set_domain::
	@echo "========================================="
	echo "==> Set CF Pages Domain: $(cf_pages_domain)"
	echo "========================================="
	$(SCRIPTS)/cf_pages_set_domain.sh \
		"$(cf_account_id)" \
		"$(cf_pages_project)" \
		"$(cf_pages_domain)" \
		"$(CF_PAGES_TOKEN_AGE_FN)" \
		"$(LOCAL_SHARED_AGE_IDENTITY_FN)"

## Deploy static site to Cloudflare Pages (production): settings=XXXX
cf_pages_deploy_preview:: $(CF_PAGES_DEPLOY_BIN)
	$(CF_PAGES_DEPLOY_BIN) \
		"$(cf_account_id)" \
		"$(cf_pages_project)" \
		"$(cf_pages_site_dir)" \
		"$(CF_PAGES_TOKEN_AGE_FN)" \
		"$(LOCAL_SHARED_AGE_IDENTITY_FN)" \
		"preview"

## Create project and attach domain (one-time setup): settings=XXXX
cf_pages_setup:: cf_pages_create_project cf_pages_set_domain

.ONESHELL:
## Take site offline - remove custom domain from CF Pages project: settings=XXXX
## Project and content remain intact. Re-enable with cf_pages_enable.
cf_pages_disable::
	@echo "========================================="
	echo "==> Disable CF Pages: $(cf_pages_domain)"
	echo "========================================="
	$(SCRIPTS)/cf_pages_remove_domain.sh \
		"$(cf_account_id)" \
		"$(cf_pages_project)" \
		"$(cf_pages_domain)" \
		"$(CF_PAGES_TOKEN_AGE_FN)" \
		"$(LOCAL_SHARED_AGE_IDENTITY_FN)"

## Re-attach custom domain to CF Pages project (re-enable after disable): settings=XXXX
cf_pages_enable:: cf_pages_set_domain

.ONESHELL:
## Delete all preview branch deployments (removes preview.PROJECT.pages.dev): settings=XXXX
cf_pages_delete_preview::
	@echo "========================================="
	echo "==> Delete Preview Deployments: $(cf_pages_project)"
	echo "========================================="
	$(SCRIPTS)/cf_pages_delete_preview.sh \
		"$(cf_account_id)" \
		"$(cf_pages_project)" \
		"$(CF_PAGES_TOKEN_AGE_FN)" \
		"$(LOCAL_SHARED_AGE_IDENTITY_FN)"

.ONESHELL:
## Purge all Cloudflare cache for the zone: settings=XXXX
cf_purge_cache::
	@echo "========================================="
	echo "==> Purge CF Cache: $(cf_pages_domain)"
	echo "========================================="
	token_file="$(CF_PURGE_ALL_TOKEN_AGE_FN)"
	identity_file="$(LOCAL_SHARED_AGE_IDENTITY_FN)"
	if [ ! -f "$$token_file" ]; then
		echo "ERROR: Purge token not found: $$token_file" >&2
		echo "Run: make create_cf_purge_all_token" >&2
		exit 1
	fi
	token=$$(age -d -i "$$identity_file" "$$token_file") || { \
		echo "ERROR: Failed to decrypt purge token" >&2; exit 1; }
	result=$$(curl -s -X POST \
		"https://api.cloudflare.com/client/v4/zones/$(cf_zone_id)/purge_cache" \
		-H "Authorization: Bearer $$token" \
		-H "Content-Type: application/json" \
		--data '{"purge_everything":true}')
	echo "$$result" | grep -q '"success":true' && \
		echo "Cache purged successfully." || \
		{ echo "ERROR: Purge failed: $$result" >&2; exit 1; }

## ---

## ---
.ONESHELL:
## Generate all configuration scripts based on enabled features
generate_all_scripts::
	@echo "========================================="
	echo "==> Generating scripts for: $(SETTINGS)"
	echo "========================================="
	mkdir -p $(OUT_PATH)
	# Always generate foundation
	$(MAKE) _generate_feature FEATURE=foundation
	# Generate optional features based on flags
	if [ "$(ENABLE_NGINX)" = "1" ]; then
		$(MAKE) _generate_feature FEATURE=nginx
		# Generate certbot-formatted Cloudflare token if plain token exists
		if [ -f "$(SERVER_SETTINGS_PATH)/cloudflare_token.age" ]; then
			mkdir -p "$(OUT_PATH)/secrets"
			echo "  Generating certbot-formatted Cloudflare token..."
			temp_plain=$$(mktemp)
			temp_formatted=$$(mktemp)
			trap 'rm -f $$temp_plain $$temp_formatted' EXIT INT TERM
			age -d -i "$(LOCAL_AGE_IDENTITY_FN)" "$(SERVER_SETTINGS_PATH)/cloudflare_token.age" > "$$temp_plain" 2>/dev/null || { \
				echo "  ERROR: Failed to decrypt cloudflare_token.age" >&2; \
				echo "  Run: make settings=$(SETTINGS) create_cloudflare_token" >&2; \
				exit 1; \
			}
			printf "dns_cloudflare_api_token = %s" "$$(cat $$temp_plain)" > "$$temp_formatted"
			age -R "$(SERVER_AGE_RECIPIENTS_FN)" -o "$(OUT_PATH)/secrets/cloudflare_token_nginx.age" "$$temp_formatted" 2>/dev/null || { \
				echo "  ERROR: Failed to encrypt certbot-formatted token" >&2; \
				exit 1; \
			}
			rm -f "$$temp_plain" "$$temp_formatted"
			echo "  Created cloudflare_token_nginx.age for certbot"
		fi
	fi
	if [ "$(ENABLE_NTFY)" = "1" ]; then
		$(MAKE) _generate_feature FEATURE=ntfy
	fi
	echo ""
	echo "========================================="
	echo "Scripts generated in: $(OUT_PATH)"
	echo "========================================="

.ONESHELL:
### Internal target to generate scripts for a single feature
_generate_feature:
	@echo "  Generating feature: $(FEATURE)..."
	feature_path="$(TEMPLATES)/$(FEATURE)"
	if [ ! -d "$$feature_path" ]; then
		echo "    WARNING: Feature directory not found: $$feature_path"
		exit 0
	fi
	# Process each stage directory within the feature
	for stage_dir in $$feature_path/*/; do
		[ -d "$$stage_dir" ] || continue
		stage_name=$$(basename "$$stage_dir")
		# Skip non-stage directories (like 'age')
		case "$$stage_name" in
			[a-z][0-9][0-9][0-9]-*)
				echo "    Stage: $$stage_name"
				mkdir -p "$(OUT_PATH)/$$stage_name"
				# Process each script template in the stage
				for template in $$stage_dir/*.sh; do
					[ -f "$$template" ] || continue
					script_name=$$(basename "$$template")
					output_file="$(OUT_PATH)/$$stage_name/$$script_name"
					echo "      -> $$script_name"
					$(SCRIPTS)/template_subst.sh $(SERVER_SETTINGS_PATH)/extended_settings.mk "$$template" > "$$output_file"
					chmod +x "$$output_file"
				done
				# Process auxiliary template files (*.templ)
				stage_root=$${stage_dir%/};
				find "$$stage_root" -type f -name '*.templ' | while IFS= read -r template; do
					rel_path=$${template#$$stage_root/};
					output_file="$(OUT_PATH)/$$stage_name/$${rel_path%.templ}";
					output_dir=$$(dirname "$$output_file");
					mkdir -p "$$output_dir";
					echo "      -> $${rel_path%.templ}";
					$(SCRIPTS)/template_subst.sh $(SERVER_SETTINGS_PATH)/extended_settings.mk "$$template" > "$$output_file";
				done
				;;
			*)
			# Skip directories that don't match stage pattern
			;;
		esac
	done

.ONESHELL:
## Copy Age identity file to remote server: settings=XXXX !!!DO IT BEFORE make deploy!!!
deploy_age_identity:: check_deps check_age_ident
	@echo "========================================="
	echo "==> Copying Age identity to $(deploy_host)"
	echo "========================================="
	echo "Local identity: $(LOCAL_AGE_IDENTITY_FN)"
	echo "Remote path: $(letsencrypt_age_identity_path)"
	echo "SSH Key: $(deploy_ssh_identity)"
	echo ""
	if [ ! -f "$(LOCAL_AGE_IDENTITY_FN)" ]; then
		echo "ERROR: Local Age identity file not found: $(LOCAL_AGE_IDENTITY_FN)"
		exit 1
	fi
	remote_dir=$$(dirname "$(letsencrypt_age_identity_path)")
	echo "Creating remote directory: $$remote_dir"
	ssh -i $(deploy_ssh_identity) $(deploy_user)@$(deploy_host) "mkdir -p $$remote_dir && chmod 700 $$remote_dir"
	echo "Copying Age identity file..."
	scp -i $(deploy_ssh_identity) "$(LOCAL_AGE_IDENTITY_FN)" $(deploy_user)@$(deploy_host):"$(letsencrypt_age_identity_path)"
	echo "Setting secure permissions (600)..."
	ssh -i $(deploy_ssh_identity) $(deploy_user)@$(deploy_host) "chmod 600 $(letsencrypt_age_identity_path)"
	echo ""
	echo "Age identity copied successfully"
	echo ""
	echo "Verifying deployment..."
	ssh -i $(deploy_ssh_identity) $(deploy_user)@$(deploy_host) "ls -la $(letsencrypt_age_identity_path)"
	echo ""

# When ENABLE_CHATMAIL=1: chatmail/relay deploys its stack first (postfix, dovecot,
# nginx, TLS, DKIM, ...), then the standard copy+run handles MDIST scripts (ntfy).
# Use deploy_mdist for day-to-day changes that don't need chatmail reinstalled.
ifeq ($(ENABLE_CHATMAIL),1)
.ONESHELL:
deploy:: chatmail_setup_env deploy_chatmail generate_all_scripts

.ONESHELL:
## Fast deploy: skip chatmail/relay reinstall, run only mdist scripts: settings=XXXX
deploy_mdist:: generate_all_scripts deploy_age_identity deploy_copy deploy_run

.ONESHELL:
deploy_check:: chatmail_status
endif

.ONESHELL:
## Full deployment. Copy scripts and execute (combine deploy_copy and deploy_run): settings=XXXX
deploy:: deploy_age_identity deploy_copy deploy_run

.ONESHELL:
## Clone chatmail/relay repo and set up Python venv: settings=XXXX
chatmail_setup_env:: check_deps
	@command -v python3 >/dev/null 2>&1 || { \
		echo "ERROR: python3 not found. Install: sudo apt install python3-dev gcc" >&2; exit 1; }
	python3 -c "import ensurepip" >/dev/null 2>&1 || { \
		_pyver=$$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")'); \
		echo "ERROR: python3-venv not available (ensurepip missing)." >&2; \
		echo "Install: sudo apt install python$$_pyver-venv" >&2; \
		exit 1; }
	python3 -c "import sysconfig; open(sysconfig.get_path('include')+'/Python.h')" 2>/dev/null || { \
		echo "ERROR: python3-dev not found. Install: sudo apt install python3-dev gcc" >&2; exit 1; }
	command -v gcc >/dev/null 2>&1 || { \
		echo "ERROR: gcc not found. Install: sudo apt install gcc" >&2; exit 1; }
	if [ -d "$(chatmail_relay_dir)" ]; then \
		echo "chatmail/relay already cloned at $(chatmail_relay_dir)"; \
		cd "$(chatmail_relay_dir)" && git pull; \
	else \
		echo "Cloning chatmail/relay to $(chatmail_relay_dir)"; \
		git clone https://github.com/chatmail/relay "$(chatmail_relay_dir)"; \
	fi
	cd "$(chatmail_relay_dir)" && scripts/initenv.sh
	echo "chatmail/relay environment ready"

.ONESHELL:
## Initialize chatmail.ini for this domain (run once, then commit the result): settings=XXXX
chatmail_init:: check_deps
	@if [ ! -d "$(chatmail_relay_dir)" ]; then \
		echo "ERROR: chatmail/relay not found at $(chatmail_relay_dir)" >&2; \
		echo "Run: make settings=$(SETTINGS) chatmail_setup_env" >&2; \
		exit 1; \
	fi
	cd "$(chatmail_relay_dir)"
	if [ -f chatmail.ini ]; then \
		echo "chatmail.ini already exists - skipping init"; \
	else \
		scripts/cmdeploy init "$(chatmail_domain)"; \
		echo ""; \
		echo "chatmail.ini created. Copy it to settings:"; \
		echo "  cp $(chatmail_relay_dir)/chatmail.ini $(CHATMAIL_INI_SRC)"; \
		echo "Then commit it to version control."; \
	fi

.ONESHELL:
## Configure ~/.ssh/config entry for chatmail domain (idempotent): settings=XXXX
chatmail_setup_ssh::
	@_host="$(chatmail_domain)"
	_key="$(deploy_ssh_identity)"
	_marker="# mdist: $$_host"
	if grep -qF "$$_marker" "$$HOME/.ssh/config" 2>/dev/null; then
		echo "SSH config entry already present for $$_host"
	else
		printf '\n%s\nHost %s\n    User root\n    IdentityFile %s\n' \
			"$$_marker" "$$_host" "$$_key" >> "$$HOME/.ssh/config"
		echo "Added SSH config entry: $$_host -> $$_key"
	fi

.ONESHELL:
## Disable systemd-resolved stub listener on server to free port 53 for unbound: settings=XXXX
chatmail_disable_resolved_stub::
	@echo "--- Disabling systemd-resolved stub listener on $(deploy_host)"
	ssh -i $(deploy_ssh_identity) $(deploy_user)@$(deploy_host) \
		'grep -q "DNSStubListener" /etc/systemd/resolved.conf \
		&& sed -i "s/#\?DNSStubListener=.*/DNSStubListener=no/" /etc/systemd/resolved.conf \
		|| printf "\nDNSStubListener=no\n" >> /etc/systemd/resolved.conf; \
		systemctl stop systemd-resolved 2>/dev/null || true; \
		printf "nameserver 127.0.0.1\n" > /etc/resolv.conf; \
		echo "systemd-resolved stub listener disabled, resolv.conf set to unbound"'

.ONESHELL:
## Create/verify Cloudflare DNS records for chatmail domain (A + CNAMEs): settings=XXXX
chatmail_create_dns::
	@_zone=$$(printf '%s' "$(chatmail_domain)" | sed 's/^[^.]*\.//')
	echo "--- Ensuring DNS A record: $(chatmail_domain) -> $(HOST_IP)"
	$(SCRIPTS)/configure_cloudflare_dns_record.sh \
		"$$_zone" "$(chatmail_domain)" "$(HOST_IP)" \
		"$(CF_DNS_TOKEN_AGE_FN)" "$(LOCAL_SHARED_AGE_IDENTITY_FN)"
	echo "--- Ensuring DNS CNAME: mta-sts.$(chatmail_domain) -> $(chatmail_domain)."
	$(SCRIPTS)/configure_cloudflare_dns_record.sh \
		"$$_zone" "mta-sts.$(chatmail_domain)" "$(chatmail_domain)." \
		"$(CF_DNS_TOKEN_AGE_FN)" "$(LOCAL_SHARED_AGE_IDENTITY_FN)" CNAME
	echo "--- Ensuring DNS CNAME: www.$(chatmail_domain) -> $(chatmail_domain)."
	$(SCRIPTS)/configure_cloudflare_dns_record.sh \
		"$$_zone" "www.$(chatmail_domain)" "$(chatmail_domain)." \
		"$(CF_DNS_TOKEN_AGE_FN)" "$(LOCAL_SHARED_AGE_IDENTITY_FN)" CNAME

.ONESHELL:
## Wait for chatmail domain to resolve locally (up to 5 min): settings=XXXX
chatmail_wait_dns::
	@echo "--- Waiting for local DNS: $(chatmail_domain) -> $(HOST_IP)"
	if command -v nscd >/dev/null 2>&1; then nscd -i hosts 2>/dev/null || true; fi
	if command -v systemd-resolve >/dev/null 2>&1; then systemd-resolve --flush-caches 2>/dev/null || true; fi
	_i=0
	while [ "$$_i" -lt 60 ]; do
		_resolved=$$(getent hosts "$(chatmail_domain)" 2>/dev/null | awk '{print $$1}' | head -1 || true)
		if [ "$$_resolved" = "$(HOST_IP)" ]; then
			echo "DNS resolved: $(chatmail_domain) -> $$_resolved"
			exit 0
		fi
		printf "."
		sleep 5
		_i=$$(($$_i + 1))
	done
	echo ""
	echo "ERROR: $(chatmail_domain) did not resolve to $(HOST_IP) within 5 minutes" >&2
	echo "Manual fix: echo '$(HOST_IP) $(chatmail_domain)' | sudo tee -a /etc/hosts" >&2
	exit 1

.ONESHELL:
## Deploy chatmail relay to server (Postfix, Dovecot, nginx, TLS, DKIM, ...): settings=XXXX
deploy_chatmail:: chatmail_setup_env chatmail_setup_ssh chatmail_create_dns chatmail_wait_dns chatmail_disable_resolved_stub
	@if [ ! -d "$(chatmail_relay_dir)" ]; then \
		echo "ERROR: chatmail/relay not found at $(chatmail_relay_dir)" >&2; \
		echo "Run: make settings=$(SETTINGS) chatmail_setup_env" >&2; \
		exit 1; \
	fi
	if [ -f "$(CHATMAIL_INI_SRC)" ]; then \
		echo "Copying chatmail.ini from settings"; \
		cp "$(CHATMAIL_INI_SRC)" "$(chatmail_relay_dir)/chatmail.ini"; \
	elif [ ! -f "$(chatmail_relay_dir)/chatmail.ini" ]; then \
		echo "chatmail.ini not found - running init for $(chatmail_domain)"; \
		cd "$(chatmail_relay_dir)" && scripts/cmdeploy init "$(chatmail_domain)"; \
		echo "Saving chatmail.ini to settings for version control"; \
		cp "$(chatmail_relay_dir)/chatmail.ini" "$(CHATMAIL_INI_SRC)"; \
		echo "chatmail.ini saved to $(CHATMAIL_INI_SRC) - commit it to version control"; \
	fi
	echo "========================================="
	echo "==> Deploying chatmail relay to $(chatmail_domain)"
	echo "========================================="
	cd "$(chatmail_relay_dir)" && scripts/cmdeploy run || { \
		echo "ERROR: cmdeploy run failed - chatmail/relay deployment aborted" >&2; exit 1; }

.ONESHELL:
## Create all required chatmail DNS records (MX, DKIM, SPF, DMARC, SRV, ...): settings=XXXX
chatmail_setup_zone::
	@$(SCRIPTS)/chatmail_setup_zone.sh \
		"$(chatmail_domain)" \
		"$(HOST_IP)" \
		"$(CF_DNS_TOKEN_AGE_FN)" \
		"$(LOCAL_SHARED_AGE_IDENTITY_FN)" \
		"$(deploy_ssh_identity)"

# =============================================================================
# Chatmail Access Control (invite tokens)
# =============================================================================

.ONESHELL:
## Generate invite tokens for all users in chatmail_users.txt: settings=XXXX
generate_chatmail_tokens::
	@if [ ! -f "$(CHATMAIL_USERS_FILE)" ]; then \
		echo "ERROR: $(CHATMAIL_USERS_FILE) not found" >&2; exit 1; fi
	mkdir -p "$(CHATMAIL_TOKENS_DIR)"
	recipients_file="$(SERVER_AGE_RECIPIENTS_FN)"
	count=0; skipped=0
	while IFS= read -r username || [ -n "$$username" ]; do
		username=$$(printf '%s' "$$username" | sed 's/#.*//' | tr -d '[:space:]')
		[ -z "$$username" ] && continue
		token_file="$(CHATMAIL_TOKENS_DIR)/$$username.age"
		if [ -f "$$token_file" ]; then
			skipped=$$((skipped + 1))
		else
			token=$$(cat /dev/urandom | tr -dc 'a-z0-9' | head -c 32)
			printf '%s' "$$token" | age -e -R "$$recipients_file" > "$$token_file"
			echo "  Generated token for: $$username"
			count=$$((count + 1))
		fi
	done < "$(CHATMAIL_USERS_FILE)"
	echo "Done: $$count generated, $$skipped already existed"

.ONESHELL:
## Deploy invite tokens and access-controlled newemail.py to server: settings=XXXX
deploy_chatmail_users::
	@if [ ! -f "$(CHATMAIL_USERS_FILE)" ]; then \
		echo "ERROR: $(CHATMAIL_USERS_FILE) not found" >&2; exit 1; fi
	identity_file="$(LOCAL_AGE_IDENTITY_FN)"
	echo "Collecting valid tokens..."
	tokens=""
	while IFS= read -r username || [ -n "$$username" ]; do
		username=$$(printf '%s' "$$username" | sed 's/#.*//' | tr -d '[:space:]')
		[ -z "$$username" ] && continue
		token_file="$(CHATMAIL_TOKENS_DIR)/$$username.age"
		if [ ! -f "$$token_file" ]; then
			echo "  WARNING: no token for $$username - run generate_chatmail_tokens first"
			continue
		fi
		token=$$(age -d -i "$$identity_file" "$$token_file") \
			|| { echo "ERROR: failed to decrypt token for $$username" >&2; exit 1; }
		tokens="$$tokens$$token\n"
		echo "  Loaded token for: $$username"
	done < "$(CHATMAIL_USERS_FILE)"
	echo "Deploying to $(deploy_host)..."
	ssh -i $(deploy_ssh_identity) $(deploy_user)@$(deploy_host) 'mkdir -p /etc/chatmail'
	printf "# chatmail valid invite tokens - managed by mdist\n$$tokens" | \
		ssh -i $(deploy_ssh_identity) $(deploy_user)@$(deploy_host) \
		'cat > /etc/chatmail/valid_tokens.txt && chmod 644 /etc/chatmail/valid_tokens.txt'
	scp -i $(deploy_ssh_identity) \
		"$(CHATMAIL_NEWEMAIL_SRC)" \
		$(deploy_user)@$(deploy_host):/usr/lib/cgi-bin/newemail.py
	ssh -i $(deploy_ssh_identity) $(deploy_user)@$(deploy_host) \
		'chmod 755 /usr/lib/cgi-bin/newemail.py && nginx -t && systemctl reload nginx'
	echo "Deployed: tokens and access-controlled newemail.py"
	echo "Users can now register with their invite URL."

.ONESHELL:
## Show invite URL for a user: settings=XXXX USERNAME=alice
show_chatmail_invite::
	@if [ -z "$(USERNAME)" ]; then \
		echo "ERROR: USERNAME is required" >&2; \
		echo "Usage: make settings=$(SETTINGS) show_chatmail_invite USERNAME=alice" >&2; exit 1; fi
	token_file="$(CHATMAIL_TOKENS_DIR)/$(USERNAME).age"
	if [ ! -f "$$token_file" ]; then
		echo "ERROR: No token for $(USERNAME). Run generate_chatmail_tokens first." >&2; exit 1
	fi
	token=$$(age -d -i "$(LOCAL_AGE_IDENTITY_FN)" "$$token_file") \
		|| { echo "ERROR: Failed to decrypt token" >&2; exit 1; }
	echo ""
	echo "Invite for $(USERNAME):"
	echo "  URL: https://$(chatmail_domain)/new?token=$$token"
	echo "  QR:  DCACCOUNT:https://$(chatmail_domain)/new?token=$$token"
	echo ""
	echo "Share the QR data string with Delta Chat or scan via:"
	if command -v qrencode >/dev/null 2>&1; then
		qrencode -t UTF8 "DCACCOUNT:https://$(chatmail_domain)/new?token=$$token"
	else
		echo "  (install qrencode to display QR code in terminal)"
	fi

.ONESHELL:
## List chatmail users and their token status: settings=XXXX
ls_chatmail_users::
	@if [ ! -f "$(CHATMAIL_USERS_FILE)" ]; then \
		echo "No user file: $(CHATMAIL_USERS_FILE)"; exit 0; fi
	echo "Chatmail users ($(SETTINGS)):"
	echo "---"
	while IFS= read -r username || [ -n "$$username" ]; do
		username=$$(printf '%s' "$$username" | sed 's/#.*//' | tr -d '[:space:]')
		[ -z "$$username" ] && continue
		token_file="$(CHATMAIL_TOKENS_DIR)/$$username.age"
		if [ -f "$$token_file" ]; then
			printf "  %-20s [token OK]\n" "$$username"
		else
			printf "  %-20s [NO TOKEN - run generate_chatmail_tokens]\n" "$$username"
		fi
	done < "$(CHATMAIL_USERS_FILE)"

.ONESHELL:
## Show required DNS records for chatmail: settings=XXXX
chatmail_dns:: check_deps
	@cd "$(chatmail_relay_dir)" && scripts/cmdeploy dns

.ONESHELL:
## Check chatmail relay service status: settings=XXXX
chatmail_status:: check_deps
	@cd "$(chatmail_relay_dir)" && scripts/cmdeploy status

.ONESHELL:
## Run chatmail relay tests: settings=XXXX
chatmail_test:: check_deps
	@cd "$(chatmail_relay_dir)" && scripts/cmdeploy test

# =============================================================================
# Delta Chat Webhook Bot Management
# =============================================================================
WEBHOOK_SERVICES_FILE  ?= $(SERVER_SETTINGS_PATH)/webhook_services.txt
WEBHOOK_TOKENS_DIR     ?= $(SERVER_SETTINGS_PATH)/webhook_tokens
WEBHOOK_GROUPS_DIR     ?= $(SERVER_SETTINGS_PATH)/webhook_groups
WEBHOOK_BOT_CONF       ?= $(SERVER_SETTINGS_PATH)/webhook_bot.age
WEBHOOK_ADMIN_CONF     ?= $(SERVER_SETTINGS_PATH)/deltachat_admin.age
WEBHOOK_SRC_DIR        ?= $(CURDIR)/src/deltachat-webhook
WEBHOOK_BIN            ?= $(WEBHOOK_SRC_DIR)/deltachat-webhook
WEBHOOK_REMOTE_DIR     ?= /opt/deltachat-webhook
WEBHOOK_ACCOUNTS_DIR   ?= /var/lib/deltachat-webhook
WEBHOOK_LISTEN         ?= 127.0.0.1:8095
WEBHOOK_PATH           ?= /webhook
DELTACHAT_RPC_SERVER_URL ?= https://github.com/chatmail/core/releases/download/v2.49.0/deltachat-rpc-server-x86_64-linux

.ONESHELL:
## Build deltachat-webhook Go binary
build_webhook::
	@echo "--- Building deltachat-webhook"
	cd "$(WEBHOOK_SRC_DIR)" && GOOS=linux GOARCH=amd64 go build -o deltachat-webhook .
	echo "Built: $(WEBHOOK_BIN)"

.ONESHELL:
## Create bot account on chatmail server using an invite token: settings=XXXX
create_webhook_bot::
	@identity_file="$(LOCAL_AGE_IDENTITY_FN)"
	recipients_file="$(SERVER_AGE_RECIPIENTS_FN)"
	bot_conf="$(WEBHOOK_BOT_CONF)"
	if [ -f "$$bot_conf" ]; then \
		echo "Bot config already exists: $$bot_conf"; \
		echo "Run: make settings=$(SETTINGS) show_webhook_bot"; \
		exit 0; fi
	token_file=$$(ls "$(CHATMAIL_TOKENS_DIR)"/*.age 2>/dev/null | head -1)
	if [ -z "$$token_file" ]; then \
		echo "ERROR: No tokens in $(CHATMAIL_TOKENS_DIR). Run generate_chatmail_tokens first." >&2; exit 1; fi
	token=$$(age -d -i "$$identity_file" "$$token_file") \
		|| { echo "ERROR: failed to decrypt token" >&2; exit 1; }
	echo "--- Creating bot account on $(chatmail_domain)..."
	response=$$(curl -sf -X POST \
		"https://$(chatmail_domain)/new?token=$$token" \
		-H "Content-Type: application/x-www-form-urlencoded") \
		|| { echo "ERROR: failed to create account" >&2; exit 1; }
	addr=$$(printf '%s' "$$response" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['email'])")
	password=$$(printf '%s' "$$response" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['password'])")
	if [ -z "$$addr" ] || [ -z "$$password" ]; then \
		echo "ERROR: unexpected response from /new" >&2; exit 1; fi
	printf 'address %s\npassword %s\n' "$$addr" "$$password" \
		| age -e -R "$$recipients_file" > "$$bot_conf"
	echo "Bot account created: $$addr"
	echo "Config stored: $$bot_conf"

.ONESHELL:
## Show webhook bot credentials: settings=XXXX
show_webhook_bot::
	@identity_file="$(LOCAL_AGE_IDENTITY_FN)"
	bot_conf="$(WEBHOOK_BOT_CONF)"
	if [ ! -f "$$bot_conf" ]; then \
		echo "ERROR: Bot config not found. Run: make settings=$(SETTINGS) create_webhook_bot" >&2; exit 1; fi
	age -d -i "$$identity_file" "$$bot_conf"

.ONESHELL:
## Create admin account on chatmail server using an invite token: settings=XXXX
create_deltachat_admin::
	@identity_file="$(LOCAL_AGE_IDENTITY_FN)"
	recipients_file="$(SERVER_AGE_RECIPIENTS_FN)"
	admin_conf="$(WEBHOOK_ADMIN_CONF)"
	if [ -f "$$admin_conf" ]; then \
		echo "Admin config already exists: $$admin_conf"; \
		echo "Run: make settings=$(SETTINGS) show_deltachat_admin"; \
		exit 0; fi
	token_file=$$(ls "$(CHATMAIL_TOKENS_DIR)"/*.age 2>/dev/null | head -1)
	if [ -z "$$token_file" ]; then \
		echo "ERROR: No tokens in $(CHATMAIL_TOKENS_DIR). Run generate_chatmail_tokens first." >&2; exit 1; fi
	token=$$(age -d -i "$$identity_file" "$$token_file") \
		|| { echo "ERROR: failed to decrypt token" >&2; exit 1; }
	echo "--- Creating admin account on $(chatmail_domain)..."
	response=$$(curl -sf -X POST \
		"https://$(chatmail_domain)/new?token=$$token" \
		-H "Content-Type: application/x-www-form-urlencoded") \
		|| { echo "ERROR: failed to create account" >&2; exit 1; }
	addr=$$(printf '%s' "$$response" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['email'])")
	password=$$(printf '%s' "$$response" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['password'])")
	if [ -z "$$addr" ] || [ -z "$$password" ]; then \
		echo "ERROR: unexpected response from /new" >&2; exit 1; fi
	printf 'address %s\npassword %s\n' "$$addr" "$$password" \
		| age -e -R "$$recipients_file" > "$$admin_conf"
	echo "Admin account created: $$addr"
	echo "Config stored: $$admin_conf"
	echo "Import into Delta Chat: make settings=$(SETTINGS) show_deltachat_admin"

.ONESHELL:
## Show deltachat admin account credentials: settings=XXXX
show_deltachat_admin::
	@identity_file="$(LOCAL_AGE_IDENTITY_FN)"
	admin_conf="$(WEBHOOK_ADMIN_CONF)"
	if [ ! -f "$$admin_conf" ]; then \
		echo "ERROR: Admin config not found. Run: make settings=$(SETTINGS) create_deltachat_admin" >&2; exit 1; fi
	age -d -i "$$identity_file" "$$admin_conf"

.ONESHELL:
## Register webhook service: generate token + create Delta Chat group: settings=XXXX SERVICE=name
register_webhook_service::
	@if [ -z "$(SERVICE)" ]; then \
		echo "ERROR: SERVICE is required. Usage: make settings=$(SETTINGS) register_webhook_service SERVICE=my-service" >&2; exit 1; fi
	identity_file="$(LOCAL_AGE_IDENTITY_FN)"
	recipients_file="$(SERVER_AGE_RECIPIENTS_FN)"
	mkdir -p "$(WEBHOOK_TOKENS_DIR)" "$(WEBHOOK_GROUPS_DIR)"
	token_file="$(WEBHOOK_TOKENS_DIR)/$(SERVICE).age"
	group_file="$(WEBHOOK_GROUPS_DIR)/$(SERVICE).group_id"
	if [ -f "$$token_file" ] && [ -f "$$group_file" ]; then \
		echo "Service already registered: $(SERVICE)"; \
		echo "Token: make settings=$(SETTINGS) show_webhook_token SERVICE=$(SERVICE)"; \
		echo "Invite: make settings=$(SETTINGS) webhook_invite SERVICE=$(SERVICE)"; \
		exit 0; fi
	if [ ! -f "$$token_file" ]; then \
		token=$$(cat /dev/urandom | tr -dc 'a-z0-9' | head -c 40); \
		printf '%s' "$$token" | age -e -R "$$recipients_file" > "$$token_file"; \
		echo "Generated token for: $(SERVICE)"; fi
	if [ ! -f "$(WEBHOOK_BOT_CONF)" ]; then \
		echo "ERROR: Bot config not found. Run: make settings=$(SETTINGS) create_webhook_bot first." >&2; exit 1; fi
	if ! ssh -i $(deploy_ssh_identity) $(deploy_user)@$(deploy_host) \
		"[ -f $(WEBHOOK_REMOTE_DIR)/bot.conf ]" 2>/dev/null; then \
		echo "ERROR: bot.conf not on server. Run: make settings=$(SETTINGS) deploy_webhook first." >&2; exit 1; fi
	admin_addr=""
	if [ -f "$(WEBHOOK_ADMIN_CONF)" ]; then \
		admin_addr=$$(age -d -i "$$identity_file" "$(WEBHOOK_ADMIN_CONF)" | awk '/^address/{print $$2}'); fi
	echo "--- Creating Delta Chat group: $(SERVICE)"
	admin_flag=""
	if [ -n "$$admin_addr" ]; then admin_flag="--admin $$admin_addr"; fi
	ssh -i $(deploy_ssh_identity) $(deploy_user)@$(deploy_host) \
		"systemctl stop deltachat-webhook 2>/dev/null || true"
	output=$$(ssh -i $(deploy_ssh_identity) $(deploy_user)@$(deploy_host) \
		"$(WEBHOOK_REMOTE_DIR)/deltachat-webhook create-group \
		--accounts-dir $(WEBHOOK_ACCOUNTS_DIR) \
		--bot $(WEBHOOK_REMOTE_DIR)/bot.conf \
		--name '$(SERVICE)' $$admin_flag")
	ssh -i $(deploy_ssh_identity) $(deploy_user)@$(deploy_host) \
		"systemctl start deltachat-webhook 2>/dev/null || true"
	group_id=$$(printf '%s' "$$output" | grep '^group_id=' | cut -d= -f2)
	invite=$$(printf '%s' "$$output" | grep '^invite=' | cut -d= -f2-)
	if [ -z "$$group_id" ]; then \
		echo "ERROR: failed to create group" >&2; exit 1; fi
	printf '%s\n' "$$group_id" > "$$group_file"
	echo "Service registered: $(SERVICE)"
	echo "Group ID: $$group_id"
	if [ -n "$$invite" ]; then \
		echo "Invite link: $$invite"; fi
	echo ""
	echo "Next: make settings=$(SETTINGS) show_webhook_token SERVICE=$(SERVICE)"

.ONESHELL:
## Show webhook service token: settings=XXXX SERVICE=name
show_webhook_token::
	@if [ -z "$(SERVICE)" ]; then \
		echo "ERROR: SERVICE is required" >&2; exit 1; fi
	identity_file="$(LOCAL_AGE_IDENTITY_FN)"
	token_file="$(WEBHOOK_TOKENS_DIR)/$(SERVICE).age"
	if [ ! -f "$$token_file" ]; then \
		echo "ERROR: No token for $(SERVICE). Run: make settings=$(SETTINGS) register_webhook_service SERVICE=$(SERVICE)" >&2; exit 1; fi
	token=$$(age -d -i "$$identity_file" "$$token_file")
	echo "Service: $(SERVICE)"
	echo "Token:   $$token"
	echo ""
	echo "Usage:"
	echo "  curl -X POST https://$(chatmail_domain)$(WEBHOOK_PATH) \\"
	echo "    -H 'Authorization: Bearer $$token' \\"
	echo "    -H 'Content-Type: application/json' \\"
	echo "    -d '{\"text\": \"hello from $(SERVICE)\"}'"

.ONESHELL:
## Get fresh invite link for a webhook group: settings=XXXX SERVICE=name
webhook_invite::
	@if [ -z "$(SERVICE)" ]; then \
		echo "ERROR: SERVICE is required" >&2; exit 1; fi
	identity_file="$(LOCAL_AGE_IDENTITY_FN)"
	group_file="$(WEBHOOK_GROUPS_DIR)/$(SERVICE).group_id"
	if [ ! -f "$$group_file" ]; then \
		echo "ERROR: Group not registered. Run: make settings=$(SETTINGS) register_webhook_service SERVICE=$(SERVICE)" >&2; exit 1; fi
	group_id=$$(cat "$$group_file")
	ssh -i $(deploy_ssh_identity) $(deploy_user)@$(deploy_host) \
		"systemctl stop deltachat-webhook 2>/dev/null || true"
	link=$$(ssh -i $(deploy_ssh_identity) $(deploy_user)@$(deploy_host) \
		"$(WEBHOOK_REMOTE_DIR)/deltachat-webhook invite \
		--accounts-dir $(WEBHOOK_ACCOUNTS_DIR) \
		--bot $(WEBHOOK_REMOTE_DIR)/bot.conf \
		--group $$group_id")
	ssh -i $(deploy_ssh_identity) $(deploy_user)@$(deploy_host) \
		"systemctl start deltachat-webhook 2>/dev/null || true"
	echo "Invite link for $(SERVICE): $$link"

.ONESHELL:
## Show QR code for joining a webhook group (scan with Delta Chat): settings=XXXX SERVICE=name
webhook_qr::
	@if [ -z "$(SERVICE)" ]; then \
		echo "ERROR: SERVICE is required" >&2; exit 1; fi
	identity_file="$(LOCAL_AGE_IDENTITY_FN)"
	group_file="$(WEBHOOK_GROUPS_DIR)/$(SERVICE).group_id"
	if [ ! -f "$$group_file" ]; then \
		echo "ERROR: Group not registered. Run: make settings=$(SETTINGS) register_webhook_service SERVICE=$(SERVICE)" >&2; exit 1; fi
	group_id=$$(cat "$$group_file")
	ssh -i $(deploy_ssh_identity) $(deploy_user)@$(deploy_host) \
		"systemctl stop deltachat-webhook 2>/dev/null || true"
	link=$$(ssh -i $(deploy_ssh_identity) $(deploy_user)@$(deploy_host) \
		"$(WEBHOOK_REMOTE_DIR)/deltachat-webhook invite \
		--accounts-dir $(WEBHOOK_ACCOUNTS_DIR) \
		--bot $(WEBHOOK_REMOTE_DIR)/bot.conf \
		--group $$group_id")
	ssh -i $(deploy_ssh_identity) $(deploy_user)@$(deploy_host) \
		"systemctl start deltachat-webhook 2>/dev/null || true"
	echo "Scan this QR code with Delta Chat to join group: $(SERVICE)"
	echo ""
	qrencode -t UTF8 "$$link"
	echo ""
	echo "Or open in browser on phone: $$link"

.ONESHELL:
## List all registered webhook services: settings=XXXX
ls_webhook_services::
	@echo "Webhook services ($(SETTINGS)):"
	echo "---"
	if [ ! -f "$(WEBHOOK_SERVICES_FILE)" ]; then \
		echo "  (no services file)"; exit 0; fi
	while IFS= read -r svc || [ -n "$$svc" ]; do
		svc=$$(printf '%s' "$$svc" | sed 's/#.*//' | tr -d '[:space:]')
		[ -z "$$svc" ] && continue
		token_file="$(WEBHOOK_TOKENS_DIR)/$$svc.age"
		group_file="$(WEBHOOK_GROUPS_DIR)/$$svc.group_id"
		token_status="[NO TOKEN]"
		group_status="[NO GROUP]"
		[ -f "$$token_file" ] && token_status="[token OK]"
		[ -f "$$group_file" ] && group_status="[group $$(cat $$group_file)]"
		printf "  %-20s %s %s\n" "$$svc" "$$token_status" "$$group_status"
	done < "$(WEBHOOK_SERVICES_FILE)"

.ONESHELL:
## Full webhook bot deployment: build, install, configure, start: settings=XXXX
deploy_webhook:: create_deltachat_admin create_webhook_bot build_webhook
	@echo "========================================="
	echo "==> Deploying deltachat webhook bot to $(deploy_host)"
	echo "========================================="
	identity_file="$(LOCAL_AGE_IDENTITY_FN)"
	echo "--- Setting up server directories"
	ssh -i $(deploy_ssh_identity) $(deploy_user)@$(deploy_host) \
		"mkdir -p $(WEBHOOK_REMOTE_DIR) $(WEBHOOK_ACCOUNTS_DIR) && \
		 chmod 700 $(WEBHOOK_ACCOUNTS_DIR) && \
		 systemctl stop deltachat-webhook 2>/dev/null || true"
	echo "--- Installing deltachat-rpc-server"
	ssh -i $(deploy_ssh_identity) $(deploy_user)@$(deploy_host) \
		"if [ ! -f /usr/local/bin/deltachat-rpc-server ]; then \
		    curl -sfL -o /usr/local/bin/deltachat-rpc-server '$(DELTACHAT_RPC_SERVER_URL)' && \
		    chmod +x /usr/local/bin/deltachat-rpc-server && \
		    echo 'Installed deltachat-rpc-server'; \
		 else echo 'deltachat-rpc-server already installed'; fi"
	echo "--- Deploying webhook binary"
	scp -i $(deploy_ssh_identity) "$(WEBHOOK_BIN)" \
		"$(deploy_user)@$(deploy_host):$(WEBHOOK_REMOTE_DIR)/deltachat-webhook"
	ssh -i $(deploy_ssh_identity) $(deploy_user)@$(deploy_host) \
		"chmod +x $(WEBHOOK_REMOTE_DIR)/deltachat-webhook"
	echo "--- Deploying bot.conf"
	bot_conf_plain=$$(mktemp)
	trap "rm -f $$bot_conf_plain" EXIT
	age -d -i "$$identity_file" "$(WEBHOOK_BOT_CONF)" > "$$bot_conf_plain" \
		|| { echo "ERROR: decrypt bot config" >&2; exit 1; }
	scp -i $(deploy_ssh_identity) "$$bot_conf_plain" \
		"$(deploy_user)@$(deploy_host):$(WEBHOOK_REMOTE_DIR)/bot.conf"
	ssh -i $(deploy_ssh_identity) $(deploy_user)@$(deploy_host) \
		"chmod 600 $(WEBHOOK_REMOTE_DIR)/bot.conf"
	echo "--- Registering services"
	while IFS= read -r svc || [ -n "$$svc" ]; do
		svc=$$(printf '%s' "$$svc" | sed 's/#.*//' | tr -d '[:space:]')
		[ -z "$$svc" ] && continue
		echo "  Registering: $$svc"
		$(MAKE) --no-print-directory settings=$(SETTINGS) register_webhook_service SERVICE="$$svc" </dev/null
	done < "$(WEBHOOK_SERVICES_FILE)"
	echo "--- Generating services.conf"
	services_conf=$$(mktemp)
	trap "rm -f $$bot_conf_plain $$services_conf" EXIT
	while IFS= read -r svc || [ -n "$$svc" ]; do
		svc=$$(printf '%s' "$$svc" | sed 's/#.*//' | tr -d '[:space:]')
		[ -z "$$svc" ] && continue
		token_file="$(WEBHOOK_TOKENS_DIR)/$$svc.age"
		group_file="$(WEBHOOK_GROUPS_DIR)/$$svc.group_id"
		if [ ! -f "$$token_file" ] || [ ! -f "$$group_file" ]; then
			echo "  WARNING: $$svc not fully registered, skipping" >&2; continue; fi
		token=$$(age -d -i "$$identity_file" "$$token_file")
		group_id=$$(cat "$$group_file")
		printf '%s %s %s\n' "$$svc" "$$token" "$$group_id" >> "$$services_conf"
	done < "$(WEBHOOK_SERVICES_FILE)"
	scp -i $(deploy_ssh_identity) "$$services_conf" \
		"$(deploy_user)@$(deploy_host):$(WEBHOOK_REMOTE_DIR)/services.conf"
	ssh -i $(deploy_ssh_identity) $(deploy_user)@$(deploy_host) \
		"chmod 600 $(WEBHOOK_REMOTE_DIR)/services.conf"
	echo "--- Installing systemd service"
	unit_file=$$(mktemp)
	trap "rm -f $$bot_conf_plain $$services_conf $$unit_file" EXIT
	printf '[Unit]\nDescription=Delta Chat Webhook Bot\nAfter=network.target\n\n[Service]\nType=simple\nExecStart=$(WEBHOOK_REMOTE_DIR)/deltachat-webhook serve --accounts-dir $(WEBHOOK_ACCOUNTS_DIR) --bot $(WEBHOOK_REMOTE_DIR)/bot.conf --services $(WEBHOOK_REMOTE_DIR)/services.conf --listen $(WEBHOOK_LISTEN)\nRestart=always\nRestartSec=5\n\n[Install]\nWantedBy=multi-user.target\n' > "$$unit_file"
	scp -i $(deploy_ssh_identity) "$$unit_file" \
		"$(deploy_user)@$(deploy_host):/etc/systemd/system/deltachat-webhook.service"
	ssh -i $(deploy_ssh_identity) $(deploy_user)@$(deploy_host) \
		"systemctl daemon-reload && systemctl enable deltachat-webhook"
	echo "--- Configuring nginx"
	ssh -i $(deploy_ssh_identity) $(deploy_user)@$(deploy_host) \
		"python3 -c \"\
import sys; path='/etc/nginx/nginx.conf'; loc='location $(WEBHOOK_PATH)'; \
block='\t\tlocation $(WEBHOOK_PATH) {\n\t\t\tproxy_pass http://$(WEBHOOK_LISTEN);\n\t\t}\n\n'; \
content=open(path).read(); \
open(path,'w').write(content.replace('\t\tlocation /mxdeliv/',block+'\t\tlocation /mxdeliv/',1)) if loc not in content else None; \
print('added webhook location' if loc not in content else 'webhook location already exists') \
\""
	ssh -i $(deploy_ssh_identity) $(deploy_user)@$(deploy_host) \
		"nginx -t && nginx -s reload"
	echo "--- Starting deltachat-webhook service"
	ssh -i $(deploy_ssh_identity) $(deploy_user)@$(deploy_host) \
		"systemctl restart deltachat-webhook && sleep 2 && \
		 systemctl status deltachat-webhook --no-pager --lines=5"
	echo "========================================="
	echo "==> Webhook bot deployed! Check: make settings=$(SETTINGS) ls_webhook_services"
	echo "========================================="

.ONESHELL:
## Redeploy services.conf + restart (use after adding new services): settings=XXXX
update_webhook_conf::
	@identity_file="$(LOCAL_AGE_IDENTITY_FN)"
	echo "--- Regenerating services.conf"
	services_conf=$$(mktemp)
	trap "rm -f $$services_conf" EXIT
	while IFS= read -r svc || [ -n "$$svc" ]; do
		svc=$$(printf '%s' "$$svc" | sed 's/#.*//' | tr -d '[:space:]')
		[ -z "$$svc" ] && continue
		token_file="$(WEBHOOK_TOKENS_DIR)/$$svc.age"
		group_file="$(WEBHOOK_GROUPS_DIR)/$$svc.group_id"
		if [ ! -f "$$token_file" ] || [ ! -f "$$group_file" ]; then
			echo "  WARNING: $$svc not fully registered, skipping" >&2; continue; fi
		token=$$(age -d -i "$$identity_file" "$$token_file")
		group_id=$$(cat "$$group_file")
		printf '%s %s %s\n' "$$svc" "$$token" "$$group_id" >> "$$services_conf"
	done < "$(WEBHOOK_SERVICES_FILE)"
	scp -i $(deploy_ssh_identity) "$$services_conf" \
		"$(deploy_user)@$(deploy_host):$(WEBHOOK_REMOTE_DIR)/services.conf"
	ssh -i $(deploy_ssh_identity) $(deploy_user)@$(deploy_host) \
		"chmod 600 $(WEBHOOK_REMOTE_DIR)/services.conf && \
		 systemctl restart deltachat-webhook && sleep 2 && \
		 systemctl status deltachat-webhook --no-pager --lines=3"
	echo "Done: services.conf updated and service restarted"

# =============================================================================
# ntfy Notification Server Management
# =============================================================================

.ONESHELL:
## Create/verify Cloudflare DNS A record for ntfy domain: settings=XXXX
ntfy_create_dns::
	@echo "--- Ensuring DNS A record: $(ntfy_domain) -> $(HOST_IP)"
	$(SCRIPTS)/configure_cloudflare_dns_record.sh \
		"$$(printf '%s' "$(ntfy_domain)" | sed 's/^[^.]*\.//')" \
		"$(ntfy_domain)" "$(HOST_IP)" \
		"$(CF_DNS_TOKEN_AGE_FN)" "$(LOCAL_SHARED_AGE_IDENTITY_FN)"

ifeq ($(ENABLE_NTFY),1)
deploy_copy:: ntfy_create_dns
endif

.ONESHELL:
## Create ntfy access token for a topic: settings=XXXX TOPIC=mytopic
create_ntfy_token:: check_deps
	@if [ -z "$(TOPIC)" ]; then \
		echo "ERROR: TOPIC required. Usage: make settings=XXXX create_ntfy_token TOPIC=alerts" >&2; \
		exit 1; \
	fi
	echo "Creating ntfy token for topic: $(TOPIC)"
	ssh -i "$(deploy_ssh_identity)" $(deploy_user)@$(deploy_host) \
		"ntfy token add --log-level=error --topic $(TOPIC) 2>&1 | tee /dev/stderr"
	echo ""
	echo "Usage: curl -d 'Hello' -H 'Authorization: Bearer TOKEN' $(ntfy_base_url)/$(TOPIC)"

.ONESHELL:
## Show ntfy admin accounts/tokens: settings=XXXX
show_ntfy_tokens:: check_deps
	@ssh -i "$(deploy_ssh_identity)" $(deploy_user)@$(deploy_host) \
		"ntfy user list 2>&1; echo '---'; ntfy token list 2>&1"

## ---

.ONESHELL:
## Copy generated scripts to remote server
deploy_copy:: check_deps
	@echo "========================================="
	echo "==> Copying scripts to $(deploy_host)"
	echo "========================================="
	echo "Source: $(OUT_PATH)/"
	echo "Target: $(deploy_user)@$(deploy_host):$(deploy_path)/"
	echo "SSH Key: $(deploy_ssh_identity)"
	echo ""
	ssh -i $(deploy_ssh_identity) $(deploy_user)@$(deploy_host) "rm -rf $(deploy_path)/*"
	scp -i $(deploy_ssh_identity) -r $(OUT_PATH)/* $(deploy_user)@$(deploy_host):$(deploy_path)/
	echo ""
	echo "Scripts copied successfully"

.ONESHELL:
## Execute deployment scripts on remote server
deploy_run:: check_deps
	@echo "========================================="
	echo "==> Executing deployment on $(deploy_host)"
	echo "========================================="
	ssh -i $(deploy_ssh_identity) $(deploy_user)@$(deploy_host) 'sh $(deploy_path)/a001-run-all/run-all.sh'

.ONESHELL:
### Execute deployment with dry-run (show what would run)
deploy_check:: check_deps
	@echo "========================================="
	echo "==> Checking deployment on $(deploy_host)"
	echo "========================================="
	ssh -i $(deploy_ssh_identity) $(deploy_user)@$(deploy_host) 'sh $(deploy_path)/a001-run-all/run-all.sh --dry-run'

.ONESHELL:
## shh to the server
connect_to_server::
	@echo "========================================="
	echo "==> ssh to the server  $(deploy_host)"
	echo "========================================="
	ssh -i $(deploy_ssh_identity) $(deploy_user)@$(deploy_host)

.ONESHELL:
### Ensure that all needed tools are installed.
check_deps::
	@command -v jq >/dev/null 2>&1    || { echo "ERROR: jq is not installed. Please install jq."; exit 1; }
	@command -v age >/dev/null 2>&1   || { echo "ERROR: age is not installed. Please install age - simple, modern, and secure file encryption."; exit 1; }

.ONESHELL:
### Ensure that Age Identity is exists
check_age_ident::
	@if [ ! -f "$(LOCAL_AGE_IDENTITY_FN)" ]; then
		echo "Age identity File $(LOCAL_AGE_IDENTITY_FN) not found. Creating ..."
		mkdir -p $$(dirname "$(LOCAL_AGE_IDENTITY_FN)")
		age-keygen -o $(LOCAL_AGE_IDENTITY_FN)
		echo "Age Identity file is created: $(LOCAL_AGE_IDENTITY_FN)"
		echo "\n\n\n"
	fi

.ONESHELL:
### Ensure that Recipients file exists. By default it contains your public key
check_age_recipients::
	@if [ ! -f "$(SERVER_AGE_RECIPIENTS_FN)" ] || [ ! -s "$(SERVER_AGE_RECIPIENTS_FN)" ]; then
		if [ ! -f "$(SERVER_AGE_RECIPIENTS_FN)" ]; then
			echo "Age recipients file $(SERVER_AGE_RECIPIENTS_FN) not found. Creating ..."
		else
			echo "Age recipients file $(SERVER_AGE_RECIPIENTS_FN) is empty. Regenerating ..."
		fi
		mkdir -p $$(dirname "$(SERVER_AGE_RECIPIENTS_FN)")
		age-keygen -y $(LOCAL_AGE_IDENTITY_FN) > $(SERVER_AGE_RECIPIENTS_FN)
		echo "Age recipients file created with public key from $(LOCAL_AGE_IDENTITY_FN)"
	fi

.ONESHELL:
### Encrypt file fileName. Output is in fileName.age: Parameters IN=fileName - full path to the file.
encrypt_file:: check_age_recipients
	@echo "==> Encrypt file ..."
	out="$(IN).age"
	umask 077
	age -R $(SERVER_AGE_RECIPIENTS_FN) -o "$${out}" "$(IN)"
	echo "     Original file  : $(IN)"
	echo "     Encrypted file : $${out}"

.ONESHELL:
### Decrypt file fileName.age. Output is in fileName: Parameters IN=fileName.age - full path to the file.
decrypt_file:: check_age_recipients
	@echo "==> decrypt file ..."
	out=$$(echo "$(IN)" | sed 's/\.age$$//'); \
	umask 077
	age -d -i $(AGE_IDENT_FN) -o "$${out}" "$(IN)"
	echo "     Encrypted file : $(IN)"
	echo "     Decrypted file : $${out}"

## ---

# =============================================================================
# No rules after this line.
# =============================================================================
dummy::
	@echo "dummy"

.ONESHELL:
## Usage
usage::
	@echo "Usage:"
	echo " make settings=XXXX COMMAND"
	echo "   setting - directory with the settings parameter. Use: make ls-servers - to available settings"
	echo "   command - one of the commands from makefile.  Use: make help  or make help_all - to see list of avaiable commands"
	echo " "

## Show session start reminder for Claude (run this at session start!)
claude_start::
	@echo "========================================="
	@echo "CLAUDE SESSION START"
	@echo "========================================="
	@echo ""
	@echo "Copy this prompt to Claude:"
	@echo ""
	@echo "---START PROMPT---"
	@echo "Read and follow project guidelines:"
	@echo "- CLAUDE.md"
	@echo "- docs/claude/adr-guidelines.md"
	@echo "- docs/claude/PROJECT_NOTES.md"
	@echo "- docs/adr/0000-index.md"

	@echo ""
	@echo "Key reminders:"
	@echo "- Shell scripts: Use POSIX sh (#!/bin/sh), not bash"
	@echo "- Validate with: ./scripts/validate_posix.sh"
	@echo "- ADRs: <150 lines, must include Summary + Quick Reference + Key Changes"
	@echo "- Code style: ASCII only, 120 chars/line, concrete paths, commands in backticks"
	@echo "---END PROMPT---"
	@echo ""
	@echo "========================================="
	@echo "Full documentation:"
	@echo "========================================="
	@cat docs/claude/SESSION_START_REMINDER.md
	@echo ""
	@echo "========================================="
	@echo "Current Work Status:"
	@echo "========================================="
	@if [ -f docs/claude/PROJECT_NOTES.md ]; then \
		cat docs/claude/PROJECT_NOTES.md; \
	else \
		echo "No PROJECT_NOTES.md found"; \
	fi

## Print this help
help::
	@awk '/^## ---/ {c=substr($$0,7); print c ":"; c=0; next} /^## /{c=substr($$0,3);next}c&&/^[[:alpha:]][[:alnum:]_/-]+:/{print substr($$1,1,index($$1,":")),c}1{c=0}' $(MAKEFILE_LIST) | column -s: -t -W 2,3 -o " "

## Print extended help. Show all possible targets
help_all:: help
	@echo ""
	@echo "Other Targers:"
	@echo ""
	@awk '/^## ---/ {c=substr($$0,8); print c ":"; c=0; next} /^### /{c=substr($$0,4);next}c&&/^[[:alpha:]][[:alnum:]_/-]+:/{print substr($$1,1,index($$1,":")),c}1{c=0}' $(MAKEFILE_LIST) | column -s: -t -W 2,3 -o " "
