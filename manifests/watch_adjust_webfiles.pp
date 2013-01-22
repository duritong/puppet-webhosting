define webhosting::watch_adjust_webfiles (
  $ensure = 'present',
  $path,
  $sftp_user,
  $run_user
) {
  require webhosting::watch_adjust_webfiles::base
  dirwatcher::job {
    $name :
      ensure => $ensure,
      watch_directory => "${path}",
      watch_events => 'create,move_to',
      watch_command => "/usr/local/sbin/chown_webfiles.sh ${run_user} ${sftp_user} ${path} \$filename",
  }
  file{
    "/etc/cron.daily/fix_webperms_${name}":
      ensure => $ensure,
      content => "#!/bin/env bash\nfind ${path} -user ${run_user} -exec /usr/local/sbin/chown_webfiles.sh ${run_user} ${sftp_user} '{}' \\;\n",
      owner => root, group => 0, mode => 0700;
  }
}

