#!/bin/sh
# Dumpnrotate V161023 - Simple rotating database dumping using mysqldump
# Written by Pasi Korkalo / OUTI Libraries

# GPL3 on later applies.

# Get configuration, you can place your configs in a directory of your choice.
# /etc/dumpdatabases/ would be a reasonable candidate

# For examples see hourlydump.conf and dailydump.conf.
if test -e "$1"; then
  . "$1"
else
  echo "Enter the name of the configuration file."
  exit 1
fi

# Nag about missing parameters.
if test -z "$databasename" || test -z "$dumpdir" || test -z "$databaseuser" || test -z "$databasepasswd"; then
  echo "Some of the required variables are not defined in the configuration file."
  exit 1
fi

# With -1 keep the dumps for 100 years, preserving 100000 dumps (in practice never remove anything not specifically defined to be removed).
test $keepdays -ge 0 2> /dev/null || keepdays="36525"
test $keepnumber -ge 0 2> /dev/null || keepnumber="100000"

echo "$(date) Keep dumps for $keepdays days or at least $keepnumber dumps."

# Ensure that we have the target directory for the dump + restrict permissions for the dir and dumps.
umask 077; mkdir -p $dumpdir

# Remove expired dumps.
IFS='
'
for file in $(ls -rt $dumpdir/${databasename}_*.sql* 2> /dev/null); do
  test $(ls $dumpdir/${databasename}_*.sql* | wc -l) -le $keepnumber && echo "$(date) Preserving at least $keepnumber files, no more files to remove." && break
  test $(date +%s -r $file) -gt $(date +%s --date="$keepdays days ago") && echo "$(date) Skipping the removal of files newer than $keepdays days." && break 
  echo "$(date) $(rm -v $file)"
done
unset IFS

# Make a new dump
timestamp="$(date +%y%m%d%H%M)"
echo -n "$(date) Creating new dump as $dumpdir/${databasename}_${timestamp}.sql"
if test $compressdumps = "yes"; then
  echo ".gz"
  mysqldump -u$databaseuser -p$databasepasswd --skip-lock-tables --single-transaction $databasename | gzip > $dumpdir/${databasename}_${timestamp}.sql.gz
else
  echo
  mysqldump -u$databaseuser -p$databasepasswd --skip-lock-tables --single-transaction $databasename > $dumpdir/${databasename}_${timestamp}.sql
fi
echo "$(date) Dumped."
