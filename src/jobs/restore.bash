#!/usr/bin/env bash
#
# restore script
#

# Pre-initialize lists
TARGETS=()

# Assigns CLI arguments
while getopts "n:d:t:k:o:psv" opt; do
    case "$opt" in
        # Name of the backup
        n)
            NAME="${OPTARG}"
            ;;
        # target paths
        t)
            TARGETS+=("${OPTARG}")
            ;;
        # Temporary Directory
        o)
            TEMP_DIR="${OPTARG}"
            ;;
        # Encryption key
        k)
            KEY_PATH="${OPTARG}"
            ENCRYPT=1
            ;;
        # Use SSH
        s)
            USE_SSH=1
            ;;
        # Use PIGZ
        p)
            USE_PIGZ=1
            ;;
        # CHECKSUM backup file
        v)
            CHECKSUM=1
            ;;
        # Unknown arg
        ?)
            echo "Unknown argument provided [-${opt} ${OPTARG}]."
            exit 1
            ;;
        #
    esac
done

#
#  Select first target for restore
TARGET_DIR=${TARGETS[0]}

# DEBUG OUTPUT
echo "NAME       = ${NAME}"
echo "TARGETS    = ${TARGETS[@]}"
echo "TARGET_DIR = ${TARGET_DIR}"
echo "TEMP_DIR   = ${TEMP_DIR}"
echo "USE_PIGZ   = ${USE_PIGZ}"
echo "USE_SSH    = ${USE_SSH}"
echo "ENCRYPT    = ${ENCRYPT}"
echo "KEY_PATH   = ${KEY_PATH}"
echo "CHECKSUM   = ${CHECKSUM}"

#
#  compression service
if [[ $USE_PIGZ ]]; then tarArgs="--use-compress-program=pigz";
else tarArgs="-z"; fi
#
#  Copy program
if [[ $USE_SSH ]]; then copyBin="scp"; else copyBin="cp -fr"; fi
#
# Encryption file ext
if [[ $ENCRYPT ]]; then eExt=".gpg"; fi
#
# Determine if we are going to do checksum
# If we are using GPG encrytion, no need to generate a checksum.
# Gpg does this check automatically.
if [[ $ENCRYPT && $CHECKSUM ]]; then
    # Frees variable
    CHECKSUM=
fi
#
# Select backup and copy to temp dir
restoreFiles=($(ls ${TARGET_DIR}/burenix-${NAME}-*.tar.gz${eExt}))
# reverse list for newest backup
restoreFiles=($(echo ${restoreFiles[@]} | tr ' ' '\n' | tac | tr '\n' ' '))
chosenFile=${restoreFiles[0]}
#
# greeting
echo "Starting restore: [ ${chosenFile} ] => [ ${NAME} ]"
#
# Copy backup to temp dir from destination
echo "Copying backup data [${chosenFile}] to temporary directory [${TEMP_DIR}]."
${copyBin} "${chosenFile}" "${TEMP_DIR}"
restoreFileTemp="${TEMP_DIR}/$(basename ${chosenFile})"
#
# Run checksum validation on backup
if [[ $CHECKSUM ]]; then
    # generate checksum file
    baseName=$(basename ${chosenFile})
    shaFile="${TARGET_DIR}/${baseName%.tar*}.checksum"
    # Copy checksum file to temp
    echo "Copying checksum file from restore target. [${shaFile}]"
    ${copyBin} "${shaFile}" "${TEMP_DIR}"
    # get new name
    shaFileTemp="${TEMP_DIR}/$(basename ${shaFile})"
    # run validation
    echo "Running checksum validation"
    sha256sum -c "${shaFile}" || (echo "Checksum validation failed. Exiting..."; exit 1)
    echo "Checksum validation succeeded!"
fi
#
#
# Perform restore
if [[ $ENCRYPT ]]; then
    # Decrypt and decompress
    echo "Decrypting and decompressing backup [ ${restoreFileTemp} ] to restore destination under root"
    gpg --batch --passphrase-file "${KEY_PATH}" -d "${restoreFileTemp}" | tar "${tarArgs}" -C / -xf -
else
    # Non encrypted
    echo "Decompressing backup [ ${restoreFileTemp} ] to restore destination under root"
    tar "${tarArgs}" -C / -xf "${restoreFileTemp}"
fi
#
# Cleanup
echo "Removing temporary backup file [${restoreFileTemp}]"
rm -fr ${restoreFileTemp}
# delete sha file and ignore errors if it doesnt exist
rm -fr "${shaFileTemp}" 2> /dev/null
#
#
echo "Restore Completed!"
