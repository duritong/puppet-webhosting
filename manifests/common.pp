# Manages common things amongst webhostings
# user_provider:
#   - local: user will be crated locally (*default*)
#   - ldap: ldap settings will be passed and ldap authorization
#           is mandatory using webdav as user_access
#   - everything else will currently do noting
# user_access:
#   - sftp: an sftp only user will be created (*default*)
#   - webdav: a webdav vhost will be created which will point to the webhostings root
# ldap_user: Used if you have set user_provider to `ldap`
#   - absent: $name will be passed
#   - any: any authenticated ldap user will work
#   - everything else will be used as a required ldap username
define webhosting::common(
    $ensure = present,
    $uid = 'absent',
    $gid = 'uid',
    $user_provider = 'local',
    $user_access = 'sftp',
    $webdav_domain = 'absent',
    $webdav_ssl_mode = false,
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
    $nagios_check_code = 'OK',
    $ldap_user = 'absent'
){
    if ($user_provider == 'local') and ($user_access == 'sftp') {
        user::sftp_only{"${name}":
            ensure => $ensure,
            uid => $uid,
            gid => $gid,
            password => $password,
            password_crypted => $password_crypted,
        }
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
    if ($run_mode == 'itk') {
        if ($run_uid=='absent') and ($ensure != 'absent') {
            fail("you need to define run_uid for $name on $fqdn to use itk")
        }
        if ($user_provider == 'local') {
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
            }
            if ($user_access == 'sftp') {
                User::Managed[$real_run_uid_name]{
                    require => User::Sftp_only[$name],
                }
                User::Sftp_only["${name}"]{
                    homedir_mode => 0755,
                }
            }
        }
    }

    if ($user_access == 'webdav'){
        apache::vhost::webdav{"webdav.${name}":
            domain => $webdav_domain,
            manage_webdir => false,
            path => $operatingsystem ? {
                openbsd => "/var/www/htdocs/$name",
                default => "/var/www/vhosts/$name"
            },
            path_is_webdir => true,
            run_mode => $run_mode,
            run_uid => $run_uid,
            run_gid => $run_gid,
            ssl_mode => $webdav_ssl_mode,
        }
        if ($user_provider == 'ldap'){
            if ($ldap_user == 'absent') {
                $real_ldap_user = $name
            } else {
                $real_ldap_user = $ldap_user
            }
            Apache::Vhost::Webdav["webdav.${name}"]{
                ldap_auth => true,
                ldap_user => $real_ldap_user,
            }
        }
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
}
