#!/usr/bin/env bash
#
# Displays the json config for each of, or all, the data sources.

SOURCES_PATH="/etc/burenix/conf"
DATA_SOURCE="${1}"

#
#  Check that the DATA_SOURCE provided is valid
if [[ -z $(ls ${SOURCES_PATH}/${DATA_SOURCE}.json 2> /dev/null) ]]; then
    echo "Data source: [${DATA_SOURCE}] was not found. Please run 'burenix-cli ls' to see the available data sources."
    exit 1
fi

#
#
if [[ -n "${DATA_SOURCE}"  ]]; then
    # Show just one config
    cat ${SOURCES_PATH}/${DATA_SOURCE}.json | jq
else
    # show all configs
    cat ${SOURCES_PATH}/*.json | jq
fi
