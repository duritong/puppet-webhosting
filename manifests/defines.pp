# manifests/defines.pp

# domainalias:
#   - www: add as well a www.${name} entry
#   - absent: do nothing
#   - default: add the string
define webhosting::static(
    $uid = 'absent',
    $gid = 'absent',
    $password = 'absent',
    $password_crypted = 'true',
    $domainalias = 'www',
    $owner = root,
    $group = 'sftponly',
    $allow_override = 'None',
    $options = 'absent',
    $additional_options = 'absent',
    $ssl_mode = 'false',
    $vhost_mode = 'template',
    $vhost_source = 'absent',
    $vhost_destination = 'absent',
    $htpasswd_file = 'absent',
    $nagios_check_domain = 'absent',
    $nagios_check_url = '/',
    $nagios_check_code = 'OK'
){

    case $domainalias {
        'www': { $real_domainalias = "www.${name}" }
        default: { $real_domainalias = $domainalias }
    }
    user::sftp_only{"${name}":
        uid => $uid,
        gid => $gid,
        password => $password,
        password_crypted => $password_crypted,         
    }

    apache::vhost::static{"${name}":
        domainalias => $real_domainalias,
        group => $group,
        user_owner => $name, 
        allow_override => $allow_override,
        options => $options,
        additional_options => $additional_options,
        ssl_mode => $ssl_mode,
        vhost_mode => $vhost_mode,    
        vhost_source => $vhost_source,
        vhost_destination => $vhost_destination,
        htpasswd_file => $htpasswd_file,
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
}
