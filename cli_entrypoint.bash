#!/usr/bin/env bash
#

#
# Backup-Restore CLI
#
# CLI is for triggering a backup manually
# Acts as a root for the cli
#

# Import vars from file
. /etc/burenix/conf/env.conf
# KEY_PATH => path to key file
# CLI_PATH => path to cli scripts

# Mappings for entrypoint input args
CLI_CMD="${2}"
CLI_ARGS="${@:3}"

case "${CLI_CMD}" in
    restore | backup | ls)
        ${CLI_PATH}/${CLI_CMD}.bash "${KEY_PATH}" ${CLI_ARGS}
        ;;
    ?)
        echo "Invalid command [${CLI_CMD}] provided."
        echo "Please use 'bure help' to see the possible options."
        exit 1
        ;;
esac
