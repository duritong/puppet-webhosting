#!/bin/bash

if [ -z $1 ]; then
  echo "USAGE: $0 name_of_smf_installation||all"
  exit 1
fi

basedir=/var/www/vhosts/
if [ $1 = 'all' ]; then
  smfs=''
  for i in $(ls $basedir/*/www/SSI.php); do
    wwwdir=$(dirname $i)
    if [ -d "${wwwdir}/.git" ]; then
      git --git-dir=${wwwdir}/.git remote -v | grep '(fetch)' | awk '{ print $2 }' | grep -q 'ismf.git'
      if [ $? -eq 0 ]; then
        name=$(basename $(dirname $wwwdir))
        smfs="${smfs}${name} "
      fi
    fi
  done
else
  smfs=$1
fi

function run_cmd_as {
  run_user=$1
  cmd=$2

  su -s /bin/bash $run_user -c "${cmd}"
  res=$?
  [ $res -gt 0 ] && abort "Comand failed with exitcode ${res}"
}

function abort {
  echo $1
  echo "Aborting..."
  exit 1
}

function update_smf {
  smf=$1
  basesmfdir=$basedir/$smf
  starterfile="/var/www/mod_fcgid-starters/${smf}/${smf}-starter"
  wwwdir=$basesmfdir/www
  if [ ! -f "${wwwdir}/SSI.php" ]; then
    abort "SMF ${smf} does not really seem to be an smf!"
  fi
  if [ ! -f $starterfile ]; then
    abort "SMF ${smf} does not have a starter file"
  fi

  ftpuser=$(stat -c%U $wwwdir)
  runuser=$(stat -c%U $starterfile)

  echo "Updating ${smf}"
  find ${wwwdir} -user ${runuser} -print0 | xargs --no-run-if-empty -0 chmod g+w
  find ${wwwdir} -user ${runuser} -print0 | xargs --no-run-if-empty -0 chown ${ftpuser}
  run_cmd_as $ftpuser "cd ${wwwdir} && git pull --no-edit && chmod -R g+w attachments avatars cache Packages Smileys Themes"
  echo "Updating ${smf} done"
}


for smf in $smfs; do
  update_smf $smf
done

