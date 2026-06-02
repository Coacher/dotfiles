#!/bin/bash

set -e

CMD="rsync -rlp -Ic --existing -i"
${CMD} --dry-run "${1}" "${2}"

read -r -p "Proceed? (y/N): " ANSWER
case "${ANSWER:-N}" in
    [yY])
        ${CMD} --stats "${1}" "${2}"
        ;;
    [nN])
        echo "Aborting per user request."
        ;;
    *)
        echo "Invalid input. Please enter 'y' or 'n'."
        ;;
esac
