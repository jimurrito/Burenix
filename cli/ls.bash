#!/usr/bin/env bash
#
# Shows the available backup sources and snapshots
#

SOURCES_PATH="/etc/burenix/conf"
DATA_SOURCES=($(ls ${SOURCES_PATH}/*tgt.conf))

# Per data source
for source in ${DATA_SOURCES[@]}; do
    # get data source name
    DS_NAME="$(basename "${source}" | cut -d. -f1)"
    echo -e "\nData Source: [${DS_NAME}]\n"
    # get targets
    DS_TGTS=$(cat "${source}")
    # Get snapshots from targets
    for tgt in ${DS_TGTS[@]}; do
        echo -e "Backup Target: [${tgt}]"
        SNAPS=$(ls ${tgt}/backup-${DS_NAME}*.tar.gz*)
        echo -e "Available Snapshots"
        for snap in ${SNAPS[@]}; do
            echo "  -> $(basename ${snap})"
        done
        echo ""
    done
    
    #
    echo ""
    printf "%.0s- " {1..30}
    echo ""
done
