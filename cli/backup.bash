#!/usr/bin/env bash
#
# Runs backup systemd job
# Backup job is not ran under the current user's context
#

SOURCES_PATH="/etc/burenix/conf"
PROVIDED_DS="${2}"

#
# Run wizard if no DS provided
if [[ -z "${PROVIDED_DS}" ]]; then
    #
    # Wizard
    DATA_SOURCES=($(ls ${SOURCES_PATH}/*tgt.conf))
    SOURCE_COUNT="${#DATA_SOURCES[@]}"
    SELECT=-1
    while [[ ${SELECT} -le -1 || ${SELECT} -ge ${SOURCE_COUNT} ]]; do
        SOURCE_PARSE_LIST=() # initialize
        # Data Source selection screen
        for ((i = 0 ; i < $SOURCE_COUNT ; i++)); do
            parsed=$(basename "${DATA_SOURCES[$i]}" | cut -d. -f1)
            SOURCE_PARSE_LIST+=("${parsed}")
            echo "[${i}] - ${parsed}"
        done
        # take input
        read -p "Select a data source [0-$(( SOURCE_COUNT - 1 ))]: " SELECT
        # Input check
        if [[ ${SELECT} -gt -1 && ${SELECT} -lt ${SOURCE_COUNT} ]]; then
            # Input OK
            DS="${SOURCE_PARSE_LIST[$SELECT]}" # Friendly name of data-source
        else
            # bad input
            echo -e "\nInput [${SELECT}] is out of bounds! \n"
        fi
    done
else
    #
    # Direct run
    DS="${PROVIDED_DS}"
fi

#
# Final confirmation
while [[ ! "$CONF" ]]; do
    echo -e "\nAre you sure you want to start the backup of this Data Source [${DS}]?"
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

echo -e "\n Backup started..."
systemctl restart backup-${DS}.service &

echo "Run 'journalctl -u backup-${DS}.service --follow' to track the progress."
