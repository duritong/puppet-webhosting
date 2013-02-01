# add a adjust_watch for webfiles
#
#  ensure:
#    'present': cron
#    'both': cron & inotify
#    'inotify': inotify
#    'absent': absent
define webhosting::watch_adjust_webfiles (
  $ensure = 'present',
  $path,
  $sftp_user,
  $run_user
) {

  $file_ensure = $ensure ? {
    'absent'  => 'absent',
    'inotify' => 'absent',
    default   => 'present'
  }

  $job_ensure = $ensure ? {
    'both'    => 'present',
    'inotify' => 'present',
    default   => 'absent'
  }

  file{"/etc/cron.daily/fix_webperms_${name}":
    ensure => $file_ensure,
  }

  if $ensure != 'absent' {
    require webhosting::watch_adjust_webfiles::base
  }

  if $job_ensure == 'present' {
    dirwatcher::job {$name :
      watch_directory => $path,
      watch_events    => 'create,move_to',
      watch_command   => "/usr/local/sbin/chown_webfiles.sh ${run_user} ${sftp_user} ${path} \$filename",
    }
  }

  if $file_ensure == 'present' {
    File["/etc/cron.daily/fix_webperms_${name}"]{
      content => "#!/bin/env bash\nfind ${path} -user ${run_user} -exec /usr/local/sbin/chown_webfiles.sh ${run_user} ${sftp_user} '{}' \\;\n",
      owner   => root,
      group   => 0,
      mode    => 0700,
    }
  }
}

