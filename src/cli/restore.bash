#!/usr/bin/env bash
#
# Runs backup systemd job
# Backup job is not ran under the current user's context
#

SOURCES_PATH="/etc/burenix/conf"
DATA_SOURCE="${1}"


#
# Verbose display if DATA_SOURCE is not provided
if [[ -z "${DATA_SOURCE}" ]]; then
    echo "No data source provided for backup. Please run 'burenix-cli ls' to see the available data sources."
    exit 0
fi

#
# Check that the DATA_SOURCE provided is valid
if [[ -z $(ls ${SOURCES_PATH}/${DATA_SOURCE}.json 2> /dev/null) ]]; then
    echo "Data source: [${DATA_SOURCE}] was not found. Please run 'burenix-cli ls' to see the available data sources."
    exit 1
fi

#
# Final confirmation
while [[ ! "$CONF" ]]; do
    echo -e "\nAre you sure you want to start the restore of this Data Source [${DATA_SOURCE}]?"
    read -p "[y/n]: " RESP
    case "${RESP}" in
        y|Y)
            CONF=1
            ;;
        n|N)
            exit 0
            ;;
        ?)
            echo -e "\nInvalid input! \n"
            ;;
    esac
done

#
srv="burenix-${DATA_SOURCE}-restore.service"

#
# Start backup job
echo -e "\nRestore started..."
# Prestart systemd logging to stdout
journalctl -fu "${srv}" &
sudo systemctl restart "${srv}" || (echo "Restore job failed to start!" && exit 1)

#
# Stop sample logging after interval
sleep 3
# Kill background logging
kill %1

#
# check if the service is still running to determine status
buStatus=$(systemctl show "${srv}" --property SubState)
if [[ "${buStatus}" == "SubState=active" ]]; then
    echo "Run 'journalctl -fu "${srv}"' to continue tracking the progreess."
else
    echo "Restore job completed!"
fi
