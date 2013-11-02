#!/bin/bash

for smf in /var/www/vhosts/*/www; do
  if [ -f $smf/SSI.php ] && [ -d $smf/.git ]; then
    cd $smf
    git remote -v | grep '(fetch)' | awk '{ print $2 }' | grep -q 'ismf.git'
    if [ $? -eq 0 ]; then
      name=$(basename `dirname $smf`)
      owner=`stat --printf=%U index.php`
      echo "Updating ${name}"
      su $owner -s /bin/bash -c "cd $(pwd); git pull"
      echo "Done updating ${name}"
    fi
  fi
done

