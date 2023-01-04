# rsync-snapshot

This script offers automated snapshot-style backup using `rsync`. It creates incremental backups of files and directories to a local backup drive or directory. 

## Features
- Each snapshot backup is saved under its own directory with a time stamp attached. Backed-up files and directories can be accessed and therefore restored directly.
- Unchanged files and directories are hardlinked to save space.
- (Optionally) certain files and directories can be excluded from the backup process.
- (Optionally) a standalone backup drive can be mounted before and umounted after each backup circle to protect data intergrity.
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
Usage: rsync-snapshot.sh [OPTION]... SRC DST

Options
  -e      Specify backup exclusion file
  -d      Specify UUID registration file
  -n      Specify number of snapshots to keep (default: 5)
  -h      Display help
```

The parameter `SRC` specifies the backup source while `DST` indicates the backup destination.

After each backup circle, the script will create a symlink `last` always pointing to the latest backup snapshot.

Optionally, a plain text file (e.g.: `/etc/backups/backup.exclusions`) can be specified using the `-e` option to indicate files and directories to be excluded from the backup process.

### Example - A backup exclusion file for whole system backup

```
/dev/*
/proc/*
/sys/*
/tmp/*
/run/*
/var/tmp/*
/var/cache/*
/var/run/*
/media/*
/mnt/*
/lost+found
```

Optionally, a backup drive registration file (e.g.: `/etc/backups/backup.drives`) can be specified using the `-d` option. Multiple UUIDs for potential backup partitions can be included in the file with one UUID per line (for physically rotating the backup drives).

If a registered backup partition is initially umounted, the script will mount it to the specified backup destination `DST`. After the backup process, the partition will be automatically umounted to protect data integrity. If a registered backup partition is already mounted, the script will ignore the specified backup destination `DST` and keep the backup drive at its current mount point after the backup process.

## Examples

Backup the home directory to `/backups`:

```
sudo ./rsync-snapshot.sh ~/ /backups
```

Whole system backup with backup exclusion file `/etc/backups/backup.exclusions` to backup drive specified in `/etc/backups/backup.drives` mounted at `/mnt`:

```
sudo ./rsync-snapshot.sh -e /etc/backups/backup.exclusions -d /etc/backups/backup.drives / /mnt
```

### Add a cron job for automated backup

Use `sudo crontab -e` to add a cron job, such as:

```
5 0 * * * /usr/local/sbin/rsync-snapshot.sh -e /etc/backups/backup.exclusions -d /etc/backups/backup.drives / /mnt
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
