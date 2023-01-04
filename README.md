# rsync-snapshot

This script offers automated snapshot-style backup using `rsync`. It creates incremental backups of files and directories to a local backup drive. 

## Features
- Each snapshot backup is saved under its own folder with a time stamp attached. Backed-up files and directories can be accessed and therefore restored directly.
- Unchanged files and directories are hardlinked to save space.
- Umount backup drive after each backup circle to protect data intergrity.
- Automatically rotate and purge old backups.
- A symlink `last` always pointing to the latest backup snapshot.

### This script is based on the ideas of several previous implementations
- *Easy automated snapshot-style backups with Linux and rsync* by Mikes Handy: [http://www.mikerubel.org/computers/rsync_snapshots/](http://www.mikerubel.org/computers/rsync_snapshots/)
- *Mount drive automatically to backup using rsync*: [https://frustratedtech.com/post/52316736743/bash-script-mount-drive-automatically-to-backup](https://frustratedtech.com/post/52316736743/bash-script-mount-drive-automatically-to-backup)

## Installation

```
git clone https://github.com/zhen-huan-hu/rsync-snapshot.git
```

Optionally, copy and move the script to `/usr/local/sbin`.

## Usage

```
Usage: rsync-snapshot.sh [OPTION]... SRC

Options
  -e      Specify backup exclusion file (default: /etc/backups/backup.exclusions)
  -d      Specify UUID registration file (default: /etc/backups/backup.disks)
  -p      Specify backup drive mounting point (default: /mnt)
  -n      Specify number of snapshots to keep (default: 5)
  -h      Display help
```
The script expects a file specifying files and directories to be excluded from backups. The default location is `/etc/backups/backup.exclusions` but can be re-specified using the `-e` option.

### Example of the backup exclusion file (for whole system backup)

```
/dev/*
/proc/*
/sys/*
/tmp/*
/run/*
/var/tmp/*
/var/cache/*
/media/*
/mnt/*
/lost+found
```

The script also requires an UUID registration file (default location: `/etc/backups/backup.disks`). Multiple UUIDs for the backup partition can be included in the file with one UUID per line (for potentially rotating the backup drives physically). The script will mount the partition based on the first matched UUID as the backup location.

If the backup partition is initially umounted, the script will mount the partition to the specified mounting point (default: `\mnt`). After the backup process, the partition will be umounted to protect data integrity. If the backup partition has already been mounted to a different location, the script will ignore the specified mounting point and keep it mounted after the backup process.

On the backup drive, the script will create a symlink `last` always pointing to the latest backup snapshot.

## Examples

Backup the home directory with exclusion file `~/exclusion_list.txt`:

```
./rsync-snapshot.sh -e ~/exclusion_list.txt ~/
```

Whole system backup:

```
sudo ./rsync-snapshot.sh /
```

### Add a cron job for automated backup

Use `sudo crontab -e` to add a cron job, such as:

```
5 0 * * * /usr/local/sbin/rsync-snapshot.sh /
```

This does daily backup at 0:05 am.

## LICENSE

GNU General Public License, version 2

Copyright (C) 2023  Zhen-Huan Hu

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
