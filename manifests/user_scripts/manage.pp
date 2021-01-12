# manage webhosting scripts for a certain webhosting
define webhosting::user_scripts::manage (
  $sftp_user,
  $run_user,
  $web_group,
  $base_path                  = 'absent',
  $scripts                    = 'ALL',
  $options                    = {},
  $user_scripts_help          = 'https://wiki.immerda.ch/index.php/WebhostingUserScripts',
  $user_scripts_admin_address = 'admin@immerda.ch'
) {
  if $scripts != 'absent' {
    $scripts_path = $base_path ? {
      'absent' => "/var/www/vhosts/${name}/scripts",
      default => "${base_path}/scripts"
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

    require webhosting::user_scripts
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
    }

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

    $webhosting::user_scripts::scripts_to_deploy.each |String $script_name, Variant[String, Boolean] $config_ext| {
      if ($script_name in $scripts) or ($scripts == 'ALL') {
        file {
          "${scripts_path}/${script_name}":
            ensure => directory,
            owner  => $sftp_user,
            group  => $web_group,
            mode   => '0600';
          "incron_${script_name}_${name}":
            path    => "/etc/incron.d/${name}_${script_name}",
            content => "${scripts_path}/${script_name}/ IN_CREATE /opt/webhosting_user_scripts/common/run_incron.sh \$@ \$#\n",
            owner   => root,
            group   => 0,
            mode    => '0400',
            require => File["${scripts_path}/${script_name}"];
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
  }
}
