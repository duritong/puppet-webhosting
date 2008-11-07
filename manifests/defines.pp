# manifests/defines.pp

define webhosting::static(
    $password = 'absent',
    $password_crypted = 'true',
    $domainalias = 'absent',
    $owner = root,
    $group = 'sftponly',
    $allow_override = 'None',
    $additional_options = 'absent',
    $ssl_mode = 'false',
    $vhost_mode = 'template',
    $vhost_source = 'absent',
    $vhost_destination = 'absent',
    $nagios_check_url = '/',
    $nagios_check_code = 'OK'
){
    user::sftp_only{"${name}":
        password => $password,
        password_crypted => $password_crypted,         
    }

    apache::vhost::static{"${name}":
        domainalias => $domainalias,
        group => $group,
        user_owner => $name, 
        allow_override => $allow_override,
        additional_options => $additional_options,
        ssl_mode => $ssl_mode,
        vhost_mode => $vhost_mode,    
        vhost_source => $vhost_source,
        vhost_destination => $vhost_destination,
    }

    if $use_nagios {
        nagios::service::http{"${name}":
            ssl_mode => $ssl_mode,
            check_url => $nagios_check_url,
            check_code => $nagios_check_code, 
        }
    }
}
