#!/bin/env bash

run_user=$1
sftp_user=$2
file=$3

([ -z $run_user ] || [ -z $sftp_user ] || [ -z '$file' ]) && exit 1

if [ -f '$file' ]; then
  target_mode=0660
elif [ -d '$file' ]; then
  target_mode=0770
else
  exit 0
fi

current_owner=`stat -c %U '${file}'`

if [ "${current_owner}" = "${run_user}" ]; then
  chmod ${target_mode} $file
  chown ${sftp_user} $file
fi
