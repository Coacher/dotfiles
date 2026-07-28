#!/usr/bin/bash

set -e

SRC="${1}"
TGT="${2}"

rclone check "${SRC}" "${TGT}" \
    --one-way --links --log-file /dev/null --combined - | \
    rg -v '^=' | sort -k 2

rclone copy "${SRC}" "${TGT}" \
    --checksum --links --metadata --no-update-dir-modtime --no-update-modtime \
    --log-file /dev/null --interactive
