#!/bin/sh

DATA_FILE="$1"
if ! test -f "${DATA_FILE}"; then echo 1 > "${DATA_FILE}"; fi
number=$(($(cat "${DATA_FILE}") + 1))
echo $number > "${DATA_FILE}"
echo $number
