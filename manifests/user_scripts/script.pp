# deploy a script
define webhosting::user_scripts::script(){
  file{
    "/opt/webhosting_user_scripts/${name}":
      ensure => directory,
      owner  => root,
      group  => 0,
      mode   => '0400';
    "/opt/webhosting_user_scripts/${name}/${name}.rb":
      source => "puppet:///modules/webhosting/user_scripts/${name}/${name}.rb",
      owner  => root,
      group  => 0,
      mode   => '0500';
  }
}
