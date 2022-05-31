# the basics for the user_scripts
class webhosting::user_scripts (
  $default_contact_domain = false,
  $notifications_sender   = "root@${facts['networking']['fqdn']}",
  Hash[String[1], Variant[String[1],Boolean]] $scripts_to_deploy = {
    'adjust_permissions'  => 'dirs',
    'update_mode'         => false,
    'update_wordpress'    => 'dirs',
    'ssh_authorized_keys' => 'keys',
    'pod_restart'         => 'pods',
  },
  Array[String[1]] $static_scripts = ['ssh_authorized_keys'],
  Array[String[1]] $container_scripts = ['ssh_authorized_keys','pod_restart'],
  Array[String[1]] $php_scripts = ['ssh_authorized_keys', 'adjust_permissions', 'update_mode', 'update_wordpress'],
) {
  # on later platforms we use systemd.path
  if versioncmp($facts['os']['release']['major'],'8') < 0 {
    require incron
  }

  # common stuff
  file {
    ['/opt/webhosting_user_scripts',
      '/opt/webhosting_user_scripts/common',
    ]:
      ensure => directory,
      owner  => root,
      group  => 0,
      mode   => '0400';
    '/opt/webhosting_user_scripts/common/webscripts.rb':
      source => 'puppet:///modules/webhosting/user_scripts/common/webscripts.rb',
      owner  => root,
      group  => 0,
      mode   => '0400';
    '/opt/webhosting_user_scripts/common/run_incron.sh':
      source => 'puppet:///modules/webhosting/user_scripts/common/run_incron.sh',
      owner  => root,
      group  => 0,
      mode   => '0500';
  }
  # deploy scripts
  $all_scripts = $scripts_to_deploy.keys
  $all_scripts.each |String $script_name| {
    file {
      "/opt/webhosting_user_scripts/${script_name}":
        ensure => directory,
        owner  => root,
        group  => 0,
        mode   => '0400';
      "/opt/webhosting_user_scripts/${script_name}/${script_name}.rb":
        source => "puppet:///modules/webhosting/user_scripts/${script_name}/${script_name}.rb",
        owner  => root,
        group  => 0,
        mode   => '0500';
    }
  }

  logrotate::rule {
    'webhosting-scripts':
      path         => '/var/www/vhosts/*/logs/users-script-*.log',
      rotate       => 7,
      compress     => true,
      copytruncate => true,
      dateext      => true,
      missingok    => true,
      su           => true,
  }

  # script dependencies
  # update mode script
  include posix_acl::requirements

  # wordpress updates
  require wordpress::base
  require tmpwatch
  require rubygems::mail

  file {
    '/usr/local/sbin/auto_update_wordess':
      source  => 'puppet:///modules/webhosting/update_scripts/auto_update_wordess.rb',
      require => File['/opt/webhosting_user_scripts/update_wordpress/update_wordpress.rb'],
      owner   => root,
      group   => 0,
      mode    => '0500';
  } -> file {
    '/etc/cron.daily/auto_update_wordess':
      content => "#!/bin/bash\n/usr/local/sbin/auto_update_wordess ${notifications_sender}> /var/log/auto_update_wordess.log\n",
      owner   => root,
      group   => 0,
      mode    => '0500';
  } -> logrotate::rule {
    'auto-update-wordpress':
      path         => '/var/log/auto_update_wordess.log',
      rotate       => 7,
      compress     => true,
      copytruncate => true,
      dateext      => true,
      missingok    => true,
  }
  # manage ssh keys
  if $facts['os']['selinux']['enabled'] {
    selinux::fcontext {
      '/var/www/ssh_authorized_keys(/.*)?':
        setype => 'ssh_home_t',
        before => File['/var/www/ssh_authorized_keys'],
    }
  }
  file {
    '/var/www/ssh_authorized_keys':
      ensure  => directory,
      owner   => root,
      group   => 0,
      mode    => '0444',
      purge   => true,
      force   => true,
      recurse => true,
      seltype => 'ssh_home_t',
  }
}
