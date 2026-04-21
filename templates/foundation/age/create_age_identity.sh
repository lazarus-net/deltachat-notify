#!/bin/sh
#
# Create Age Identity file of not exists
#
# Parameters:
#  local_age_identity_fn -  identity file on a local machine - full path.

set -eu

FN=${local_age_identity_fn}

# If file exists - nothing to do.
if [ -f "$(FN)" ]; then
    exit 0
fi

echo "Age identity File ${FN} not found. Creating ..."

dir=$(dirname "${FN}")

if [ ! -d ${dir} ]; then
    mkdir -p ${dir}
fi

age_keygen -o {FN}

echo "Age Identity file is created: ${FN}"

