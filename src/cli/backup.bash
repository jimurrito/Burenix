#!/usr/bin/env bash
#
# Runs backup systemd job
# Backup job is not ran under the current user's context
#

SOURCES_PATH="/etc/burenix/conf"
dataSource="${2}"

#
#
# Verbose display if datasource is not provided
if [[ -z "${dataSource}" ]]; then
    echo "No data source provided for backup. Please run 'burenix-cli ls' to see the available data sources."
    exit 0
fi

#
# Check that the datasource provided is valid
valid=$(ls ${SOURCES_PATH}/${dataSource}.json 2> /dev/null)
if [[ -z "${valid}" ]]; then
    echo "Data source: [${dataSource}] was not found. Please run 'burenix-cli ls' to see the available data sources."
    exit 1
fi

#
# Final confirmation
while [[ ! "$CONF" ]]; do
    echo -e "\nAre you sure you want to start the backup of this Data Source [${dataSource}]?"
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
srv="burenix-${dataSource}-backup.service"

#
# Start backup job
echo -e "\nBackup started..."
# Prestart systemd logging to stdout
journalctl -fu "${srv}" &
sudo systemctl restart "${srv}" || (echo "Backup job failed to start!" && exit 1)

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
    echo "Backup job completed!"
fi
