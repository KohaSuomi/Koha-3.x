#!/bin/bash

# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.

### BEGIN INIT INFO
# Provides:          koha-api-daemon
# Required-Start:    $syslog $remote_fs
# Required-Stop:     $syslog $remote_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Hypnotoad Mojolicious Server for handling Koha API requests
### END INIT INFO
. /etc/environment #Source Koha's environment variables

USER=koha
loggedInUser=`whoami`
NAME=koha-api-daemon
## See Koha/REST/V1.pm for more info about the environmental variables.
export MOJO_CONFIG=$KOHA_PATH/api/v1/hypnotoad.conf
#You get 3 logfiles here, .log, .stderr, .stdout
export MOJO_LOGFILES=__LOG_DIR__/kohaapi.mojo
export MOJO_LOGLEVEL=debug

##ABOUT CHANGING THE process name/command visible by programs like 'top' and 'ps'.
#
# You can make a small incision to /usr/local/share/perl/5.14.2/Mojo/Server.pm or wherever your
# Mojo::Server is located at.
# Go to load_app(), and after perl code line
# 60: FindBin->again;
# add
# $0 = 'koha-api-daemon';
# This renames all hypnotoad processes as koha-api-daemon.
# No side-effects encoutered so far but minimal testing here!

if [[ $EUID -ne 0 && $loggedInUser -ne $USER ]]; then
    echo "You must run this script as 'root' or as '$USER'";
    exit 1;
fi

function start {
    echo "Starting Hypnotoad"
    su -c "hypnotoad $KOHA_PATH/api/v1/script.cgi" $USER
    echo "ALL GLORY TO THE HYPNOTOAD."
}
function stop {
    su -c "hypnotoad $KOHA_PATH/api/v1/script.cgi -s" $USER
}

case "$1" in
    start)
        start
      ;;
    stop)
        stop
      ;;
    restart)
        echo "Restarting Hypnotoad"
        stop
        start
      ;;
    *)
      echo "Usage: /etc/init.d/$NAME {start|stop|restart}"
      exit 1
      ;;
esac
