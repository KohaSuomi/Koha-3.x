#!/bin/bash
### BEGIN INIT INFO
# Provides:          koha-zebra-daemon
# Required-Start:    $syslog $remote_fs
# Required-Stop:     $syslog $remote_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Zebra server daemon for Koha indexing
### END INIT INFO

ACTION=$1
SIPDEVICE=$2

SIPCONFIGDIR="/home/koha/koha-dev/etc/SIPconfig/"
LOGDIR="/home/koha/koha-dev/var/log/sip2/"
RUNDIR="/home/koha/koha-dev/var/run/sip2/"
LOCKDIR="/home/koha/koha-dev/var/lock/sip2/"

##  0  ## Show how to use this carp!
function help_usage {
    echo "$0 -service"
    echo "Starts and stops Koha SIP server worker configurations"
    echo ""
    echo "USAGE:"
    echo "service $0 start|stop|restart [<configName>]"
    echo ""
    echo "Param1 start, stop, restart daemon"
    echo "Param2 configuration name. Finds all *.xml-files from $SIPCONFIGDIR."
    echo "    Each config file is a clone of SIPconfig.xml containing specific"
    echo "    configuration for parallel SIP Servers."
    echo "    Param2 is the name of the config without the trailing filetype."
    echo "    OR ALL which targets all configuration files."
    echo ""

}

##  I  ## Find out the configuration files to start servers for.
function findConfigurationFile {
    SIPCONFIGFILES=$(ls $SIPCONFIGDIR)

    SIPDEVICES=$(ls $SIPCONFIGDIR | grep -Po '^.*?(?=\.xml)')
    bad_param=1
    if [ "$2" == "ALL" ]; then
        SIPDEVICES=$(ls $SIPCONFIGDIR | grep -Po '^.*?(?=\.xml)')
        bad_param=0;
    elif [ $2 ]; then
        for SIPDEVICE in ${SIPDEVICES[@]}
        do
            if [ "$SIPDEVICE" == "$2" ] ; then
                SIPDEVICES=$SIPDEVICE
                bad_param=0;
                break
            fi
        done
    fi
    if [ $bad_param != 0 ]; then
        echo "----------------------------------------------------"
        echo "Unknown SIP configuration '$2'"
        echo "Valid configuration files present in $SIPCONFIGDIR:"
        echo "$SIPDEVICES"
        echo "----------------------------------------------------"
        help_usage
        exit 1
    fi
}

##  II  ## Do the daemonizing magic
function handleSIPConfig {
    ACTION=$1
    SIPDEVICE=$2
    SIPCONFIG="$SIPCONFIGDIR/$SIPDEVICE.xml"

    USER=koha
    GROUP=koha
    NAME=koha-sip-$SIPDEVICE-daemon
    ERRLOG=$LOGDIR/$SIPDEVICE.err
    STDOUT=$LOGDIR/$SIPDEVICE.std
    OUTPUT=$LOGDIR/$SIPDEVICE.out
    #Also rsyslog logs to some directory. See /etc/rsyslog.d/koha.conf

    . /etc/environment
    export KOHA_CONF PERL5LIB

    case "$ACTION" in
    start)
      echo "Starting SIP2 Server"

      # create run and lock and log directories if needed;
      # /var/run and /var/lock are completely cleared at boot
      # on some platforms
      if [[ ! -d $RUNDIR ]]; then
        umask 022
        mkdir -p $RUNDIR
        if [[ $EUID -eq 0 ]]; then
            chown $USER:$GROUP $RUNDIR
        fi
      fi
      if [[ ! -d $LOCKDIR ]]; then
        umask 022
        mkdir -p $LOCKDIR
        if [[ $EUID -eq 0 ]]; then
            chown -R $USER:$GROUP $LOCKDIR
        fi
      fi
      if [[ ! -d $LOGDIR ]]; then
        umask 022
        mkdir -p $LOGDIR
        if [[ $EUID -eq 0 ]]; then
            chown -R $USER:$GROUP $LOGDIR
        fi
      fi

      daemon --delay=30 --name=$NAME --pidfiles=$RUNDIR --user=$USER --errlog=$ERRLOG --stdout=$STDOUT --output=$OUTPUT --respawn --command="perl -I/home/koha/kohaclone/C4/SIP/ -MILS /home/koha/kohaclone/C4/SIP/SIPServer.pm $SIPCONFIG" 
      ;;
    stop)
      echo "Stopping SIP2 Server"
      daemon --delay=30 --name=$NAME --pidfiles=$RUNDIR --user=$USER --errlog=$ERRLOG --stdout=$STDOUT --output=$OUTPUT --respawn --stop --command="perl -I/home/koha/kohaclone/C4/SIP/ -MILS /home/koha/kohaclone/C4/SIP/SIPServer.pm $SIPCONFIG" 
      ;;
    restart)
      echo "Restarting the SIP2 Server"
      daemon --delay=30 --name=$NAME --pidfiles=$RUNDIR --user=$USER --errlog=$ERRLOG --stdout=$STDOUT --output=$OUTPUT --respawn --restart --command="perl -I/home/koha/kohaclone/C4/SIP/ -MILS /home/koha/kohaclone/C4/SIP/SIPServer.pm $SIPCONFIG" 
      ;;
    *)
      echo "---------------------------------------------"
      echo "Usage: /etc/init.d/$NAME {start|stop|restart}"
      echo "---------------------------------------------"
      help_usage
      exit 1
      ;;
    esac
}


findConfigurationFile $ACTION $SIPDEVICE
for SIPDEVICE in $SIPDEVICES; do
    handleSIPConfig $ACTION $SIPDEVICE
done
