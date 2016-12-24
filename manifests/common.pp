# Manages common things amongst webhostings
# user_access:
#   - sftp: an sftp only user will be created (*default*)
# wwwmail:
#   This will include the web run user in a group called wwwmailers.
#   This makes it easier to enable special rights on a webserver's mailserver to
#   this group.
#   - default: false
define webhosting::common(
  $ensure                = present,
  $configuration         = {},
  $uid                   = 'absent',
  $uid_name              = 'absent',
  $gid                   = 'uid',
  $gid_name              = 'absent',
  $user_access           = 'sftp',
  $password              = 'absent',
  $password_crypted      = true,
  $htpasswd_file         = 'absent',
  $ssl_mode              = false,
  $run_mode              = 'normal',
  $run_uid               = 'absent',
  $run_uid_name          = 'absent',
  $run_gid               = 'absent',
  $wwwmail               = false,
  $watch_adjust_webfiles = 'absent',
  $user_scripts          = 'absent',
  $user_scripts_options  = {},
  $nagios_check          = 'ensure',
  $nagios_check_domain   = 'absent',
  $nagios_check_url      = '/',
  $nagios_check_code     = '200',
  $nagios_use            = 'generic-service',
  $git_repo              = 'absent',
){
  if ($run_gid == 'absent') {
    if ($gid == 'uid') {
      $real_run_gid = $uid
    } else {
      $real_run_gid = $gid
    }
  } else {
    $real_run_gid = $run_gid
  }
  if ($uid_name == 'absent'){
    $real_uid_name = $name
  } else {
    $real_uid_name = $uid_name
  }
  if ($gid_name == 'absent'){
    $real_gid_name = $real_uid_name
  } else {
    $real_gid_name = $gid_name
  }
  if ($run_uid_name == 'absent'){
    $real_run_uid_name = "${name}_run"
  } else {
    $real_run_uid_name = $run_uid_name
  }

  $vhost_path = "/var/www/vhosts/${name}"

  if ($user_access == 'sftp') {
    $real_uid = $uid ? {
      'iuid'  => iuid($real_uid_name,'webhosting'),
      default => $uid
    }
    $real_password = $password ? {
      'trocla' => trocla("webhosting_${real_uid_name}",'sha512crypt'),
      default  => $password
    }
    user::sftp_only{$real_uid_name:
      ensure           => $ensure,
      password_crypted => $password_crypted,
      homedir          => $vhost_path,
      gid              => $gid,
      uid              => $real_uid,
      password         => $real_password,
    }
    include ::apache::sftponly
  }

  if $run_mode in ['fcgid','static'] {
    if ($user_access == 'sftp') {
      if ($ensure != 'absent') {
        User::Sftp_only[$real_uid_name]{
          homedir_mode => '0750',
        }
      }
      user::groups::manage_user{
        "apache_in_${real_gid_name}":
          group => $real_gid_name,
          user  => 'apache',
      }
      User::Groups::Manage_user["apache_in_${real_gid_name}"]{
        ensure => $ensure,
      }
      if $ensure == 'present' {
        User::Groups::Manage_user["apache_in_${real_gid_name}"]{
          require => User::Sftp_only[$real_uid_name],
        }
      }
    }
  }
  if $run_mode == 'fcgid' {
    if ($run_uid=='absent') and ($ensure != 'absent') {
      fail("you need to define run_uid for ${name} on ${::fqdn} to use fcgid")
    }
    $real_run_uid = $run_uid ? {
      'iuid'  => iuid($real_run_uid_name,'webhosting'),
      default => $run_uid,
    }
    $shell = $::operatingsystem ? {
      /^(Debian|Ubuntu)$/ => '/usr/sbin/nologin',
      default             => '/sbin/nologin',
    }
    user::managed{$real_run_uid_name:
      ensure       => $ensure,
      manage_group => false,
      managehome   => false,
      homedir      => $vhost_path,
      uid          => $real_run_uid,
      shell        => $shell,
    }
    if ($user_access == 'sftp') {
      if ($ensure == 'absent') {
        User::Managed[$real_run_uid_name]{
          before => User::Sftp_only[$real_uid_name],
        }
      } else {
        User::Managed[$real_run_uid_name]{
          require => User::Sftp_only[$real_uid_name],
        }
      }
    }

    if $wwwmail {
      user::groups::manage_user{
        "${real_run_uid_name}_in_wwwmailers":
          ensure => $ensure,
          group  => 'wwwmailers',
          user   => $real_run_uid_name,
      }
      if ($ensure == 'present') {
        require ::webhosting::wwwmailers
        User::Groups::Manage_user["${real_run_uid_name}_in_wwwmailers"]{
          require => User::Managed[$real_run_uid_name],
        }
      }
    }
    if ($ensure == 'present') {
      $rreal_run_gid = $real_run_gid ? {
        'iuid'  => iuid($real_uid_name,'webhosting'),
        default => $real_run_gid,
      }
      User::Managed[$real_run_uid_name]{
        gid => $rreal_run_gid,
      }
    }
  }

  if $nagios_check != 'unmanaged' {
    if $nagios_check == 'ensure' {
      $nagios_ensure = $ensure
    } else {
      $nagios_ensure = $nagios_check
    }
    $real_nagios_check_code = $htpasswd_file ? {
      'absent'  => $nagios_check_code,
      default   => '401'
    }

    nagios::service::http{$name:
      ensure       => $nagios_ensure,
      check_domain => $nagios_check_domain,
      ssl_mode     => $ssl_mode,
      check_url    => $nagios_check_url,
      use          => $nagios_use,
      check_code   => $real_nagios_check_code,
    }
  }

  $watch_webfiles_ensure = $ensure ? {
    'absent'  => 'absent',
    default   => $watch_adjust_webfiles,
  }
  webhosting::watch_adjust_webfiles{
    $name:
      ensure    => $watch_webfiles_ensure,
      path      => "${vhost_path}/www/",
      sftp_user => $real_uid_name,
      run_user  => $real_run_uid_name,
  }

  if $ensure != 'absent' {
    webhosting::user_scripts::manage{$name:
      ensure    => $user_scripts,
      base_path => $vhost_path,
      scripts   => $user_scripts,
      sftp_user => $real_uid_name,
      run_user  => $real_run_uid_name,
      web_group => $real_gid_name,
      options   => $user_scripts_options,
    }
  }
  if ($git_repo != 'absent') and ($ensure != 'absent') {
    webhosting::utils::clone{
      $name:
        git_repo     => $git_repo,
        documentroot => "${vhost_path}/www",
        uid_name     => $uid_name,
        run_uid_name => $real_run_uid_name,
        gid_name     => $gid_name,
        run_mode     => $run_mode,
    }
  }
}
