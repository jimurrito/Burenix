#!/usr/bin/env bash
#
# restore script
#

# Pre-initialize lists
TARGETS=()

# Assigns CLI arguments
while getopts "n:d:t:k:o:psx" opt; do
    case "$opt" in
        # Name of the backup
        n)
            NAME="${OPTARG}"
            ;;
        # target paths
        t)
            TARGETS+=("${OPTARG}")
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

#
#  Select first target for restore
TARGET_DIR=${TARGETS[0]}

# DEBUG OUTPUT
echo "NAME       = ${NAME}"
echo "TARGETS    = ${TARGETS[@]}"
echo "TARGET_DIR = ${TARGET_DIR}"
echo "KEY_PATH   = ${KEY_PATH}"
echo "TEMP_DIR   = ${TEMP_DIR}"
echo "USE_PIGZ   = ${USE_PIGZ}"
echo "USE_SSH    = ${USE_SSH}"
echo "NO_ENCRYPT = ${NO_ENCRYPT}"

#
#  compression service
if [[ -n "${USE_PIGZ}" ]]; then COMPRESSION_ARG="--use-compress-program=pigz"; fi
#
# Determine which copy program to use
if [[ -n "${USE_SSH}" ]]; then COPY_BIN="scp"; else COPY_BIN="cp -fr"; fi
#
# Encryption file ext
if [[ -n "${NO_ENCRYPT}" ]]; then E_EXT=".gpg"; fi
#
# Select backup and copy to temp dir
RESTORE_FILES=($(ls "${TARGET_DIR}/burenix-${NAME}-*.tar.gz${E_EXT}"))
RESTORE_FILE_CHOSEN=${RESTORE_FILES[0]}
#
# greeting
echo "Starting restore: [ ${RESTORE_FILE_CHOSEN} ] => [ ${NAME} ]"
#
# Copy backup to temp dir
echo "Copying backup data [${RESTORE_FILE_CHOSEN}] to temporary directory [${TEMP_DIR}]."
${COPY_BIN} -fv "${RESTORE_FILE_CHOSEN}" "${TEMP_DIR}"
RESTORE_FILE_TEMP="${TEMP_DIR}/$(basename ${RESTORE_FILE_CHOSEN})"
#
# Perform restore
if [[ "$NO_ENCRYPT" ]]; then
    # Non encrypted
    echo "Decompressing backup [ ${RESTORE_FILE_TEMP} ] to restore destination under root"
    tar "${COMPRESSION_ARG}" -C / -xf "${RESTORE_FILE_TEMP}"
else
    # Decrypt and decompress
    echo "Decrypting and decompressing backup [ ${RESTORE_FILE_TEMP} ] to restore destination under root"
    gpg --batch --passphrase-file "${KEY_PATH}" -d "${RESTORE_FILE_TEMP}" | tar "${COMPRESSION_ARG}" -C / -xf -
fi
#
# Cleanup
echo "Removing temporary backup file [${RESTORE_FILE_TEMP}]"
\rm -fr ${RESTORE_FILE_TEMP}
#
#
echo "Restore Completed!"
