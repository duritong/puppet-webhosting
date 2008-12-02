# manifests/defines.pp

# domainalias:
#   - www: add as well a www.${name} entry
#   - absent: do nothing
#   - default: add the string
define webhosting::static(
    $uid = 'absent',
    $gid = 'uid',
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
        documentroot_owner => $name, 
        documentroot_group => $group, 
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

# run_mode: 
#   - normal: nothing special (*default*)
#   - itk: apache is running with the itk module 
#          and run_uid and run_gid are used as vhost users
# run_uid: the uid the vhost should run as with the itk module
# run_gid: the gid the vhost should run as with the itk module
define webhosting::modperl(
    $uid = 'absent',
    $gid = 'uid',
    $password = 'absent',
    $password_crypted = 'true',
    $domainalias = 'www',
    $owner = root,
    $group = 'sftponly',
    $run_mode = 'normal',
    $run_uid = 'absent',
    $run_gid = 'absent',
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
                manage_group => 'false',
                require => User::Sftp_only[$name],
            }
            User::Sftp_only["${name}"]{ 
                homedir_mode => 0755 
            }
            Apache::Vhost::Modperl[$name]{
                documentroot_owner => $name,
                documentroot_group => $name,
                documentroot_mode => 0750,
            }
        }
    } 

    apache::vhost::modperl{"${name}":
        domainalias => $real_domainalias,
        group => $group,
        allow_override => $allow_override,
        options => $options,
        additional_options => $additional_options,
        run_mode => $run_mode,
        run_uid => "${name}_run",
        run_gid => "${name}",
        ssl_mode => $ssl_mode,
        vhost_mode => $vhost_mode,
        vhost_source => $vhost_source,
        vhost_destination => $vhost_destination,
        htpasswd_file => $htpasswd_file,
        require => [ User::Sftp_only["${name}"], User::Managed["${name}_run"] ],
    }
   case $run_mode {
        'itk': {
            Apache::Vhost::Modperl[$name]{
                documentroot_owner => $name,
                documentroot_group => $name,
                documentroot_mode => 0750,
            }
        }
    } 
}
