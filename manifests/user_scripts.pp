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

  # script to adjust permission in web directories
  webhosting::user_scripts::script{'adjust_permissions': }

  # update mode script
  include ::acl::requirements
  webhosting::user_scripts::script{'update_mode': }

  # wordpress updates
  require ::wordpress::base
  require ::tmpwatch
  webhosting::user_scripts::script{'update_wordpress': }
}
