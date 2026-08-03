#!/usr/bin/bash

set -eu

SRC="${1:?usage: ${0##*/} SRC TGT}"
TGT="${2:?usage: ${0##*/} SRC TGT}"

rclone check "${SRC}" "${TGT}" \
    --one-way --links \
    --log-file /dev/null --combined - \
    | rg -v '^=' | sort -k 2

rclone copy "${SRC}" "${TGT}" \
    --checksum --links --metadata --no-update-modtime \
    --log-file /dev/null --interactive
