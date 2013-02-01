class webhosting::watch_adjust_webfiles::base {
  file{'/usr/local/sbin/chown_webfiles.sh':
    source  => 'puppet:///modules/webhosting/watch_adjust_webfiles/chown_webfiles.sh',
    owner   => root,
    group   => 0,
    mode    => '0700';
  }
}
