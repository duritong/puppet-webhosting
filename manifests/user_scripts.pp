# the basics for the user_scripts
class webhosting::user_scripts {
  require ::incron

  # common stuff
  file{
    [ '/opt/webhosting_user_scripts',
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
  ['adjust_permissions','update_mode',
    'update_wordpress','ssh_authorized_keys'].each |String $script_name| {
    file{
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
  # script dependencies
  # update mode script
  include ::acl::requirements

  # wordpress updates
  require ::wordpress::base
  require ::tmpwatch

  # manage ssh keys
  if $facts['selinux'] {
    selinux::fcontext{'/var/www/ssh_authorized_keys(/.*)?':
      setype => 'ssh_home_t',
      before => File['/var/www/ssh_authorized_keys'],
    }
  }
  file{'/var/www/ssh_authorized_keys':
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
