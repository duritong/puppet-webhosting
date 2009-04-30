# manifests/files/webhosting_standard.pp

define webhosting::common(
    $ensure = present,
    $uid = 'absent',
    $gid = 'uid',
    $password = 'absent',
    $password_crypted = true,
    $htpasswd_file = 'absent',
    $ssl_mode = false,
    $run_mode = 'normal',
    $run_uid = 'absent',
    $run_uid_name = 'absent',
    $run_gid = 'absent',
    $run_gid_name = 'absent',
    $nagios_check = 'ensure',
    $nagios_check_domain = 'absent',
    $nagios_check_url = '/',
    $nagios_check_code = 'OK'
){
    user::sftp_only{"${name}":
      ensure => $ensure,
      uid => $uid,
      gid => $gid,
      password => $password,
      password_crypted => $password_crypted,
    }

    if $use_nagios {
      if $nagios_check == 'ensure' {
        $nagios_ensure = $ensure
      } else {
        $nagios_ensure = $nagios_check
      }
      if $nagios_check_code == 'OK' {
        $real_nagios_check_code = $htpasswd_file ? {
          'absent' => $nagios_check_code,
          default => '401'
        }
      } else {
        $real_nagios_check_code = $nagios_check_code
      }

      nagios::service::http{"${name}":
        ensure => $nagios_ensure,
        check_domain => $nagios_check_domain,
        ssl_mode => $ssl_mode,
        check_url => $nagios_check_url,
        check_code => $real_nagios_check_code,
      }
    }

    if ($run_mode == 'itk') {
      if ($run_uid=='absent') and ($ensure != 'absent') {
        fail("you need to define run_uid for $name on $fqdn to use itk")
      }
      if ($run_gid == 'absent') {
        if ($gid == 'uid') {
          $real_run_gid = $uid
        } else {
          $real_run_gid = $gid
        }
      } else {
        $real_run_gid = $run_gid
      }
      if ($run_uid_name == 'absent'){
        $real_run_uid_name = "${name}_run"
      } else {
        $real_run_uid_name = $run_uid_name
      }
      user::managed{$real_run_uid_name:
        ensure => $ensure,
        uid => $run_uid,
        gid => $real_run_gid,
        manage_group => false,
        managehome => false,
        shell => $operatingsystem ? {
          debian => '/usr/sbin/nologin',
          ubuntu => '/usr/sbin/nologin',
          default => '/sbin/nologin'
        },
        require => User::Sftp_only[$name],
      }
      User::Sftp_only["${name}"]{
        homedir_mode => 0755
      }
   }
}
