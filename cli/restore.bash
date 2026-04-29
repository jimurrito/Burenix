#!/usr/bin/env bash
#

#
# Restore script for backup-restore
# This script is meant to be executed via the backup-restore cli
#

#
# RESTORE PROCESS
#
# > take desired backup, and copy back to temp
# > decrypt and delete .gpg version
# > extract content to '/' as files are stored with path from root dir.
# > delete tar
#

#
# Statics
SOURCES_PATH="/etc/burenix/conf"
KEY_PATH="${1}"

#
# WIZARD ONLY FOR NOW
#

#
# Select Data Source
echo -e "Restore Wizard\n"
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
        SELECT_DS_NAME="${SOURCE_PARSE_LIST[$SELECT]}" # Friendly name of data-source
        SELECT_DS_TGTS=($(cat ${DATA_SOURCES[$SELECT]})) # target path(s)
    else
        # bad input
        echo -e "\nInput [${SELECT}] is out of bounds! \n"
    fi
done



# IMPORTANT VARS
#
# SELECT_DS_NAME => friendly data source name
# SELECT_DS_TGTS => Array of target Paths
#

#
# Select Data Path
echo -e "\n\nData Source Name: [${SELECT_DS_NAME}]\n"
PATH_COUNT="${#SELECT_DS_TGTS[@]}"
SELECT=-1
while [[ ${SELECT} -le -1 || ${SELECT} -ge ${PATH_COUNT} ]]; do
    # Data Path selection screen
    for ((i = 0 ; i < $PATH_COUNT ; i++)); do
        echo "[${i}] - ${SELECT_DS_TGTS[$i]}"
    done
    # take input
    read -p "Select a backup target [0-$(( PATH_COUNT - 1 ))]: " SELECT
    # Input check
    if [[ ${SELECT} -gt -1 && ${SELECT} -lt ${PATH_COUNT} ]]; then
        # Input OK
        SELECT_DS_PATH="${SELECT_DS_TGTS[$SELECT]}" # target path for restore
    else
        # bad input
        echo -e "\nInput [${SELECT}] is out of bounds! \n"
    fi
done

# IMPORTANT VARS
#
# SELECT_DS_NAME => friendly data source name
# SELECT_DS_TGTS => Array of target Paths
# SELECT_DS_PATH => target backup path
#

#
# Select snapshot
echo -e "\n\nBackup Target [${SELECT_DS_PATH}]\n"
SNAPS=($(ls ${SELECT_DS_PATH}/backup-${SELECT_DS_NAME}*.tar.gz*))
SNAP_COUNT="${#SNAPS[@]}"
SELECT=-1
while [[ ${SELECT} -le -1 || ${SELECT} -ge ${SNAP_COUNT} ]]; do
    # Data Path selection screen
    for ((i = 0 ; i < $SNAP_COUNT ; i++)); do
        echo "[${i}] - ${SNAPS[$i]}"
    done
    # take input
    read -p "Select a snapshot [0-$(( SNAP_COUNT - 1 ))]: " SELECT
    # Input check
    if [[ ${SELECT} -gt -1 && ${SELECT} -lt ${SNAP_COUNT} ]]; then
        # Input OK
        SELECT_DS_SNAP="${SNAPS[$SELECT]}" # target snap for restore
    else
        # bad input
        echo -e "\nInput [${SELECT}] is out of bounds! \n"
    fi
done

# IMPORTANT VARS
#
# SELECT_DS_NAME => friendly data source name
# SELECT_DS_TGTS => Array of target Paths
# SELECT_DS_PATH => target backup path
# SELECT_DS_SNAP => Path to desired backup snapshot
#

#
# Final confirmation
while [[ ! "$CONF" ]]; do
    echo -e "\nAre you sure you want to restore using this backup snapshot [${SELECT_DS_SNAP}]?"
    read -p "[y/n]: " RESP
    case "${RESP}" in
        y|Y)
            CONF=1
            ;;
        n|N)
            exit 1
            ;;
        ?)
            echo -e "\nInvalid input! \n"
            ;;
    esac
done

#
# Prep for restore
TEMP_DIR="$(cat ${SOURCES_PATH}/${SELECT_DS_NAME}.tmp.conf)"

# Copy to temp directory
echo "Copying snapshot to temp dir [${TEMP_DIR}]..."
cp -fv "${SELECT_DS_SNAP}" "${TEMP_DIR}"
TEMP_SNAP_PATH="${TEMP_DIR}/$(basename ${SELECT_DS_SNAP})"

#
echo -e "\nStarting restore. Do not stop this operation or risk corruption.\n"

#
# Decrypt or not 
if [[ "${SELECT_DS_SNAP}" =~ ".gpg" ]]; then
    echo -e "Decrypting backup snapshot using backup key @ [${KEY_PATH}]...\n"
    # we need to decrypt 
    gpg --batch --passphrase-file "${KEY_PATH}" -d "${TEMP_SNAP_PATH}" | tar --use-compress-program=pigz -C / -xf -
else
    # no decryption needed
    tar --use-compress-program=pigz -C / -xf "${TEMP_SNAP_PATH}"
fi

echo -e "Restore completed!"

#
# Remove temp file
echo -e "Cleaning up temporary files..."
\rm -fr "${TEMP_SNAP_PATH}"

#
echo "done"
