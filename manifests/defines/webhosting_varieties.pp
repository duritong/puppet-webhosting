# manifests/defines.pp

# domainalias:
#   - www: add as well a www.${name} entry
#   - absent: do nothing
#   - default: add the string
define webhosting::static(
    $ensure = present,
    $uid = 'absent',
    $gid = 'uid',
    $password = 'absent',
    $password_crypted = true,
    $domainalias = 'www',
    $owner = root,
    $group = 'sftponly',
    $allow_override = 'None',
    $do_includes = false,
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
    $nagios_check_code = 'OK'
){
    webhosting::common{$name:
        ensure => $ensure,
        uid => $uid,
        gid => $gid,
        password => $password,
        password_crypted => $password_crypted,
        htpasswd_file => $htpasswd_file,
        ssl_mode => $ssl_mode,
        run_mode => $run_mode,
        run_uid => $run_uid,
        run_gid => $run_gid,
        nagios_check => $nagios_check,
        nagios_check_domain => $nagios_check_domain,
        nagios_check_url => $nagios_check_url,
        nagios_check_code => $nagios_check_code,
    }
    apache::vhost::static{"${name}":
        ensure => $ensure,
        domainalias => $domainalias,
        group => $group,
        documentroot_owner => $name, 
        documentroot_group => $group, 
        allow_override => $allow_override,
        do_includes => $do_includes,
        options => $options,
        additional_options => $additional_options,
        default_charset => $default_charset,
        ssl_mode => $ssl_mode,
        vhost_mode => $vhost_mode,    
        vhost_source => $vhost_source,
        vhost_destination => $vhost_destination,
        htpasswd_file => $htpasswd_file,
    }
}

# run_mode: 
#   - normal: nothing special (*default*)
#   - itk: apache is running with the itk module 
#          and run_uid and run_gid are used as vhost users
# run_uid: the uid the vhost should run as with the itk module
# run_gid: the gid the vhost should run as with the itk module
define webhosting::modperl(
    $ensure = present,
    $uid = 'absent',
    $gid = 'uid',
    $password = 'absent',
    $password_crypted = true,
    $domainalias = 'www',
    $owner = root,
    $group = 'sftponly',
    $run_mode = 'normal',
    $run_uid = 'absent',
    $run_gid = 'absent',
    $allow_override = 'None',
    $do_includes = false,
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
    $nagios_check_code = 'OK',
    $mod_security = true
){
    webhosting::common{$name:
        ensure => $ensure,
        uid => $uid,
        gid => $gid,
        password => $password,
        password_crypted => $password_crypted,
        htpasswd_file => $htpasswd_file,
        ssl_mode => $ssl_mode,
        run_mode => $run_mode,
        run_uid => $run_uid,
        run_gid => $run_gid,
        nagios_check => $nagios_check,
        nagios_check_domain => $nagios_check_domain,
        nagios_check_url => $nagios_check_url,
        nagios_check_code => $nagios_check_code,
    }
    apache::vhost::modperl{"${name}":
        ensure => $ensure,
        domainalias => $domainalias,
        group => $group,
        allow_override => $allow_override,
        do_includes => $do_includes,
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
    case $run_mode {
        'itk': {
            Apache::Vhost::Modperl[$name]{
                documentroot_owner => $name,
                documentroot_group => $name,
                documentroot_mode => 0750,
                run_uid => "${name}_run",
                run_gid => "${name}",
                require => [ User::Sftp_only["${name}"], User::Managed["${name}_run"] ],
            }
        }
        default: {
            Apache::Vhost::Modperl[$name]{
                require => User::Sftp_only["${name}"], 
            }
        }
    } 
}

# run_mode: 
#   - normal: nothing special (*default*)
#   - itk: apache is running with the itk module 
#          and run_uid and run_gid are used as vhost users
# run_uid: the uid the vhost should run as with the itk module
# run_gid: the gid the vhost should run as with the itk module
define webhosting::php(
    $ensure = present,
    $uid = 'absent',
    $gid = 'uid',
    $password = 'absent',
    $password_crypted = true,
    $domainalias = 'www',
    $owner = root,
    $group = 'sftponly',
    $run_mode = 'normal',
    $run_uid = 'absent',
    $run_gid = 'absent',
    $allow_override = 'None',
    $do_includes = false,
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
    $nagios_check_code = 'OK',
    $mod_security = true
){
    webhosting::common{$name:
        ensure => $ensure,
        uid => $uid,
        gid => $gid,
        password => $password,
        password_crypted => $password_crypted,
        htpasswd_file => $htpasswd_file,
        ssl_mode => $ssl_mode,
        run_mode => $run_mode,
        run_uid => $run_uid,
        run_gid => $run_gid,
        nagios_check => $nagios_check,
        nagios_check_domain => $nagios_check_domain,
        nagios_check_url => $nagios_check_url,
        nagios_check_code => $nagios_check_code,
    }
    apache::vhost::php::standard{"${name}":
        ensure => $ensure,
        domainalias => $domainalias,
        group => $group,
        allow_override => $allow_override,
        do_includes => $do_includes,
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
    case $run_mode {
        'itk': {
            Apache::Vhost::Php::Standard[$name]{
                documentroot_owner => $name,
                documentroot_group => $name,
                documentroot_mode => 0750,
                run_uid => "${name}_run",
                run_gid => "${name}",
                require => [ User::Sftp_only["${name}"], User::Managed["${name}_run"] ],
            }
        }
        default: {
            Apache::Vhost::Php::Standard[$name]{
                require => User::Sftp_only["${name}"], 
            }
        }
    } 
}

# run_mode: 
#   - normal: nothing special (*default*)
#   - itk: apache is running with the itk module 
#          and run_uid and run_gid are used as vhost users
# run_uid: the uid the vhost should run as with the itk module
# run_gid: the gid the vhost should run as with the itk module
define webhosting::php::joomla(
    $ensure = present,
    $uid = 'absent',
    $gid = 'uid',
    $password = 'absent',
    $password_crypted = true,
    $domainalias = 'www',
    $owner = root,
    $group = 'sftponly',
    $run_mode = 'normal',
    $run_uid = 'absent',
    $run_gid = 'absent',
    $allow_override = 'None',
    $do_includes = false,
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
    $nagios_check_code = 'OK',
    $git_repo = 'absent',
    $mod_security = true,
    $manage_config = true,
    $config_webwriteable = false,
    $manage_directories = true
){
    webhosting::common{$name:
        ensure => $ensure,
        uid => $uid,
        gid => $gid,
        password => $password,
        password_crypted => $password_crypted,
        htpasswd_file => $htpasswd_file,
        ssl_mode => $ssl_mode,
        run_mode => $run_mode,
        run_uid => $run_uid,
        run_gid => $run_gid,
        nagios_check => $nagios_check,
        nagios_check_domain => $nagios_check_domain,
        nagios_check_url => $nagios_check_url,
        nagios_check_code => $nagios_check_code,
    }

    $real_path = $path ? {
        'absent' => $operatingsystem ? {
            openbsd => "/var/www/htdocs/${name}",
            default => "/var/www/vhosts/${name}"
        },
        default => "${path}"
    }
    $documentroot = "${real_path}/www"

    apache::vhost::php::joomla{"${name}":
        ensure => $ensure,
        domainalias => $domainalias,
        group => $group,
        allow_override => $allow_override,
        do_includes => $do_includes,
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
        manage_config => $manage_config,
        config_webwriteable => $config_webwriteable,
        manage_directories => $manage_directories,
    }
    if $git_repo != 'absent' {
        # create webdir
        # for the cloning, $documentroot needs to be absent
        git::clone{"git_clone_$name":
            ensure => $ensure,
            git_repo => $git_repo,
            projectroot => $documentroot,
            cloneddir_user => $documentroot_owner,
            cloneddir_group => $documentroot_group,
            before =>  Apache::Vhost::Php::Joomla[$name],
        }
    }
    case $run_mode {
        'itk': {
            Apache::Vhost::Php::Joomla[$name]{
                documentroot_owner => $name,
                documentroot_group => $name,
                documentroot_mode => 0750,
                run_uid => "${name}_run",
                run_gid => "${name}",
                require => [ User::Sftp_only["${name}"], User::Managed["${name}_run"] ],
            }
            if $git_repo != 'absent' {
                Git::Clone["git_clone_$name"]{
                    require => [ User::Sftp_only["${name}"], User::Managed["${name}_run"] ],
                }
            }
        }
        default: {
            Apache::Vhost::Php::Joomla[$name]{
                require => User::Sftp_only["${name}"], 
            }
            if $git_repo != 'absent' {
                Git::Clone["git_clone_$name"]{
                    require => User::Sftp_only["${name}"],
                }
            }
        }
    } 
}

