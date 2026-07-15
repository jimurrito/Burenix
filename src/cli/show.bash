#!/usr/bin/env bash
#
# Displays the json config for each of, or all, the data sources.

SOURCES_PATH="/etc/burenix/conf"
#
dataSource="${1}"

#
#
if [[ -n "${dataSource}"  ]]; then
    # Show just one config
    cat ${SOURCES_PATH}/${dataSource}.json | jq
else
    # show all configs
    cat ${SOURCES_PATH}/*.json | jq
fi
