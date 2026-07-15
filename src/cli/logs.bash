#!/usr/bin/env bash
#
# Shows for a data sources's backup and restore services
# Lite wrapper for journalctl
#

SOURCES_PATH="/etc/burenix/conf"
DATA_SOURCE="${1}"
job="${2}"
args=${@:3}

#
# Verbose display if DATA_SOURCE is not provided
if [[ -z "${DATA_SOURCE}" ]]; then
    echo "No data source provided. Please run 'burenix-cli ls' to see the available data sources."
    exit 1
fi

if [[ -z "${job}" ]]; then
    echo "No job provided. Input must be either 'backup' or 'restore'."
    exit 1
fi

#
#   Check that the DATA_SOURCE provided is valid
if [[ -z $(ls ${SOURCES_PATH}/${DATA_SOURCE}.json 2> /dev/null) ]]; then
    echo "Data source: [${DATA_SOURCE}] was not found. Please run 'burenix-cli ls' to see the available data sources."
    exit 1
fi

#
#  validate job
case $job in
    backup | restore )
        journalctl -u "burenix-${DATA_SOURCE}-${job}.service" ${args}
        ;;
    * )
        echo "Job provided [${job}] is not valid. Input must be either 'backup' or 'restore'."
        exit 1
        ;;
esac
