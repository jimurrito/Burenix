#!/usr/bin/env bash
#

#
# Backup-Restore CLI
#
# CLI is for triggering a backup manually
# Acts as a root for the cli
#

# Mappings for entrypoint input args
KEY_PATH="${1}" # passed in alias invocation
CLI_CMD="${2}"
CLI_ARGS="${@:3}"
CLI_PATH="/etc/burenix/cli"

case "${CLI_CMD}" in
    restore | backup | ls)
        ${CLI_PATH}/${CLI_CMD}.bash "${KEY_PATH}" ${CLI_ARGS}
        ;;
    help)
        ${CLI_PATH}/help.bash
        ;;
    *)
        echo "No valid sub-command provided."
        ${CLI_PATH}/help.bash
        exit 1
        ;;
esac
