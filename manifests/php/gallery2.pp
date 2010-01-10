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
# php_safe_mode_exec_bins: An array of local binaries which should be linked in the
#                          safe_mode_exec_bin for this hosting
#                          *default*: None
# php_default_charset: default charset header for php.
#                      *default*: absent, which will set the same as default_charset
#                                 of apache
define webhosting::php::gallery2(
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
    $run_gid_name = 'absent',
    $allow_override = 'None',
    $do_includes = false,
    $options = 'absent',
    $additional_options = 'absent',
    $default_charset = 'absent',
    $ssl_mode = false,
    $php_safe_mode_exec_bins = 'absent',
    $php_default_charset = 'absent',
    $vhost_mode = 'template',
    $vhost_source = 'absent',
    $vhost_destination = 'absent',
    $htpasswd_file = 'absent',
    $nagios_check = 'ensure',
    $nagios_check_domain = 'absent',
    $nagios_check_url = '/',
    $nagios_check_code = '302',
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

    $path = $operatingsystem ? {
        openbsd => "/var/www/htdocs/${name}",
        default => "/var/www/vhosts/${name}"
    }
    $documentroot = "${path}/www"

    $real_php_safe_mode_exec_bins = $php_safe_mode_exec_bins ? {
        'absent' => [ '/usr/bin/convert', '/usr/bin/composite', '/usr/bin/identify' ],
        default => "${php_safe_mode_exec_bins}"
    }

    apache::vhost::php::gallery2{"${name}":
        ensure => $ensure,
        domainalias => $domainalias,
        server_admin => $server_admin,
        group => $group,
        allow_override => $allow_override,
        do_includes => $do_includes,
        options => $options,
        additional_options => $additional_options,
        default_charset => $default_charset,
        run_mode => $run_mode,
        ssl_mode => $ssl_mode,
        php_default_charset => $php_default_charset,
        php_safe_mode_exec_bins => $real_php_safe_mode_exec_bins,
        vhost_mode => $vhost_mode,
        vhost_source => $vhost_source,
        vhost_destination => $vhost_destination,
        htpasswd_file => $htpasswd_file,
        mod_security => $mod_security,
        manage_config => $manage_config,
        config_webwriteable => $config_webwriteable,
        manage_directories => $manage_directories,
    }
    if ($git_repo != 'absent') and ($ensure != 'absent') {
        # create webdir
        # for the cloning, $documentroot needs to be absent
        git::clone{"git_clone_$name":
            ensure => $ensure,
            git_repo => $git_repo,
            projectroot => $documentroot,
            cloneddir_user => $name,
            cloneddir_group => $name,
            before =>  Apache::Vhost::Php::Gallery2[$name],
        }
        apache::vhost::file::documentrootdir{"gallery2gitdir_${name}":
            ensure => $ensure,
            documentroot => $documentroot,
            filename => '.git',
            thedomain => $name,
            owner => $name,
            group => 'root',
            mode => 400,
        }
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
          Apache::Vhost::Php::Gallery2[$name]{
            documentroot_owner => $name,
            documentroot_group => $name,
            run_uid => $real_run_uid_name,
            run_gid => $real_run_gid_name,
            require => [ User::Sftp_only["${name}"], User::Managed["${real_run_uid_name}"] ],
          }
          if ($git_repo != 'absent') and ($ensure != 'absent') {
            Git::Clone["git_clone_$name"]{
              require => [ User::Sftp_only["${name}"], User::Managed["${real_run_uid_name}"] ],
            }
          }
        }
        default: {
            Apache::Vhost::Php::Gallery2[$name]{
                require => User::Sftp_only["${name}"],
            }
            if ($git_repo != 'absent') and ($ensure != 'absent') {
                Git::Clone["git_clone_$name"]{
                    require => User::Sftp_only["${name}"],
                }
            }
        }
    }
}