# domainalias:
#   - www: add as well a www.${name} entry
#   - absent: do nothing
#   - default: add the string
# run_mode:
#   - normal: nothing special (*default*)
#   - fcgid: apache is running with the fcgid module and suexec
# run_uid: the uid the vhost should run as with the suexec module
# run_gid: the gid the vhost should run as with the suexec module
#
# logmode:
#   - default: Do normal logging to CustomLog and ErrorLog
#   - nologs: Send every logging to /dev/null
#   - anonym: Don't log ips for CustomLog, send ErrorLog to /dev/null
#   - semianonym: Don't log ips for CustomLog, log normal ErrorLog
define webhosting::php::mediawiki (
  $ensure              = present,
  $configuration       = {},
  $uid                 = 'absent',
  $uid_name            = 'absent',
  $gid                 = 'uid',
  $gid_name            = 'absent',
  $password            = 'absent',
  $password_crypted    = true,
  $domainalias         = 'www',
  $server_admin        = 'absent',
  $logmode             = 'default',
  $owner               = root,
  $group               = 'absent',
  $run_mode            = 'normal',
  $run_uid             = 'absent',
  $run_uid_name        = 'absent',
  $run_gid             = 'absent',
  $run_gid_name        = 'absent',
  $wwwmail             = false,
  $allow_override      = 'FileInfo Limit Options=FollowSymLinks',
  $options             = 'absent',
  $additional_options  = 'absent',
  $default_charset     = 'absent',
  $ssl_mode            = false,
  $php_settings        = {},
  $php_options         = {},
  $php_installation    = 'scl81',
  $vhost_mode          = 'template',
  $template_partial    = 'absent',
  $vhost_source        = 'absent',
  $vhost_destination   = 'absent',
  $htpasswd_file       = 'absent',
  $nagios_check        = 'ensure',
  $nagios_check_domain = undef,
  $nagios_check_url    = '/',
  $nagios_check_code   = '200',
  $nagios_use          = 'generic-service',
  $mod_security        = false,
  $image               = 'absent',
  $config              = 'unmanaged',
  $db_server           = 'unmanaged',
  $db_name             = 'unmanaged',
  $db_user             = 'db_name',
  $contact             = 'unmanaged',
  $sitename            = 'unmanaged',
  $secret_key          = 'unmanaged',
  $spam_protection     = false,
  $wiki_options        = {},
  $autoinstall         = true,
  $squid_servers       = 'absent',
  $file_extensions     = 'absent',
  $extensions          = 'absent',
  $language            = 'de',
  $hashed_upload_dir   = true
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

  $mysql_dbs = pick($configuration['mysql_dbs'],{})
  $_c_with_mysql_dbs = {
    mysql_dbs => $mysql_dbs + {
      $db_name => {
        username => $db_user ? {
          'db_name' => $db_name,
          default   => $db_user,
        }
      } + pick($mysql_dbs[$db_name],{})
    }
  }
  $_configuration = $configuration + $_c_with_mysql_dbs

  webhosting::common { $name:
    ensure              => $ensure,
    configuration       => $_configuration,
    uid                 => $uid,
    uid_name            => $real_uid_name,
    gid                 => $gid,
    gid_name            => $real_gid_name,
    password            => $password,
    password_crypted    => $password_crypted,
    htpasswd_file       => $htpasswd_file,
    ssl_mode            => $ssl_mode,
    run_mode            => $run_mode,
    run_uid             => $run_uid,
    run_uid_name        => $run_uid_name,
    run_gid             => $run_gid,
    wwwmail             => $wwwmail,
    nagios_check        => $nagios_check,
    nagios_check_domain => $nagios_check_domain,
    nagios_check_url    => $nagios_check_url,
    nagios_check_code   => $nagios_check_code,
    nagios_use          => $nagios_use,
    php_installation    => $php_installation,
  }

  if $wwwmail and ($contact != 'unmanaged') {
    $sendmail_path = "/usr/sbin/sendmail -t -f${contact} -i"
  } else {
    $sendmail_path = undef
  }
  $mediawiki_php_settings = {
    sendmail_path => $sendmail_path,
  }
  $real_php_settings = merge($mediawiki_php_settings,$php_settings)
  $mediawiki_php_options = {
    snuffleupagus_ignore_rules => (['010-mail-add-params'] + pick($php_options['snuffleupagus_ignore_rules'],[])).unique,
    additional_open_basedir    => '/var/www/mediawiki:/usr/bin/git',
  }
  $real_php_options = merge($mediawiki_php_options,$php_options)

  apache::vhost::php::mediawiki { $name:
    ensure             => $ensure,
    configuration      => $configuration,
    domainalias        => $domainalias,
    server_admin       => $server_admin,
    logmode            => $logmode,
    group              => $real_group,
    manage_docroot     => false,
    allow_override     => $allow_override,
    options            => $options,
    additional_options => $additional_options,
    default_charset    => $default_charset,
    run_mode           => $run_mode,
    ssl_mode           => $ssl_mode,
    php_settings       => $real_php_settings,
    php_options        => $real_php_options,
    php_installation   => $php_installation,
    vhost_mode         => $vhost_mode,
    vhost_source       => $vhost_source,
    vhost_destination  => $vhost_destination,
    htpasswd_file      => $htpasswd_file,
    mod_security       => $mod_security,
  }
  if $configuration['active_on_host'] != false {
    $_autoinstall = $autoinstall
  } else {
    $_autoinstall = false
  }
  mediawiki::instance { $name:
    ensure                  => $ensure,
    image                   => $image,
    config                  => $config,
    db_server               => $db_server,
    db_name                 => $db_name,
    db_user                 => $db_user,
    db_pwd                  => 'trocla',
    contact                 => $contact,
    sitename                => $sitename,
    ssl_mode                => $ssl_mode,
    secret_key              => $secret_key,
    file_extensions         => $file_extensions,
    extensions              => $extensions,
    spam_protection         => $spam_protection,
    wiki_options            => $wiki_options,
    php_installation        => $php_installation,
    autoinstall             => $_autoinstall,
    squid_servers           => $squid_servers,
    language                => $language,
    hashed_upload_dir       => $hashed_upload_dir,
    documentroot_write_mode => '0660',
  }

  case $run_mode {
    'fpm','fcgid': {
      if ($run_uid_name == 'absent') {
        $real_run_uid_name = "${name}_run"
      } else {
        $real_run_uid_name = $run_uid_name
      }
      if ($run_gid_name == 'absent') {
        $real_run_gid_name = $gid_name ? {
          'absent' => $name,
          default  => $gid_name
        }
      } else {
        $real_run_gid_name = $run_gid_name
      }
      Apache::Vhost::Php::Mediawiki[$name] {
        documentroot_owner => $real_uid_name,
        documentroot_group => $real_gid_name,
        run_uid            => $real_run_uid_name,
        run_gid            => $real_run_gid_name,
      }
      Mediawiki::Instance[$name] {
        documentroot_owner => $real_uid_name,
        documentroot_group => $real_gid_name,
        documentroot_mode  => '0640',
      }
      if $ensure != 'absent' {
        Apache::Vhost::Php::Mediawiki[$name] {
          require => [User::Sftp_only[$real_uid_name],
                      User::Managed[$real_run_uid_name]],
        }
        Mediawiki::Instance[$name] {
          require => [User::Sftp_only[$real_uid_name],
                      User::Managed[$real_run_uid_name]],
        }
      }
    }
    default: {
      if $ensure != 'absent' {
        Apache::Vhost::Php::Mediawiki[$name] {
          require => User::Sftp_only[$real_uid_name],
        }
        Mediawiki::Instance[$name] {
          require => User::Sftp_only[$real_uid_name],
        }
      }
    }
  }
  if $template_partial != 'absent' {
    Apache::Vhost::Php::Mediawiki[$name] {
      template_partial => $template_partial
    }
  }
}
