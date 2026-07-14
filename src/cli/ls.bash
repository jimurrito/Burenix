#!/usr/bin/env bash
#
# Shows the available backup sources and snapshots
#

SOURCES_PATH="/etc/burenix/conf"
DATA_SOURCES=($(ls ${SOURCES_PATH}/*.json))

# Per data source
for dSource in ${DATA_SOURCES[@]}; do
    # load datasource config
    name=$(cat $dSource | jq -r '.name')
    targets=($(cat $dSource | jq -r '.targets.[]'))
    #
    echo -e "\nData Source: [${name}]\n"
    #
    ctr=0
    #
    # Get snapshots from targets
    for targ in ${targets[@]}; do
        prime=""
        if [[ $ctr == 0 ]]; then prime="[*]"; else prime=""; fi
        echo -e "Backup Target: [ ${targ} ] ${prime}"
        snaps=($(ls ${targ}/burenix-${name}-*.tar.gz* 2> /dev/null))
        # reverse list to get newest first
        snaps=($(echo ${snaps[@]} |tr ' ' '\n'|tac|tr '\n' ' '))
        if [[ ${#snaps[@]} == 0 ]]; then
            echo -e "< No Snapshots found >";
        else
            echo -e "Available Snapshots"
        fi
        ctrN=0
        for snap in ${snaps[@]}; do
            if [[ $ctrN == 0 && $ctr == 0 ]]; then prime="[*]"; ctrN=$((ctrN+1)); else prime=""; fi
            echo "  -> $(basename ${snap}) ${prime}"
        done
        # remove prime tag from the next
        ctr=$((ctr+1));
        echo ""
    done
    #
    #
    echo ""
    printf "%.0s- " {1..30}
    echo ""
done

echo -e "\n [*] = Primary/Used for Restores"
