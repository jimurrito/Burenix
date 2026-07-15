#!/usr/bin/env bash
#
# Shows for a data sources's backup and restore services
# Lite wrapper for journalctl
#

SOURCES_PATH="/etc/burenix/conf"
dataSource="${1}"
job="${2}"
args=${@:3}

#
# Verbose display if DATA_SOURCE is not provided
if [[ -z "${dataSource}" ]]; then
    echo "No data source provided. Please run 'burenix-cli ls' to see the available data sources."
    exit 1
fi

if [[ -z "${job}" ]]; then
    echo "No job provided. Input must be either 'backup' or 'restore'."
    exit 1
fi

#
#   Check that the DATA_SOURCE provided is valid
valid=$(ls ${SOURCES_PATH}/${dataSource}.json 2> /dev/null)
if [[ -z $valid ]]; then
    echo "Data source: [${dataSource}] was not found. Please run 'burenix-cli ls' to see the available data sources."
    exit 1
fi

#
#  validate job
case $job in
    backup | restore )
        journalctl -u "burenix-${dataSource}-${job}.service" ${args}
        ;;
    * )
        echo "Job provided [${job}] is not valid. Input must be either 'backup' or 'restore'."
        exit 1
        ;;
esac
