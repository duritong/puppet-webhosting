# manage webhosting scripts for a certain webhosting
define webhosting::user_scripts::manage(
  $sftp_user,
  $run_user,
  $web_group,
  $ensure                     = 'present',
  $base_path                  = 'absent',
  $scripts                    = 'ALL',
  $options                    = {},
  $user_scripts_help          = 'https://wiki.immerda.ch/index.php/WebhostingUserScripts',
  $user_scripts_admin_address = 'admin@immerda.ch'
){
  $scripts_path = $base_path ? {
    'absent' => "/var/www/vhosts/${name}/scripts",
    default => "${base_path}/scripts"
  }

  $default_options = {
    'adjust_permissions' => {
      'only_webreadable' => [],
      'web_writable'     => [],
    },
  }
  $user_scripts_options = merge($default_options,$options)

  file{
    "user_scripts_${name}":
      path    => $scripts_path,
      recurse => true,
      purge   => true,
      force   => true;
    "incron_adjust_permissions_${name}":
      path    => "/etc/incron.d/${name}_adjust_permissions";
    "incron_update_mode_${name}":
      path    => "/etc/incron.d/${name}_update_mode";
    "incron_update_wordpress_${name}":
      path    => "/etc/incron.d/${name}_update_wordpress";
  }

  if ($ensure == 'absent') {
    File["user_scripts_${name}","incron_adjust_permissions_${name}",
      "incron_update_mode_${name}"]{
        ensure => 'absent',
    }
  } else {
    require ::webhosting::user_scripts

    File["user_scripts_${name}"]{
      ensure => directory,
      owner  => root,
      group  => $web_group,
      mode   => '0440',
    }

    file{ "${scripts_path}/vhost.options":
      content => template('webhosting/user_scripts/vhost.options.erb'),
      owner   => root,
      group   => $web_group,
      mode    => '0440';
    }

    if ('adjust_permissions' in $scripts) or ($scripts == 'ALL') {
      file{
        "${scripts_path}/adjust_permissions":
          ensure  => directory,
          owner   => $sftp_user,
          group   => $web_group,
          mode    => '0600';
        "${scripts_path}/adjust_permissions/adjust_permissions.dirs":
          content => template('webhosting/user_scripts/adjust_permissions/adjust_permissions.dirs.erb'),
          replace => false,
          owner   => $sftp_user,
          group   => $web_group,
          mode    => '0600';
      }
      File["incron_adjust_permissions_${name}"] {
        content => "${scripts_path}/adjust_permissions/ IN_CREATE /opt/webhosting_user_scripts/common/run_incron.sh \$@ \$#\n",
        owner   => root,
        group   => 0,
        mode    => '0400',
        require => File["${scripts_path}/adjust_permissions"],
      }
    } else {
      File["incron_adjust_permissions_${name}"]{
        ensure => 'absent',
      }
    }
    if ('update_wordpress' in $scripts) or ($scripts == 'ALL') {
      file{
        "${scripts_path}/update_wordpress":
          ensure => directory,
          owner  => $sftp_user,
          group  => $web_group,
          mode   => '0600';
        "${scripts_path}/update_wordpress/update_wordpress.dirs":
          content => template('webhosting/user_scripts/update_wordpress/update_wordpress.dirs.erb'),
          replace => false,
          owner   => $sftp_user,
          group   => $web_group,
          mode    => '0600';
      }
      File["incron_update_wordpress_${name}"] {
        content => "${scripts_path}/update_wordpress/ IN_CREATE /opt/webhosting_user_scripts/common/run_incron.sh \$@ \$#\n",
        owner   => root,
        group   => 0,
        mode    => '0400',
        require => File["${scripts_path}/update_wordpress"],
      }
    } else {
      File["incron_update_wordpress_${name}"]{
        ensure => 'absent',
      }
    }
    if ('update_mode' in $scripts) or ($scripts == 'ALL') {
      file{
        "${scripts_path}/update_mode":
          ensure => directory,
          owner  => $sftp_user,
          group  => $web_group,
          mode   => '0600';
      }
      File["incron_update_mode_${name}"] {
        content => "${scripts_path}/update_mode/ IN_CREATE /opt/webhosting_user_scripts/common/run_incron.sh \$@ \$#\n",
        owner   => root,
        group   => 0,
        mode    => '0400',
        require => File["${scripts_path}/update_mode"],
      }
    } else {
      File["incron_update_mode_${name}"]{
        ensure => 'absent',
      }
    }
  }
}
