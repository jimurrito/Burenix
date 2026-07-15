#!/usr/bin/env bash
#
# Backup-Restore CLI
#
# CLI is for triggering a backup manually
# Acts as a root for the cli
#
# Action scripts are held under /etc/burenix-cli
#

# Mappings for entrypoint input args
CLI_CMD="${1}"
CLI_ARGS="${@:2}"
CLI_PATH="/etc/burenix/cli"

case "${CLI_CMD}" in
    restore | backup | ls | show | logs )
        ${CLI_PATH}/${CLI_CMD} ${CLI_ARGS}
        ;;
    help )
        ${CLI_PATH}/help
        ;;
    * )
        echo "No valid sub-command provided."
        ${CLI_PATH}/help
        exit 1
        ;;
esac
