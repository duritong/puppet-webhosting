# Manages common things amongst webhostings
# user_provider:
#   - local: user will be crated locally (*default*)
#   - ldap: ldap settings will be passed and ldap authorization
#           is mandatory using webdav as user_access
#   - everything else will currently do noting
# user_access:
#   - sftp: an sftp only user will be created (*default*)
#   - webdav: a webdav vhost will be created which will point to the webhostings root
# wwwmail:
#   With a local user_provider this will include the web run user in a group called wwwmailers.
#   This makes it easier to enable special rights on a webserver's mailserver to this group.
#   - default: false
# ldap_user: Used if you have set user_provider to `ldap`
#   - absent: $name will be passed
#   - any: any authenticated ldap user will work
#   - everything else will be used as a required ldap username
define webhosting::common(
    $ensure = present,
    $uid = 'absent',
    $uid_name = 'absent',
    $gid = 'uid',
    $gid_name = 'absent',
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
    $wwwmail = false,
    $watch_adjust_webfiles = false,
    $user_scripts = 'absent',
    $user_scripts_options = {},
    $nagios_check = 'ensure',
    $nagios_check_domain = 'absent',
    $nagios_check_url = '/',
    $nagios_check_code = 'OK',
    $nagios_use = 'generic-service',
    $ldap_user = 'absent'
){
    if ($run_gid == 'absent') {
        if ($gid == 'uid') {
            $real_run_gid = $uid
        } else {
            $real_run_gid = $gid
        }
    } else {
        $real_run_gid = $run_gid
    }
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
    if ($run_uid_name == 'absent'){
        $real_run_uid_name = "${name}_run"
    } else {
        $real_run_uid_name = $run_uid_name
    }

    $vhost_path = $::operatingsystem ? {
      openbsd => "/var/www/htdocs/${name}",
      default => "/var/www/vhosts/${name}"
    }

    if ($user_provider == 'local') and ($user_access == 'sftp') {
        user::sftp_only{$real_uid_name:
            ensure => $ensure,
            uid => $uid ? {
                'iuid' => iuid($real_uid_name,'webhosting'),
                default => $uid
            },
            gid => $gid,
            password => $password ? {
                'trocla' => trocla("webhosting_${real_uid_name}",'sha512crypt'),
                default => $password
            },
            password_crypted => $password_crypted,
            homedir => $vhost_path,
        }
        include apache::sftponly
    }

    case $run_mode {
      'fcgid','static','itk','proxy-itk','static-itk': {
        if ($user_access == 'sftp') {
          if ($ensure != 'absent') {
            User::Sftp_only["${real_uid_name}"]{
              homedir_mode => 0755,
            }
          }
          user::groups::manage_user{"apache_in_${real_gid_name}":
            group => $real_gid_name,
            user => 'apache'
          }
          case $run_mode {
            'fcgid','static','static-itk': {
              User::Groups::Manage_user["apache_in_${real_gid_name}"]{
                ensure => $ensure,
              }
              if $ensure == 'present' {
                User::Groups::Manage_user["apache_in_${real_gid_name}"]{
                  require => User::Sftp_only["${real_uid_name}"],
                }
              }
            }
            default: {
              User::Groups::Manage_user["apache_in_${real_gid_name}"]{
                ensure => 'absent'
              }
            }
          }
        }
      }
    }
    case $run_mode {
      'fcgid','itk','proxy-itk','static-itk': {
        if ($run_uid=='absent') and ($ensure != 'absent') {
            fail("you need to define run_uid for $name on $fqdn to use itk")
        }
        if ($user_provider == 'local') {
          user::managed{$real_run_uid_name:
            ensure => $ensure,
            uid => $run_uid ? {
                'iuid' => iuid($real_run_uid_name,'webhosting'),
                default => $run_uid,
            },
            manage_group => false,
            managehome => false,
            homedir => $vhost_path,
            shell => $::operatingsystem ? {
              debian => '/usr/sbin/nologin',
              ubuntu => '/usr/sbin/nologin',
              default => '/sbin/nologin'
            },
          }
          if ($user_access == 'sftp') {
            if ($ensure == 'absent') {
              User::Managed[$real_run_uid_name]{
                before => User::Sftp_only[$real_uid_name],
              }
            } else {
              User::Managed[$real_run_uid_name]{
                require => User::Sftp_only[$real_uid_name],
              }
            }
          }

          if $wwwmail {
            user::groups::manage_user{"${real_run_uid_name}_in_wwwmailers":
              ensure => $ensure,
              group => 'wwwmailers',
              user => $real_run_uid_name
            }
            if ($ensure == 'present') {
              require webhosting::wwwmailers
              User::Groups::Manage_user["${real_run_uid_name}_in_wwwmailers"]{
                require => User::Managed[$real_run_uid_name],
              }
            }
          }
          if ($ensure == 'present') {
            User::Managed[$real_run_uid_name]{
              gid => $real_run_gid ? {
                  'iuid' => iuid($real_uid_name,'webhosting'),
                  default => $real_run_gid,
              },
            }
          }
        }
      }
    }

    if ($user_access == 'webdav'){
        apache::vhost::webdav{"webdav.${name}":
            domain => $webdav_domain,
            manage_webdir => false,
            path => $vhost_path,
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

    if hiera('use_nagios',false) and ($nagios_check != 'unmanaged') {
        if $nagios_check == 'ensure' {
            $nagios_ensure = $ensure
        } else {
            $nagios_ensure = $nagios_check
        }
        $real_nagios_check_code = $htpasswd_file ? {
          'absent' => $nagios_check_code,
           default => '401'
        }

        nagios::service::http{"${name}":
            ensure => $nagios_ensure,
            check_domain => $nagios_check_domain,
            ssl_mode => $ssl_mode,
            check_url => $nagios_check_url,
            use => $nagios_use,
            check_code => $real_nagios_check_code,
        }
    }

    if $watch_adjust_webfiles {
      webhosting::watch_adjust_webfiles{
        $name:
          ensure => $watch_adjust_webfiles ? {
            true => $ensure,
            default => "absent"
          },
          path => "${vhost_path}/www/",
          sftp_user => $real_uid_name,
          run_user => $real_run_uid_name,
      }
    }

    if $ensure != 'absent' {
      webhosting::user_scripts::manage{$name:
        ensure => $user_scripts ? {
          'absent' => 'absent',
          default => 'present'
        },
        base_path => $vhost_path,
        scripts => $user_scripts,
        sftp_user => $real_uid_name,
        web_group => $real_gid_name,
        options => $user_scripts_options,
      }
    }
}
