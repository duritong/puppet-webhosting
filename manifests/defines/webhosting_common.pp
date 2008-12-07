# manifests/files/webhosting_standard.pp

define webhosting::common(
    $uid = 'absent',
    $gid = 'uid',
    $password = 'absent',
    $password_crypted = true,
    $htpasswd_file = 'absent',
    $ssl_mode = false,
    $run_mode = 'normal',
    $run_uid = 'absent',
    $run_gid = 'absent',
    $nagios_check_domain = 'absent',
    $nagios_check_url = '/',
    $nagios_check_code = 'OK'
){
    user::sftp_only{"${name}":
        uid => $uid,
        gid => $gid,
        password => $password,
        password_crypted => $password_crypted,
    }

    if $use_nagios {
        case $nagios_check_code {
            'OK': {
                    $real_nagios_check_code = $htpasswd_file ? {
                        'absent' => $nagios_check_code,
                        default => '401'
                    }
            }
            default: { $real_nagios_check_code = $nagios_check_code }
        }

        nagios::service::http{"${name}":
            check_domain => $nagios_check_domain,
            ssl_mode => $ssl_mode,
            check_url => $nagios_check_url,
            check_code => $real_nagios_check_code,
        }
    }

   case $run_mode {
        'itk': {
            case $run_uid {
                'absent': { fail("you need to define run_uid for $name on $fqdn to use itk") }
            }
            case $run_gid {
                'absent': {
                    case $gid {
                        'uid': { $real_run_gid = $uid }
                        default: { $real_run_gid = $gid }
                    }
                }
                default: { $real_run_gid = $run_gid }
            }
            user::managed{"${name}_run":
                uid => $run_uid,
                gid => $real_run_gid,
                manage_group => false,
                require => User::Sftp_only[$name],
            }
            User::Sftp_only["${name}"]{
                homedir_mode => 0755
            }
        }
    }
}
