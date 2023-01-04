#!/bin/bash

set -eu

# Require root privilege to run
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root" 1>&2
    exit 1
fi

# Check if there is already an instance running
exec {LOCK_FD}< "$0"
if ! flock --nonblock "$LOCK_FD"; then
    echo "An instance is already running" 1>&2
    exit 1
fi

#
# Script configuration
#

EXCLUSION_FILE=
UUID_FILE=
NKEEP=5
AUTO_UMOUNT=0

# Parse options
while getopts ":e:d:n:h" OPTION; do
    case "$OPTION" in
    e) # Specify backup exclusion file
        if [ ! -f "$OPTARG" ]; then
            echo "Invalid backup exclusion file $OPTARG" 1>&2
            exit 1
        else
            EXCLUSION_FILE="$OPTARG"
        fi
        ;;
    d) # Specify drive UUID registration file
        if [ ! -f "$OPTARG" ]; then
            echo "Invalid drive UUID registration file $OPTARG" 1>&2
            exit 1
        else
            UUID_FILE="$OPTARG"
        fi
        ;;
    n) # Specify number of snapshots to keep
        NKEEP="$OPTARG"
        ;;
    h) # Display this help
        echo "Usage: $(basename "$0") [-e EXCLUSION_FILE] [-d UUID_FILE] [-n NKEEP] [-h] SRC DEST"
        exit 0
        ;;
    *)
        echo "Invalid option: -$OPTARG" 1>&2
        echo "Usage: $(basename "$0") [-e EXCLUSION_FILE] [-d UUID_FILE] [-n NKEEP] [-h] SRC DEST" 1>&2
        exit 1
        ;;
    esac
done
shift "$((OPTIND-1))"

# Backup source
if [ $# -ne 2 ]; then
    echo 'Invalid number of parameters' 1>&2
    exit 1
else
    if [ ! -e "$1" ]; then
        echo "Invalid backup source" 1>&2
        exit 1        
    else
        BACKUP_SRC="$1"
    fi
    if [ ! -d "$2" ]; then
        echo "Invalid backup destination" 1>&2
        exit 1
    else
        BACKUP_DST="$2"
    fi
fi

echo "Backup source: $BACKUP_SRC"
echo "Backup destination: $BACKUP_DST"
echo "Backup exclusion file: $EXCLUSION_FILE"
echo "Drive UUID registration file: $UUID_FILE"
echo "Number of snapshots to keep: $NKEEP"

#
# End of script configuration
#

# If an UUID of a backup drive is provided, try to mount it to the backup destination
if [ -n "$UUID_FILE" ]; then
    # Find whether any connected block device is a registered backup drive
    mapfile -t ALLOWED_UUIDS < "$UUID_FILE"
    for UUID in "${ALLOWED_UUIDS[@]}"; do
        if lsblk --noheadings --output fstype "/dev/disk/by-uuid/$UUID" 2> /dev/null | grep --quiet --line-regexp 'ext[2-4]'; then
            echo "Found block device $UUID registered for backup"
            break
        fi
        UUID=
    done

    if [ -z "$UUID" ]; then
        echo 'No eligible backup disk connected' 1>&2
        exit 1
    fi

    # Find the mount point if the drive is already mounted
    BACKUP_DIR="$(lsblk --noheadings --output mountpoint "/dev/disk/by-uuid/$UUID")"

    if [ -n "$BACKUP_DIR" ]; then
        echo "Drive $UUID is already mounted on $BACKUP_DIR"
        echo "Use $BACKUP_DIR as backup directory instead"
        AUTO_UMOUNT=1
    else
        BACKUP_DIR="$(realpath -m "$BACKUP_DST")"

        # Check if the mount point is occupied by another drive
        if mountpoint -q "$BACKUP_DIR"; then
            echo "Mount point $BACKUP_DIR is occupied" 1>&2
            exit 1
        else
            mount -U "$UUID" "$BACKUP_DIR"
        fi
    fi
fi
else
    BACKUP_DIR="$(realpath -m "$BACKUP_DST")"
fi

# Backup name schema
LASTDIR="$BACKUP_DIR/last"
DESTDIR="$BACKUP_DIR/$(date +%F-%T)-$(hostname)"

#
# Create snapshot
#

echo "Starting rsync backup for $(date)"

if [ -n "$EXCLUSION_FILE" ]; then
    rsync -aAXx --delete \
        --itemize-changes --stats --human-readable \
        --delete-excluded --exclude-from="$EXCLUSION_FILE" \
        --link-dest="$LASTDIR" "$BACKUP_SRC" "$DESTDIR"
else
    rsync -aAXx --delete \
        --itemize-changes --stats --human-readable \
        --link-dest="$LASTDIR" "$BACKUP_SRC" "$DESTDIR"
fi

# Touch the dir to reflect the snapshot time
touch "$DESTDIR"

echo "Completed rsync backup for $(date)"

#
# Clean up
#

# Remove symlink to previous snapshot
rm --force "$LASTDIR"

# Create new symlink to latest snapshot for the next backup to hardlink
ln -s --relative "$DESTDIR" "$LASTDIR"

# Purge expired snapshots
mapfile -t SNAPSHOTS < <(find "$BACKUP_DIR" -maxdepth 1 -type d -regextype posix-extended -regex "$BACKUP_DIR/[0-9]{4}(-[0-9]{2}){3}(:[0-9]{2}){2}-$(hostname)" 2> /dev/null | sort)

echo "Existing snapshots under $BACKUP_DIR"
printf '%s\n' "${SNAPSHOTS[@]}"

let NEXPIRED=${#SNAPSHOTS[@]}-$NKEEP
if [ $NEXPIRED -gt 0 ]; then
    echo "$NEXPIRED snapshot(s) expired"
    COUNTER=0
    while [ $COUNTER -lt $NEXPIRED ]; do
        rm -r --force "${SNAPSHOTS[$COUNTER]}"
        echo "Expired snapshot ${SNAPSHOTS[$COUNTER]} was purged"
        let COUNTER+=1
    done
fi

if [ -n "$UUID" ]; then
    echo "Backup drive used: $(df -h --output=pcent "/dev/disk/by-uuid/$UUID" | sed 1d)"

    # Unmount backup directory
    if [ $AUTO_UMOUNT -eq 0 ]; then
        echo "Unmount $BACKUP_DIR"
        umount "$BACKUP_DIR"
    fi
fi
