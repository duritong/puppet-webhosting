# domainalias:
#   - www: add as well a www.${name} entry
#   - absent: do nothing
#   - default: add the string
# run_uid: the uid the vhost should run as with the mod_passenger module
# run_gid: the gid the vhost should run as with the mod_passenger module
# user_access:
#   - sftp: an sftp only user will be created (*default*)
#
# logmode:
#   - default: Do normal logging to CustomLog and ErrorLog
#   - nologs: Send every logging to /dev/null
#   - anonym: Don't log ips for CustomLog, send ErrorLog to /dev/null
#   - semianonym: Don't log ips for CustomLog, log normal ErrorLog
define webhosting::passenger(
  $ensure               = present,
  $configuration        = {},
  $uid                  = 'absent',
  $uid_name             = 'absent',
  $gid                  = 'uid',
  $gid_name             = 'absent',
  $user_access          = 'sftp',
  $password             = 'absent',
  $password_crypted     = true,
  $domainalias          = 'www',
  $server_admin         = 'absent',
  $logmode              = 'default',
  $owner                = root,
  $group                = 'absent',
  $run_mode             = 'normal',
  $run_uid              = 'absent',
  $run_uid_name         = 'absent',
  $run_gid              = 'absent',
  $run_gid_name         = 'absent',
  $wwwmail              = false,
  $allow_override       = 'None',
  $do_includes          = false,
  $options              = 'absent',
  $additional_options   = 'absent',
  $default_charset      = 'absent',
  $ssl_mode             = false,
  $vhost_mode           = 'template',
  $template_partial     = 'absent',
  $vhost_source         = 'absent',
  $vhost_destination    = 'absent',
  $htpasswd_file        = 'absent',
  $nagios_check         = 'ensure',
  $nagios_check_domain  = 'absent',
  $nagios_check_url     = '/',
  $nagios_check_code    = '200',
  $nagios_use           = 'generic-service',
  $mod_security         = true,
  $passenger_app        = 'rails',
  $git_repo             = 'absent',
  $user_scripts         = 'absent',
  $user_scripts_options = {},
){

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
  if ($group == 'absent') and ($user_access == 'sftp') {
    $real_group = $real_gid_name
  } else {
    if ($group == 'absent') {
      $real_group = 'apache'
    } else {
      $real_group = $group
    }
  }
  webhosting::common{$name:
    ensure               => $ensure,
    configuration        => $configuration,
    uid                  => $uid,
    uid_name             => $real_uid_name,
    gid                  => $gid,
    gid_name             => $real_gid_name,
    user_access          => $user_access,
    password             => $password,
    password_crypted     => $password_crypted,
    htpasswd_file        => $htpasswd_file,
    ssl_mode             => $ssl_mode,
    run_mode             => $run_mode,
    run_uid              => $run_uid,
    run_uid_name         => $run_uid_name,
    run_gid              => $run_gid,
    wwwmail              => $wwwmail,
    nagios_check         => $nagios_check,
    nagios_check_domain  => $nagios_check_domain,
    nagios_check_url     => $nagios_check_url,
    nagios_check_code    => $nagios_check_code,
    nagios_use           => $nagios_use,
    git_repo             => $git_repo,
    user_scripts         => $user_scripts,
    user_scripts_options => $user_scripts_options,
  }
  apache::vhost::passenger{$name:
    ensure             => $ensure,
    configuration      => $configuration,
    domainalias        => $domainalias,
    server_admin       => $server_admin,
    logmode            => $logmode,
    group              => $real_group,
    allow_override     => $allow_override,
    do_includes        => $do_includes,
    options            => $options,
    additional_options => $additional_options,
    default_charset    => $default_charset,
    ssl_mode           => $ssl_mode,
    vhost_mode         => $vhost_mode,
    vhost_source       => $vhost_source,
    vhost_destination  => $vhost_destination,
    htpasswd_file      => $htpasswd_file,
    mod_security       => $mod_security,
    passenger_app      => $passenger_app,
  }

  if $ensure == 'present' {
    if $passenger_app =~ /^rails/ {
      $rails_options = "\nexport RAILS_ENV=production"
    } else {
      $rails_options = ''
    }
    $path_options = "\nexport PATH=~/gems/bin:\$PATH"
    file{
      "/var/www/vhosts/${name}/.ccache":
        ensure  => directory,
        owner   => $real_uid_name,
        group   => $real_gid_name,
        mode    => '0750';
      "/var/www/vhosts/${name}/.bashrc":
        content => "export GEM_HOME=~/gems/${path_options}${rails_options}\n",
        owner   => $real_uid_name,
        group   => $real_gid_name,
        mode    => '0640';
      "/var/www/vhosts/${name}/.profile":
        ensure  => link,
        target  => "/var/www/vhosts/${name}/.bashrc";
      "/var/www/vhosts/${name}/.gemrc":
        content => "gem: --no-ri --no-rdoc\n",
        owner   => $real_uid_name,
        group   => $real_gid_name,
        mode    => '0640';
    }
  }

  case $run_mode {
    'fcgid': {
      if ($run_uid_name == 'absent'){
        $real_run_uid_name = "${name}_run"
      } else {
        $real_run_uid_name = $run_uid_name
      }
      if ($run_gid_name == 'absent'){
        $real_run_gid_name = $gid_name ? {
          'absent'  => $name,
          default   => $gid_name
        }
      } else {
        $real_run_gid_name = $run_gid_name
      }
      Apache::Vhost::Passenger[$name]{
        documentroot_owner  => $real_uid_name,
        documentroot_group  => $real_gid_name,
        documentroot_mode   => '0750',
        run_uid             => $real_run_uid_name,
        run_gid             => $real_run_gid_name,
      }
      Apache::Vhost::Passenger[$name]{
        require => [ User::Sftp_only[$real_uid_name],
          User::Managed[$real_run_uid_name] ],
      }
    }
    default: {
      Apache::Vhost::Passenger[$name]{
        require => User::Sftp_only[$real_uid_name],
      }
      if ($run_uid_name == 'absent'){
        $real_run_uid_name = 'apache'
      } else {
        $real_run_uid_name = $run_uid_name
      }
      if ($run_gid_name == 'absent'){
        $real_run_gid_name = $gid_name ? {
          'absent'  => 'apache',
          default   => $gid_name
        }
      } else {
        $real_run_gid_name = $run_gid_name
      }
      Apache::Vhost::Passenger[$name]{
        run_uid => $run_uid,
        run_gid => $run_gid,
      }
    }
  }
  if $template_partial != 'absent' {
    Apache::Vhost::Passenger[$name]{
      template_partial => $template_partial,
    }
  }
}

