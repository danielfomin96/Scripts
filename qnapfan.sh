#!/bin/bash
# Original author: galex from https://forum.qnap.com/viewtopic.php?t=58033

REFTIME=17
TEMP_HDD_LOW=37
TEMP_HDD_MAX=49

DOLOG=true
LOGFILE="/tmp/fanCtrl.log"
FILENAME="$(basename ${BASH_SOURCE[0]})"
SD_DEVIVES="sda sdb"
LASTSPEED=-1
_lock_file=/var/lock/subsys/"$FILENAME"


#------------------------------------------------#
#   Set speed
#------------------------------------------------#
SetFanSpeed()
{
   CMD_NUM=$(($1*255/100))

   if [ $LASTSPEED -ne $CMD_NUM ]; then
      Log "$CMD_NUM - $2"
   fi
   
   LASTSPEED=$CMD_NUM

   hal_app --se_sys_set_fan_pwm enc_sys_id=root,pwm="$CMD_NUM"
}

#------------------------------------------------#
#   Log
#------------------------------------------------#
Log()
{                  
   if [ $DOLOG ]; then
      CURTIME=$(/bin/date '+%Y-%m-%d %H:%M:%S')
      echo "$CURTIME": "$1" >> $LOGFILE
   fi
}

#------------------------------------------------#
#   start
#------------------------------------------------#
start()
{
   /bin/rm -f ${_lock_file}

   if [ -f ${_lock_file} ]; then
       /bin/echo "$FILENAME is already run"
       exit 1
   fi
   /bin/touch ${_lock_file}


   while true 
   do
      SYSTEMP=0 
      DEVTEMP=0
      DEVNUM=0

      # Check devices state and get max temperature

      for i in $SD_DEVIVES
      do
         DEVNUM=$[$DEVNUM+1]
         STATE=$(/sbin/hdparm -C /dev/"${i}")

         if [[ $STATE == *active* ]]; then
            TEMP=$(/sbin/get_hd_temp "$DEVNUM")
            TEMP=${TEMP:0:2}
            if [ "$TEMP" -gt $DEVTEMP ]; then
               DEVTEMP=$TEMP
            fi
         fi
      done


      # Devices are not standby
      if [ "$DEVTEMP" -ne 0 ]; then

         if [ "$DEVTEMP" -le $TEMP_HDD_LOW ]; then

            SetFanSpeed 1 "hdd temp ($DEVTEMP)"

         else

            if [ "$DEVTEMP" -gt $TEMP_HDD_MAX ]; then
     
               SetFanSpeed 100 "hdd temp ($DEVTEMP)"

            else
            
               FANSPEED=$((($DEVTEMP-$TEMP_HDD_LOW)*100/($TEMP_HDD_MAX-$TEMP_HDD_LOW)))
               SetFanSpeed $FANSPEED "hdd temp ($DEVTEMP)"
    
            fi
         fi

      fi


      /bin/sleep $REFTIME
   done
}

#------------------------------------------------#
#   Stop
#------------------------------------------------#
stop()
{
    /bin/kill -TERM "$(pidof $FILENAME dd)"
    /bin/rm -f ${_lock_file}
}


#------------------------------------------------#
#   Main
#------------------------------------------------#
case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    *)
        echo $"Usage: $0 {start|stop}"
        exit 1
esac

exit 0




