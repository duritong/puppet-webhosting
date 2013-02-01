#!/bin/env bash

run_user=$1
sftp_user=$2
vhost=$3
file=$4

([ -z $run_user ] || [ -z $sftp_user ] || [ -z $vhost ] || [ -z "$file" ]) && exit 1

# do not adjust permissions while a script is running on this vhost
if [ -d $vhost/../scripts ]; then
  if [ -n "`find $vhost/../scripts -name *.lock`" ]; then
    exit
  fi
fi

if [ -f "$file" ]; then
  target_mode=0660
elif [ -d "$file" ]; then
  target_mode=0770
else
  exit 0
fi

current_owner=`stat -c %U "${file}"`

if [ "${current_owner}" = "${run_user}" ]; then
  chmod ${target_mode} "$file"
  chown ${sftp_user} "$file"
fi
