# An update script for smf installed by git
# from the ismf repository.
class webhosting::php::simplemachine::base {
  file{
    '/usr/local/sbin/update_smf_webhostings.sh':
      source => 'puppet:///modules/webhostings/update_scripts/update_smfs_webhostings.sh',
      owner  => root,
      group  => 0,
      mode   => '0700';
  }
}
