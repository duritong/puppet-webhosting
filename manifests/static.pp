# domainalias:
#   - www: add as well a www.${name} entry
#   - absent: do nothing
#   - default: add the string
#
# logmode:
#   - default: Do normal logging to CustomLog and ErrorLog
#   - nologs: Send every logging to /dev/null
#   - anonym: Don't log ips for CustomLog, send ErrorLog to /dev/null
#   - semianonym: Don't log ips for CustomLog, log normal ErrorLog
define webhosting::static (
  $ensure               = present,
  $configuration        = {},
  $uid                  = 'absent',
  $uid_name             = 'absent',
  $gid                  = 'uid',
  $gid_name             = 'absent',
  $password             = 'absent',
  $password_crypted     = true,
  $domain               = 'absent',
  $domainalias          = 'www',
  $server_admin         = 'absent',
  $logmode              = 'default',
  $owner                = root,
  $group                = 'absent',
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
  $nagios_check_domain = undef,
  $nagios_check_url     = '/',
  $nagios_check_code    = '200',
  $nagios_use           = 'generic-service',
  $mod_security         = false,
  $git_repo             = 'absent',
  $user_scripts         = 'auto',
  $user_scripts_options = {},
) {
  if ($uid_name == 'absent') {
    $real_uid_name = $name
  } else {
    $real_uid_name = $uid_name
  }
  if ($gid_name == 'absent') {
    $real_gid_name = $real_uid_name
  } else {
    $real_gid_name = $gid_name
  }
  if ($group == 'absent') {
    $real_group = $real_gid_name
  } else {
    $real_group = 'apache'
  }
  if $user_scripts == 'auto' {
    include webhosting::user_scripts
    $_user_scripts = $webhosting::user_scripts::static_scripts
  } else {
    $_user_scripts = $user_scripts
  }
  webhosting::common { $name:
    ensure               => $ensure,
    configuration        => $configuration,
    uid                  => $uid,
    uid_name             => $real_uid_name,
    gid                  => $gid,
    gid_name             => $real_gid_name,
    password             => $password,
    password_crypted     => $password_crypted,
    htpasswd_file        => $htpasswd_file,
    ssl_mode             => $ssl_mode,
    run_mode             => 'static',
    nagios_check         => $nagios_check,
    nagios_check_domain  => $nagios_check_domain,
    nagios_check_url     => $nagios_check_url,
    nagios_check_code    => $nagios_check_code,
    nagios_use           => $nagios_use,
    git_repo             => $git_repo,
    user_scripts         => $_user_scripts,
    user_scripts_options => $user_scripts_options,
  }
  apache::vhost::static { $name:
    ensure             => $ensure,
    configuration      => $configuration,
    domain             => $domain,
    domainalias        => $domainalias,
    server_admin       => $server_admin,
    logmode            => $logmode,
    group              => $real_group,
    documentroot_owner => $real_uid_name,
    documentroot_group => $real_group,
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
  }
  if $template_partial != 'absent' {
    Apache::Vhost::Static[$name] {
      template_partial => $template_partial
    }
  }
}
