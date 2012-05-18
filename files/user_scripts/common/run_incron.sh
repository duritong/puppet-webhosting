#!/bin/env bash

([ -d $1 ] && [ -f $1/$2 ]) || exit 1

# do we have a .run file?
script_basename=`basename $2 .run`
[ "`basename $2`" = "${script_basename}" ] && exit 1
# has the run file the same name as the containing dir?
[ "`basename $1`" != "${script_basename}" ] && exit 1

# is it an existing script?
script="/opt/webscripts/${script_basename}/${script_basename}.rb"
[ -x ${script} ] || exit 1

$script $1/$2 >> $1/${script_basename}.log