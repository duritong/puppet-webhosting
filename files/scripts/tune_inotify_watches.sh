#!/bin/bash

if [ ! -d /var/www/vhosts ]; then
  echo "No Webhostings available"
  exit 0
fi

num_hostings=$(ls -1 /var/www/vhosts/ | wc -l)
cur_value=$(cat /proc/sys/fs/inotify/max_user_instances)

cur_scripts_count=$(find /var/www/vhosts/*/scripts/ -mindepth 1 -maxdepth 1 -type d | wc -l)
cur_scripts_count_per_hosting=$((${cur_scripts_count}/${num_hostings}))

proposed_value=$(((${num_hostings}*(${cur_scripts_count_per_hosting} + 1) / 128 + 1) * 128 ))

if [ "$1" == 'tune' ]; then
  echo $proposed_value > /proc/sys/fs/inotify/max_user_instances
  echo -e "# tuned setting for incrond webhosting scripts\nfs.inotify.max_user_instances=${proposed_value}" > /etc/sysctl.d/98-inotify-incrond.conf
  exit 0
else
  if [ $proposed_value -gt $cur_value ]; then
    echo "Should adjust ${cur_value} to ${proposed_vaue}"
    exit 1
  else
    echo "Cur value ${cur_value} is correct"
    exit 0
  fi
fi
