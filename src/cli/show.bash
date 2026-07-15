#!/usr/bin/env bash
#
# Displays the json config for each of, or all, the data sources.

SOURCES_PATH="/etc/burenix/conf"
dataSource="${1}"

#
#  Check that the DATA_SOURCE provided is valid
valid=$(ls ${SOURCES_PATH}/${dataSource}.json 2> /dev/null)
if [[ -z $valid ]]; then
    echo "Data source: [${dataSource}] was not found. Please run 'burenix-cli ls' to see the available data sources."
    exit 1
fi

#
#
if [[ -n "${dataSource}"  ]]; then
    # Show just one config
    cat ${SOURCES_PATH}/${dataSource}.json | jq
else
    # show all configs
    cat ${SOURCES_PATH}/*.json | jq
fi
