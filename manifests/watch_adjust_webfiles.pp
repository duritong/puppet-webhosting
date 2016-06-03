# add a adjust_watch for webfiles
#
#  ensure:
#    'present': cron
#    'both': cron & inotify
#    'inotify': inotify
#    'absent': absent
define webhosting::watch_adjust_webfiles (
  $path,
  $sftp_user,
  $run_user,
  $ensure = 'present',
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

  $chown_script = '/usr/local/sbin/chown_webfiles.sh'

  if $job_ensure == 'present' {
    $watch_cmd = "${chown_script} ${run_user} ${sftp_user} ${path} \$filename"

    dirwatcher::job {$name :
      watch_directory => $path,
      watch_events    => 'create,move_to',
      watch_command   => $watch_cmd,
    }
  }

  if $file_ensure == 'present' {
    $cron_cmd = "#!/bin/env bash
find ${path} -ignore_readdir_race -user ${run_user} -exec ${chown_script} \\
     ${run_user} ${sftp_user} ${path} '{}' \\;"

    File["/etc/cron.daily/fix_webperms_${name}"]{
      content => $cron_cmd,
      owner   => root,
      group   => 0,
      mode    => '0700',
    }
  }
}

