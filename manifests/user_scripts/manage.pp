# manage webhosting scripts for a certain webhosting
define webhosting::user_scripts::manage (
  String[1] $sftp_user,
  String[1] $run_user,
  String[1] $web_group,
  Variant[Enum['absent'], Stdlib::Unixpath] $base_path = 'absent',
  Variant[Enum['absent'],Array[String[1]]] $scripts = [],
  Hash $options = {},
  $user_scripts_help = 'https://docs.immerda.ch/de/services/webhosting/',
  $user_scripts_admin_address = 'admin@immerda.ch',
) {
  if $scripts != 'absent' {
    $scripts_path = $base_path ? {
      'absent' => "/var/www/vhosts/${name}/scripts",
      default => "${base_path}/scripts",
    }

    $default_options = {
      'adjust_permissions' => {
        'only_webreadable' => [],
        'web_writable'     => [],
      },
      'update_wordpress' => {
        'auto_update' => false,
      },
      'global' => {
        'contact' => true,
      },
    }
    $user_scripts_options = deep_merge($default_options,$options)

    include webhosting::user_scripts
    file {
      "user_scripts_${name}":
        ensure  => directory,
        path    => $scripts_path,
        owner   => root,
        group   => $web_group,
        mode    => '0440',
        recurse => true,
        purge   => true,
        force   => true;
    } -> Exec['/usr/local/sbin/tune_inotify_watches.sh tune']

    if $user_scripts_options['global']['contact'] == true {
      if $webhosting::user_scripts::default_contact_domain {
        $hosting_contact = "${name}@${webhosting::user_scripts::default_contact_domain}"
      } else {
        $hosting_contact = "security@${name}"
      }
    } elsif $user_scripts_options['global']['contact'] {
      $hosting_contact = $user_scripts_options['global']['contact']
    } else {
      $hosting_contact = false
    }

    file {
      "${scripts_path}/vhost.options":
        content => template('webhosting/user_scripts/vhost.options.erb'),
        owner   => root,
        group   => $web_group,
        mode    => '0440';
    }

    intersection($webhosting::user_scripts::scripts_to_deploy.keys, $scripts).each |String[1] $script_name| {
      $config_ext = $webhosting::user_scripts::scripts_to_deploy[$script_name]
      file {
        "${scripts_path}/${script_name}":
          ensure => directory,
          owner  => $sftp_user,
          group  => $web_group,
          mode   => '0600';
      }
      if versioncmp($facts['os']['release']['major'],'9') < 0 {
        file { "incron_${script_name}_${name}":
          path    => "/etc/incron.d/${name}_${script_name}",
          content => "${scripts_path}/${script_name}/ IN_CREATE /opt/webhosting_user_scripts/common/run_incron.sh \$@ \$#\n",
          owner   => root,
          group   => 0,
          mode    => '0400',
          require => [File["${scripts_path}/${script_name}"],Package['incron']];
        }
      }
      if $config_ext {
        file {
          "${scripts_path}/${script_name}/${script_name}.${config_ext}":
            content => template("webhosting/user_scripts/${script_name}/${script_name}.${config_ext}.erb"),
            owner   => $sftp_user,
            group   => $web_group,
            mode    => '0600';
        }
        if ($script_name == 'ssh_authorized_keys') {
          file { "/var/www/ssh_authorized_keys/${sftp_user}":
            content => template('webhosting/user_scripts/ssh_authorized_keys/ssh_authorized_keys.keys.erb'),
            owner   => $sftp_user,
            group   => 0,
            mode    => '0600',
            seltype => 'ssh_home_t';
          }
          if !$user_scripts_options['enforce_ssh_authorized_keys'] {
            File["/var/www/ssh_authorized_keys/${sftp_user}","${scripts_path}/${script_name}/${script_name}.${config_ext}"] {
              replace => false,
            }
          }
        } else {
          File["${scripts_path}/${script_name}/${script_name}.${config_ext}"] {
            replace => false,
          }
        }
      }
    }
  }
  if versioncmp($facts['os']['release']['major'],'7') > 0 {
    $webhosting::user_scripts::scripts_to_deploy.keys.each |String[1] $script_name| {
      if $scripts == 'absent' or !($script_name in $scripts) {
        $_ensure = 'absent'
      } else {
        $_ensure = 'present'
      }
      systemd::unit_file {
        default:
          ensure => $_ensure;
        [ "webhosting-${name}-userscript-${script_name}.service",
          "webhosting-${name}-userscript-${script_name}.path" ]:;
      }
      rsyslog::confd {
        "webhosting-${name}-userscript-${script_name}":
          ensure  => $_ensure,
      }
      if $_ensure == 'present' {
        if $script_name == 'ssh_authorized_keys' {
          $rw_dirs = ['/var/www/ssh_authorized_keys']
        } elsif $script_name in ['adjust_permissions','update_mode'] {
          $rw_dirs = ["/var/www/vhosts/${name}/www"]
        } elsif $script_name in ['update_wordpress'] {
          $rw_dirs = ["/var/www/vhosts/${name}/www","/var/www/vhosts/${name}/private/wp_update_backup"]
        } elsif $script_name in ['pod_restart'] {
          $rw_dirs = ["/var/www/vhosts/${name}/www"]
        } else {
          $rw_dirs = []
        }
        Systemd::Unit_file["webhosting-${name}-userscript-${script_name}.service"]{
          content => epp('webhosting/user_scripts/systemd.path/unit.service.epp', {
            webhosting_name => $name,
            webhosting_dir  => "/var/www/vhosts/${name}",
            scripts_path    => $scripts_path,
            script_name     => $script_name,
            rw_dirs         => $rw_dirs,
          }),
          require => Exec['/usr/local/sbin/tune_inotify_watches.sh tune'],
        } -> Systemd::Unit_file["webhosting-${name}-userscript-${script_name}.path"]{
          content => epp('webhosting/user_scripts/systemd.path/unit.path.epp', {
            webhosting_name => $name,
            scripts_path    => $scripts_path,
            script_name     => $script_name,
          }),
          enable => true,
          active => true,
        }

        Rsyslog::Confd["webhosting-${name}-userscript-${script_name}"]{
          content => epp('webhosting/user_scripts/systemd.path/rsyslog-confd.epp',{
            programname  => "webhosting-${name}-userscript-${script_name}",
            service_name => "webhosting-${name}-userscript-${script_name}",
            logpath      => "/var/www/vhosts/${name}/logs",
            logfile_name => "users-script-${script_name}",
            group        => $web_group,
          }),
        } -> file {
          # manage file to workaround
          # https://access.redhat.com/solutions/3967061
          # logrotate is handled by the general wildcard
          "/var/www/vhosts/${name}/logs/users-script-${script_name}.log":
            ensure => file,
            mode   => '0640',
            owner  => 'root',
            group  => $web_group,
        }
      } else {
        Rsyslog::Confd["webhosting-${name}-userscript-${script_name}"]{
          content => '# absent'
        }
      }
    }
  }
}
