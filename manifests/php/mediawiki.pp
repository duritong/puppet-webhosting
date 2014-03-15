# domainalias:
#   - www: add as well a www.${name} entry
#   - absent: do nothing
#   - default: add the string
# user_provider:
#   - local: user will be crated locally (*default*)
#   - everything else will currently do noting
# run_mode:
#   - normal: nothing special (*default*)
#   - itk: apache is running with the itk module
#          and run_uid and run_gid are used as vhost users
# run_uid: the uid the vhost should run as with the itk module
# run_gid: the gid the vhost should run as with the itk module
#
# logmode:
#   - default: Do normal logging to CustomLog and ErrorLog
#   - nologs: Send every logging to /dev/null
#   - anonym: Don't log ips for CustomLog, send ErrorLog to /dev/null
#   - semianonym: Don't log ips for CustomLog, log normal ErrorLog
define webhosting::php::mediawiki(
  $ensure               = present,
  $uid                  = 'absent',
  $uid_name             = 'absent',
  $gid                  = 'uid',
  $gid_name             = 'absent',
  $user_provider        = 'local',
  $password             = 'absent',
  $password_crypted     = true,
  $domainalias          = 'www',
  $server_admin         = 'absent',
  $logmode              = 'default',
  $owner                = root,
  $group                = 'sftponly',
  $run_mode             = 'normal',
  $run_uid              = 'absent',
  $run_uid_name         = 'absent',
  $run_gid              = 'absent',
  $run_gid_name         = 'absent',
  $wwwmail              = false,
  $allow_override       = 'FileInfo Limit',
  $options              = 'absent',
  $additional_options   = 'absent',
  $default_charset      = 'absent',
  $ssl_mode             = false,
  $php_settings         = {},
  $php_options          = {},
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
  $image                = 'absent',
  $config               = 'unmanaged',
  $db_server            = 'unmanaged',
  $db_name              = 'unmanaged',
  $db_user              = 'db_name',
  $db_pwd               = 'unmanaged',
  $contact              = 'unmanaged',
  $sitename             = 'unmanaged',
  $secret_key           = 'unmanaged',
  $spam_protection      = false,
  $wiki_options         = {},
  $autoinstall          = true,
  $squid_servers        = 'absent',
  $file_extensions      = 'absent',
  $extensions           = 'absent',
  $language             = 'de',
  $hashed_upload_dir    = true
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
  webhosting::common{$name:
    ensure               => $ensure,
    uid                  => $uid,
    uid_name             => $real_uid_name,
    gid                  => $gid,
    gid_name             => $real_gid_name,
    user_provider        => $user_provider,
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
  }

  $mediawiki_php_settings = {
    open_basedir => "/var/www/mediawiki:/var/www/vhosts/${name}/www:/var/www/upload_tmp_dir/${name}:/var/www/session.save_path/${name}",
  }
  if $wwwmail and ($contact != 'unmanaged'){
    $mediawiki_php_settings['sendmail_path'] = "/usr/sbin/sendmail -t -f${contact} -i"
  }
  $real_php_settings = merge($mediawiki_php_settings,$php_settings)

  apache::vhost::php::mediawiki{$name:
    ensure             => $ensure,
    domainalias        => $domainalias,
    server_admin       => $server_admin,
    logmode            => $logmode,
    group              => $group,
    manage_docroot     => false,
    allow_override     => $allow_override,
    options            => $options,
    additional_options => $additional_options,
    default_charset    => $default_charset,
    run_mode           => $run_mode,
    ssl_mode           => $ssl_mode,
    php_settings       => $real_php_settings,
    php_options        => $php_options,
    vhost_mode         => $vhost_mode,
    vhost_source       => $vhost_source,
    vhost_destination  => $vhost_destination,
    htpasswd_file      => $htpasswd_file,
    mod_security       => $mod_security,
  }
  mediawiki::instance{$name:
    ensure                   => $ensure,
    image                    => $image,
    config                   => $config,
    db_server                => $db_server,
    db_name                  => $db_name,
    db_user                  => $db_user,
    db_pwd                   => $db_pwd,
    contact                  => $contact,
    sitename                 => $sitename,
    secret_key               => $secret_key,
    file_extensions          => $file_extensions,
    extensions               => $extensions,
    spam_protection          => $spam_protection,
    wiki_options             => $wiki_options,
    autoinstall              => $autoinstall,
    squid_servers            => $squid_servers,
    language                 => $language,
    hashed_upload_dir        => $hashed_upload_dir,
    documentroot_write_mode  => 0660,
  }

  case $run_mode {
    'fcgid','itk','proxy-itk','static-itk': {
      if ($run_uid_name == 'absent'){
        $real_run_uid_name = "${name}_run"
      } else {
        $real_run_uid_name = $run_uid_name
      }
      if ($run_gid_name == 'absent'){
        $real_run_gid_name = $gid_name ? {
          'absent' => $name,
          default  => $gid_name
        }
      } else {
        $real_run_gid_name = $run_gid_name
      }
      Apache::Vhost::Php::Mediawiki[$name]{
        documentroot_owner => $real_uid_name,
        documentroot_group => $real_gid_name,
        run_uid            => $real_run_uid_name,
        run_gid            => $real_run_gid_name,
        require            => [ User::Sftp_only[$real_uid_name],
                                User::Managed[$real_run_uid_name] ],
      }
      Mediawiki::Instance[$name]{
        documentroot_owner => $real_uid_name,
        documentroot_group => $real_gid_name,
        documentroot_mode  => 0640,
        require            => [ User::Sftp_only[$real_uid_name],
                                User::Managed[$real_run_uid_name] ],
      }
    }
    default: {
      Apache::Vhost::Php::Mediawiki[$name]{
        require => User::Sftp_only[$real_uid_name],
      }
      Mediawiki::Instance[$name]{
        require => User::Sftp_only[$real_uid_name],
      }
    }
  }
  if $template_partial != 'absent' {
    Apache::Vhost::Php::Mediawiki[$name]{
      template_partial => $template_partial
    }
  }
}

