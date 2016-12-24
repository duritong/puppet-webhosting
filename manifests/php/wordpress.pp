# domainalias:
#   - www: add as well a www.${name} entry
#   - absent: do nothing
#   - default: add the string
# run_mode:
#   - normal: nothing special (*default*)
#   - fcgid: apache is running with fcgid and suexec
# run_uid: the uid the vhost should run as with the suexec module
# run_gid: the gid the vhost should run as with the suexec module
#
# logmode:
#   - default: Do normal logging to CustomLog and ErrorLog
#   - nologs: Send every logging to /dev/null
#   - anonym: Don't log ips for CustomLog, send ErrorLog to /dev/null
#   - semianonym: Don't log ips for CustomLog, log normal ErrorLog
define webhosting::php::wordpress(
  $ensure                 = present,
  $configuration          = {},
  $uid                    = 'absent',
  $uid_name               = 'absent',
  $gid                    = 'uid',
  $gid_name               = 'absent',
  $password               = 'absent',
  $password_crypted       = true,
  $domainalias            = 'www',
  $server_admin           = 'absent',
  $logmode                = 'default',
  $owner                  = root,
  $group                  = 'sftponly',
  $run_mode               = 'normal',
  $run_uid                = 'absent',
  $run_uid_name           = 'absent',
  $run_gid                = 'absent',
  $run_gid_name           = 'absent',
  $watch_adjust_webfiles  = 'absent',
  $user_scripts           = 'absent',
  $user_scripts_options   = {},
  $wwwmail                = false,
  $allow_override         = 'FileInfo Indexes',
  $do_includes            = false,
  $options                = 'absent',
  $additional_options     = 'absent',
  $default_charset        = 'absent',
  $ssl_mode               = false,
  $php_settings           = {},
  $php_options            = {},
  $php_installation       = 'system',
  $vhost_mode             = 'template',
  $template_partial       = 'absent',
  $vhost_source           = 'absent',
  $vhost_destination      = 'absent',
  $htpasswd_file          = 'absent',
  $nagios_check           = 'ensure',
  $nagios_check_domain    = 'absent',
  $nagios_check_url       = '/',
  $nagios_check_code      = '200,301',
  $nagios_use             = 'generic-service',
  $autoinstall            = true,
  $blog_options           = {},
  $mod_security           = true,
  $manage_config          = false,
  $config_webwriteable    = false,
  $manage_directories     = true,
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
  if ($group == 'absent') {
    $real_group = $real_gid_name
  } else {
    $real_group = 'apache'
  }

  $path = "/var/www/vhosts/${name}"
  $documentroot = "${path}/www"

  webhosting::common{$name:
    ensure                => $ensure,
    configuration         => $configuration,
    uid                   => $uid,
    uid_name              => $real_uid_name,
    gid                   => $gid,
    gid_name              => $real_gid_name,
    password              => $password,
    password_crypted      => $password_crypted,
    htpasswd_file         => $htpasswd_file,
    ssl_mode              => $ssl_mode,
    run_mode              => $run_mode,
    run_uid               => $run_uid,
    run_uid_name          => $run_uid_name,
    run_gid               => $run_gid,
    user_scripts          => $user_scripts,
    user_scripts_options  => $user_scripts_options,
    watch_adjust_webfiles => $watch_adjust_webfiles,
    wwwmail               => $wwwmail,
    nagios_check          => $nagios_check,
    nagios_check_domain   => $nagios_check_domain,
    nagios_check_url      => $nagios_check_url,
    nagios_check_code     => $nagios_check_code,
    nagios_use            => $nagios_use,
  }

  apache::vhost::php::wordpress{$name:
    ensure              => $ensure,
    configuration       => $configuration,
    domainalias         => $domainalias,
    server_admin        => $server_admin,
    logmode             => $logmode,
    group               => $group,
    allow_override      => $allow_override,
    do_includes         => $do_includes,
    options             => $options,
    additional_options  => $additional_options,
    default_charset     => $default_charset,
    run_mode            => $run_mode,
    ssl_mode            => $ssl_mode,
    php_settings        => $php_settings,
    php_options         => $php_options,
    php_installation    => $php_installation,
    vhost_mode          => $vhost_mode,
    vhost_source        => $vhost_source,
    vhost_destination   => $vhost_destination,
    htpasswd_file       => $htpasswd_file,
    mod_security        => $mod_security,
    manage_config       => $manage_config,
    config_webwriteable => $config_webwriteable,
    manage_directories  => $manage_directories,
    require             => User::Sftp_only[$real_uid_name],
  }
  if $run_mode == 'fcgid' {
    if ($run_uid_name == 'absent'){
      $real_run_uid_name = "${name}_run"
    } else {
      $real_run_uid_name = $run_uid_name
    }
    if ($run_gid_name == 'absent'){
      $real_run_gid_name = $gid_name ? {
        'absent'  => $real_gid_name,
        default   => $gid_name
      }
    } else {
      $real_run_gid_name = $run_gid_name
    }
    Apache::Vhost::Php::Wordpress[$name]{
      documentroot_owner => $real_uid_name,
      documentroot_group => $real_gid_name,
      run_uid            => $real_run_uid_name,
      run_gid            => $real_run_gid_name,
    }
    User::Managed[$real_run_uid_name] -> Apache::Vhost::Php::Wordpress[$name]
  }
  if $ensure != 'absent' {
    wordpress::instance{$name:
      path         => $documentroot,
      autoinstall  => $autoinstall,
      blog_options => $blog_options,
      uid_name     => $real_uid_name,
      gid_name     => $real_gid_name,
      require      => User::Sftp_only[$real_uid_name],
    }
    if $manage_directories {
      Wordpress::Instance[$name]{
        before => File["${documentroot}/wp-content/uploads"],
      }
    }
    if $run_mode == 'fcgid' {
      User::Managed[$real_run_uid_name] -> Wordpress::Instance[$name]
    }
  }
  if $template_partial != 'absent' {
    Apache::Vhost::Php::Wordpress[$name]{
      template_partial => $template_partial,
    }
  }
}

