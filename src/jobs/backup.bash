#!/usr/bin/env bash
#
# Backup script
#

# Pre-initialize lists
SOURCES=()
TARGETS=()

# Assigns CLI arguments
while getopts "n:d:t:r:k:o:psx" opt; do
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
        # rollover interval
        r)
            ROLLOVER="${OPTARG}"
            ;;
        # Encryption key
        k)
            KEY_PATH="${OPTARG}"
            ;;
        # Temporary Directory
        o)
            TEMP_DIR="${OPTARG}"
            ;;
        # Use SSH
        s)
            USE_SSH=1
            ;;
        # Use PIGZ
        p)
            USE_PIGZ=1
            ;;
        # No encryption
        x)
            NO_ENCRYPT=1
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
echo "NAME = ${NAME}"
echo "SOURCES = ${SOURCES[@]}"
echo "TARGETS = ${TARGETS[@]}"
echo "ROLLOVER = ${ROLLOVER}"
echo "KEY_PATH = ${KEY_PATH}"
echo "TEMP_DIR = ${TEMP_DIR}"
echo "USE_PIGZ = ${USE_PIGZ}"
echo "USE_SSH = ${USE_SSH}"
echo "NO_ENCRYPT = ${NO_ENCRYPT}"

#
#  compression service
if [[ -n "${USE_PIGZ}" ]]; then COMPRESSION_ARG="--use-compress-program=pigz";
else COMPRESSION_ARG="-z"; fi
#
#  Copy program
if [[ -n "${USE_SSH}" ]]; then COPY_BIN="scp"; else COPY_BIN="cp -fr"; fi
#
# Encryption file ext
if [[ -z "$NO_ENCRYPT" ]]; then E_EXT=".gpg"; fi
#
# greeting
echo "Starting backup: [ ${NAME} ] => [ ${TARGETS[@]} ]"
#
# Create temp backup path for compression
BACKUP_FILE_TEMP="${TEMP_DIR}/burenix-${NAME}-$(date +"%Y-%m-%dT%H%M").tar.gz${E_EXT}"
#
# perform compression/encryption
if [[ -n "$NO_ENCRYPT" ]]; then
    # Non encrypted
    echo "Compressing data source(s) [${SOURCES}] to temporary directory [${BACKUP_FILE_TEMP}]"
    tar "${COMPRESSION_ARG}" -cf "${BACKUP_FILE_TEMP}" "${SOURCES}"
else
    # Compress and encrypt data
    echo "Compressing and Encrypting data source(s) [${SOURCES}] to temporary directory [${BACKUP_FILE_TEMP}]"
    # use '-' for tar output file name '-f' so it will pass the output to gpg for encryption.
    tar "${COMPRESSION_ARG}" -cf - "${SOURCES}" | gpg --batch --passphrase-file ${KEY_PATH} -c  > "${BACKUP_FILE_TEMP}"
fi
#
# Copy file to target locations
echo "Coping backup data [${BACKUP_FILE_TEMP}] to [${#TARGETS[@]}] target(s)."
for target in ${TARGETS[@]}; do
    echo "=> [${target}]"
    mkdir -p "${target}"
    # Copy compressed backup to destination target
    ${COPY_BIN} "${BACKUP_FILE_TEMP}" ${target}
    # rollover
    if [[ -n ${ROLLOVER} ]]; then
        echo "Cleaning up old archives over [${ROLLOVER}] days old @ [${target}]"
        find "${target}/." -mtime "+${ROLLOVER}" -delete
    fi
done
#
# Cleanup
echo "Removing temporary backup file [${BACKUP_FILE_TEMP}]"
\rm -fr ${BACKUP_FILE_TEMP}
#
#
echo "Backup Completed!"
