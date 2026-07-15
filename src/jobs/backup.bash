#!/usr/bin/env bash
#
# Backup script
#

# Pre-initialize lists
SOURCES=()
TARGETS=()

# Assigns CLI arguments
while getopts "n:d:t:r:k:o:psv" opt; do
    case "$opt" in
        # Name of the backup
        n)
            NAME="${OPTARG}"
            ;;
        # Data source path
        d)
            SOURCES+=("${OPTARG}")
            ;;
        # target paths
        t)
            TARGETS+=("${OPTARG}")
            ;;
        # Temporary Directory
        o)
            TEMP_DIR="${OPTARG}"
            ;;
        # rollover interval
        r)
            ROLLOVER="${OPTARG}"
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

# DEBUG OUTPUT
echo "NAME       = ${NAME}"
echo "SOURCES    = ${SOURCES[@]}"
echo "TARGETS    = ${TARGETS[@]}"
echo "TEMP_DIR   = ${TEMP_DIR}"
echo "ROLLOVER   = ${ROLLOVER}"
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
# greeting
echo "Starting backup: [ ${NAME} ] => [ ${TARGETS[@]} ]"
#
# Create temp backup path for compression
backupFileTemp="${TEMP_DIR}/burenix-${NAME}-$(date +"%Y-%m-%dT%H%M").tar.gz${eExt}"
#
# perform compression/encryption
if [[ $ENCRYPT ]]; then
    # Compress and encrypt data
    echo "Compressing and Encrypting data source(s) [${SOURCES}] to temporary directory [${backupFileTemp}]"
    # use '-' for tar output file name '-f' so it will pass the output to gpg for encryption.
    tar "${tarArgs}" -cf - "${SOURCES}" | gpg --batch --passphrase-file ${KEY_PATH} -c  > "${backupFileTemp}"
else
    # Non encrypted
    echo "Compressing data source(s) [${SOURCES}] to temporary directory [${backupFileTemp}]"
    tar "${tarArgs}" -cf "${backupFileTemp}" "${SOURCES}"
fi
#
# generate file integrity hash. SHA256.
if [[ $CHECKSUM ]]; then
    shaFile="${backupFileTemp%.tar*}.checksum"
    echo "Creating checksum file from backup. [$(basename $shaFile)]"
    sha256sum "${backupFileTemp}" > "${shaFile}"
fi
#
# Copy file to target locations
echo "Coping backup data [${backupFileTemp}] to [${#TARGETS[@]}] target(s)."
for target in ${TARGETS[@]}; do
    #
    echo "=> [${target}]"
    mkdir -p "${target}"
    #
    #  Copy compressed backup to destination target
    ${copyBin} "${backupFileTemp}" "${target}"
    #
    #  Copy checksum file if applicable
    if [[ $CHECKSUM ]]; then ${copyBin} "${shaFile}" "${target}"; fi
    #
    # rollover old backups
    if [[ $ROLLOVER ]]; then
        echo "Cleaning up old archives over [${ROLLOVER}] days old @ [${target}]"
        find "${target}/." -mtime "+${ROLLOVER}" -delete
    fi
done
#
# Cleanup
echo "Removing temporary backup file [${backupFileTemp}]"
rm -fr "${backupFileTemp}"
# delete sha file and ignore errors if it doesnt exist
rm -fr "${shaFile}" 2> /dev/null
#
#
echo "Backup Completed!"
