# domainalias:
#   - www: add as well a www.${name} entry
#   - absent: do nothing
#   - default: add the string
# user_provider:
#   - local: user will be crated locally (*default*)
#   - ldap: ldap settings will be passed and ldap authorization
#           is mandatory using webdav as user_access
#   - everything else will currently do noting
# run_mode:
#   - normal: nothing special (*default*)
#   - itk: apache is running with the itk module
#          and run_uid and run_gid are used as vhost users
# run_uid: the uid the vhost should run as with the itk module
# run_gid: the gid the vhost should run as with the itk module
# user_access:
#   - sftp: an sftp only user will be created (*default*)
#   - webdav: a webdav vhost will be created which will point to the webhostings root
# ldap_user: Used if you have set user_provider to `ldap`
#   - absent: $name will be passed
#   - any: any authenticated ldap user will work
#   - everything else will be used as a required ldap username
define webhosting::php(
    $ensure = present,
    $uid = 'absent',
    $gid = 'uid',
    $user_provider = 'local',
    $user_access = 'sftp',
    $webdav_domain = 'absent',
    $webdav_ssl_mode = false,
    $password = 'absent',
    $password_crypted = true,
    $domainalias = 'www',
    $server_admin = 'absent',
    $owner = root,
    $group = 'absent',
    $run_mode = 'normal',
    $run_uid = 'absent',
    $run_uid_name = 'absent',
    $run_gid = 'absent',
    $run_gid_name = 'absent',
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
    $mod_security = true,
    $ldap_user = 'absent'
){

    if ($group == 'absent') and ($user_access == 'sftp') {
        $real_group = 'sftponly'
    } else {
        if ($group == 'absent') {
            $real_group = 'apache'
        } else {
            $real_group = $group
        }
    }

    webhosting::common{$name:
        ensure => $ensure,
        uid => $uid,
        gid => $gid,
        user_provider => $user_provider,
        user_access => $user_access,
        webdav_ssl_mode => $webdav_ssl_mode,
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
        ldap_user => $ldap_user,
    }
    apache::vhost::php::standard{"${name}":
        ensure => $ensure,
        domainalias => $domainalias,
        server_admin => $server_admin,
        group => $real_group,
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
            if ($user_provider == 'local') {
                Apache::Vhost::Modperl[$name]{
                    require => [ User::Sftp_only["${name}"], User::Managed["${real_run_uid_name}"] ],
                }
            }
        }
        default: {
            if ($user_provider == 'local') {
                Apache::Vhost::Modperl[$name]{
                    require => User::Sftp_only["${name}"],
                }
            }
        }
    }
}

