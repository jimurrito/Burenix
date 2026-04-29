#!/usr/bin/env bash
#
# Backup script
#

# Pre-initialize targets list
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
            SOURCES="${OPTARG}"
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
echo "SOURCES = ${SOURCES}"
echo "TARGETS = ${TARGETS}"
echo "ROLLOVER = ${ROLLOVER}"
echo "KEY_PATH = ${KEY_PATH}"
echo "TEMP_DIR = ${TEMP_DIR}"
echo "USE_PIGZ = ${USE_PIGZ}"
echo "USE_SSH = ${USE_SSH}"
echo "NO_ENCRYPT = ${NO_ENCRYPT}"

# compression service
if [[ -n "${USE_PIGZ}" ]]; then COMPRESSION_ARG="--use-compress-program=pigz";
else COMPRESSION_ARG="-z"; fi
# Copy program
if [[ -n "${USE_SSH}" ]]; then COPY_BIN="scp"; else COPY_BIN="cp -fr"; fi
#
if [[ "$NO_ENCRYPT" ]]; then
    # Non encrypted
    BACKUP_FILE_PATH="${TEMP_DIR}/backup-${NAME}-$(date +"%Y-%m-%dT%H%M").tar.gz"
    echo "Compressing data source(s) [${SOURCES}] to [${BACKUP_FILE_PATH}] and using no encryption"
    tar "${COMPRESSION_ARG}" -cf "${BACKUP_FILE_PATH}" ${SOURCES}
else
    # Compress and encrypt data
    BACKUP_FILE_PATH="${TEMP_DIR}/backup-${NAME}-$(date +"%Y-%m-%dT%H%M").tar.gz.gpg"
    echo "Compressing data source(s) [${SOURCES}] to [${BACKUP_FILE_PATH}] and encrypting using key @ [${KEY_PATH}]"
    # use '-' for tar output file name '-f' so it will pass the output to gpg for encryption.
    tar "${COMPRESSION_ARG}" -cf - ${SOURCES} | gpg --batch --passphrase-file ${KEY_PATH} -c  > "${BACKUP_FILE_PATH}"
fi

# Copy file to target locations
echo "Coping backup data [${BACKUP_FILE_PATH}] to [${#TARGETS[@]}] target(s)."
for target in ${TARGETS[@]}; do
    echo "Ensuring target dir exists..."
    mkdir -p "${target}"
    echo "[${BACKUP_FILE_PATH}] -> [${target}]"
    ${COPY_BIN} "${BACKUP_FILE_PATH}" ${target}
    echo "Cleaning up old archives over [${ROLLOVER}] days old @ [${target}]"
    find "${target}/." -mtime "+${ROLLOVER}" -delete
done

# Cleanup
echo "Cleaning up temporary backup file."
\rm -fr ${BACKUP_FILE_PATH}
