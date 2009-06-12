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
define webhosting::php::mediawiki(
    $ensure = present,
    $uid = 'absent',
    $gid = 'uid',
    $user_provider = 'local',
    $password = 'absent',
    $password_crypted = true,
    $domainalias = 'www',
    $server_admin = 'absent',
    $owner = root,
    $group = 'sftponly',
    $run_mode = 'normal',
    $run_uid = 'absent',
    $run_uid_name = 'absent',
    $run_gid = 'absent',
    $run_uid_name = 'absent',
    $run_gid = 'absent',
    $run_gid_name = 'absent',
    $allow_override = 'FileInfo',
    $options = 'absent',
    $additional_options = 'absent',
    $default_charset = 'absent',
    $ssl_mode = false,
    $vhost_mode = 'template',
    $vhost_source = 'absent',
    $vhost_destination = 'absent',
    $htpasswd_file = 'absent',
    $nagios_check = 'ensure',
    $nagios_check_domain = 'absent',
    $nagios_check_url = '/',
    $nagios_check_code = '301',
    $mod_security = true,
    $image = 'absent',
    $config = 'unmanaged',
    $db_server = 'unmanaged',
    $db_name = 'unmanaged',
    $db_user = 'unmanaged',
    $db_pwd = 'unmanaged',
    $contact = 'unmanaged',
    $sitename = 'unmanaged',
    $secret_key = 'unmanaged',
    $squid_servers = 'absent',
    $extensions = 'absent',
    $language = 'de'
){
    webhosting::common{$name:
        ensure => $ensure,
        uid => $uid,
        gid => $gid,
        user_provider => $user_provider,
        password => $password,
        password_crypted => $password_crypted,
        htpasswd_file => $htpasswd_file,
        ssl_mode => $ssl_mode,
        run_mode => $run_mode,
        run_uid => $run_uid,
        run_uid_name => $run_uid_name,
        run_gid => $run_gid,
        run_gid_name => $run_gid_name,
        nagios_check => $nagios_check,
        nagios_check_domain => $nagios_check_domain,
        nagios_check_url => $nagios_check_url,
        nagios_check_code => $nagios_check_code,
    }

    apache::vhost::php::mediawiki{"${name}":
        ensure => $ensure,
        domainalias => $domainalias,
        server_admin => $server_admin,
        group => $group,
        manage_docroot => false,
        allow_override => $allow_override,
        options => $options,
        additional_options => $additional_options,
        default_charset => $default_charset,
        run_mode => $run_mode,
        ssl_mode => $ssl_mode,
        vhost_mode => $vhost_mode,
        vhost_source => $vhost_source,
        vhost_destination => $vhost_destination,
        htpasswd_file => $htpasswd_file,
        mod_security => $mod_security,
    }
    mediawiki::instance{$name:
      ensure => $ensure,
      image => $image,
      config => $config,
      db_server => $db_server,
      db_name => $db_name,
      db_user => $db_user,
      db_pwd => $db_pwd,
      contact => $contact,
      sitename => $sitename,
      secret_key => $secret_key,
      extensions => $extensions,
      squid_servers => $squid_servers,
      language => $language,
      documentroot_write_mode => 0660,
    }

    if ($run_mode == 'itk') {
          if ($run_uid_name == 'absent'){
            $real_run_uid_name = "${name}_run"
          } else {
            $real_run_uid_name = $run_uid_name
          }
          if ($run_gid_name == 'absent'){
            $real_run_gid_name = $name
          } else {
            $real_run_gid_name = $run_gid_name
          }
          Apache::Vhost::Php::Mediawiki[$name]{
            documentroot_owner => $name,
            documentroot_group => $name,
            run_uid => $real_run_uid_name,
            run_gid => $real_run_gid_name,
            require => [ User::Sftp_only["${name}"], User::Managed["${real_run_uid_name}"] ],
          }
          Mediawiki::Instance[$name]{
            documentroot_owner => $name,
            documentroot_group => $name,
            documentroot_mode => 0640,
            require => [ User::Sftp_only["${name}"], User::Managed["${real_run_uid_name}"] ],
          }
    } else {
      Apache::Vhost::Php::Mediawiki[$name]{
        require => User::Sftp_only["${name}"],
      }
      Mediawiki::Instance[$name]{
        require => User::Sftp_only["${name}"],
      }
    }
}

