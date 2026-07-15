#!/usr/bin/env bash
#
# Shows the available backup sources and snapshots
#

SOURCES_PATH="/etc/burenix/conf"
PROVIDED="${1}"

DATA_SOURCES=($(ls ${SOURCES_PATH}/*.json))

#
# logic function
# takes datasource config path
logic(){
    dSourcePath="${1}"
    # load datasource config
    name=$(cat $dSourcePath | jq -r '.name')
    targets=($(cat $dSourcePath | jq -r '.targets.[]'))
    #
    echo -e "\nData Source: [${name}]\n"
    #
    ctr=0
    #
    # Get snapshots from targets
    for targ in ${targets[@]}; do
        if [[ $ctr == 0 ]]; then prime="[*]"; else prime=""; fi
        echo -e "Backup Target: [ ${targ} ] ${prime}"
        #
        snaps=($(ls ${targ}/burenix-${name}-*.tar.gz* 2> /dev/null))
        if [[ ${#snaps[@]} == 0 ]]; then
            echo -e "< No Snapshots found >";
        else
            echo -e "Available Snapshots"
            # reverse list to get newest first
            snaps=($(echo ${snaps[@]} | tr ' ' '\n' | tac | tr '\n' ' '))
        fi
        #
        ctrN=0
        for snap in ${snaps[@]}; do
            # check if checksum file exists for this
            baseName=$(basename ${snap})
            if [[ $(ls "${targ}/${baseName%.tar*}.checksum" 2> /dev/null) ]]; then check="[C]"; else check=""; fi
            if [[ $ctrN == 0 && $ctr == 0 ]]; then prime="[*]"; ctrN=1; else prime=""; fi
            echo "  -> ${baseName} ${check}${prime}"
        done
        # remove prime tag from the next
        ctr=1;
        echo ""
    done
}

#
# using provided data source
if [[ $PROVIDED ]]; then
    #
    # Check that the PROVIDED is valid data source
    if [[ -z $(ls ${SOURCES_PATH}/${PROVIDED}.json 2> /dev/null) ]]; then
        echo "Data source: [${PROVIDED}] was not found. Please run 'burenix-cli ls' to see the available data sources."
        exit 1
    fi
    # run output logic
    logic "${SOURCES_PATH}/${PROVIDED}.json"
    #
    echo ""
    printf "%.0s- " {1..30}
    echo ""
else
    # Per data source
    for dSourcePath in ${DATA_SOURCES[@]}; do
        #
        logic "${dSourcePath}"
        #
        echo ""
        printf "%.0s- " {1..30}
        echo ""
    done
fi

echo -e "\n [*] = Primary/Used for Restores \n [C] = Uses Checksum"
