#!/bin/sh
# Substitute values in template file
# Settings_FN - is a Makefile or bash script that export variables Preferably with PARAMETER=VALUE declaration.
#               Variables must be exported
# Template_FN - is any file with values like ${variable_name} that will be substituted.
# Expecting
#    PKG, PKG_VERSION and PKG_RELEASE as exported ENV variables.

SETTINGS_FN="$1"
TEMPLATE_FN="$2"

# see https://www.baeldung.com/linux/envsubst-command
# for explanation of the code below
#envsubst "\${PKG} \${PKG_VERSION} \${PKG_RELEASE} \${PKG_SRC_DIR} \${PKG_DIR} $(sed -n 's/export *//g;s/^[[:space:]]*\([A-Za-z0-9_]\+\).*=.*/${\1}/p' "${SETTINGS_FN}")" < "${TEMPLATE_FN}" | sed 's/^M$//'
envsubst "$(sed -n 's/export *//g;s/^[[:space:]]*\([A-Za-z0-9_]\+\).*=.*/${\1}/p' "${SETTINGS_FN}")" < "${TEMPLATE_FN}"

#end
