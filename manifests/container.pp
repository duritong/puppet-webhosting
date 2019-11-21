# domainalias:
#   - www: add as well a www.${name} entry
#   - absent: do nothing
#   - default: add the string
#
# logmode:
#   - default: Do normal logging to CustomLog and ErrorLog
#   - nologs: Send every logging to /dev/null
#   - anonym: Don't log ips for CustomLog, send ErrorLog to /dev/null
#   - semianonym: Don't log ips for CustomLog, log normal ErrorLog
define webhosting::container(
  String $image,
  $ensure               = present,
  $configuration        = {},
  $uid                  = 'absent',
  $uid_name             = $name,
  $gid                  = 'uid',
  $gid_name             = 'absent',
  $password             = 'absent',
  $password_crypted     = true,
  $domain               = 'absent',
  $domainalias          = 'www',
  $server_admin         = 'absent',
  $logmode              = 'default',
  $owner                = root,
  $group                = 'absent',
  $allow_override       = 'None',
  $do_includes          = false,
  $additional_options   = 'absent',
  $default_charset      = 'absent',
  $ssl_mode             = false,
  $vhost_mode           = 'template',
  $template_partial     = 'absent',
  $vhost_source         = 'absent',
  $vhost_destination    = 'absent',
  $htpasswd_file        = 'absent',
  $nagios_check         = 'ensure',
  $nagios_check_domain  = 'absent',
  $nagios_check_url     = '/',
  $nagios_check_code    = '200',
  $nagios_use           = 'generic-service',
  $watch_adjust_webfiles  = 'absent',
  $user_scripts         = 'absent',
  $user_scripts_options = {},
){
  if ($gid_name == 'absent'){
    $real_gid_name = $uid_name
  } else {
    $real_gid_name = $gid_name
  }
  if ($group == 'absent') {
    $real_group = $real_gid_name
  } else {
    $real_group = 'apache'
  }
  $real_uid = $uid ? {
    'iuid'  => iuid($uid_name,'webhosting'),
    default => $uid,
  }
  if ($gid == 'uid') {
    $real_gid = $real_uid
  } else {
    $real_gid = $gid ? {
      'iuid'  => iuid($uid_name,'webhosting'),
      default => $gid,
    }
  }
  webhosting::common{$name:
    ensure                => $ensure,
    configuration         => $configuration,
    uid                   => $real_uid,
    uid_name              => $uid_name,
    gid                   => $real_gid,
    gid_name              => $real_gid_name,
    password              => $password,
    password_crypted      => $password_crypted,
    htpasswd_file         => $htpasswd_file,
    ssl_mode              => $ssl_mode,
    run_mode              => 'static',
    nagios_check          => $nagios_check,
    nagios_check_domain   => $nagios_check_domain,
    nagios_check_url      => $nagios_check_url,
    nagios_check_code     => $nagios_check_code,
    nagios_use            => $nagios_use,
    git_repo              => $git_repo,
    watch_adjust_webfiles => $watch_adjust_webfiles,
    user_scripts          => $user_scripts,
    user_scripts_options  => $user_scripts_options,
  } -> podman::container{
    $name:
      ensure         => $ensure,
      user           => $uid_name,
      uid            => $real_uid,
      gid            => $real_gid,
      homedir        => "/var/www/vhosts/${name}",
      container_name => 'con',
      manage_user    => false,
      image          => $image,
      publish        => ["8080:80"],
      run_flags      => {
        userns                    => 'keep-id',
        user                      => "${real_uid}:${real_gid}",
        'security-opt-label-type' => 'httpd_container_rw_content',
      },
      volumes        => {},
  } -> Service['apache']

  apache::vhost::container{$name:
    ensure             => $ensure,
    configuration      => $configuration,
    domain             => $domain,
    domainalias        => $domainalias,
    server_admin       => $server_admin,
    logmode            => $logmode,
    group              => $real_group,
    documentroot_owner => $uid_name,
    documentroot_group => $real_group,
    allow_override     => $allow_override,
    do_includes        => $do_includes,
    additional_options => $additional_options,
    default_charset    => $default_charset,
    ssl_mode           => $ssl_mode,
    vhost_mode         => $vhost_mode,
    vhost_source       => $vhost_source,
    vhost_destination  => $vhost_destination,
    htpasswd_file      => $htpasswd_file,
    options            => "http://127.0.0.1:8080",
  }
  if $template_partial != 'absent' {
    Apache::Vhost::Static[$name]{
      template_partial => $template_partial
    }
  }

  if $ensure == 'present' {
    exec{"adjust_path_access_for_keep-user-id_/var/www/vhosts/${name}":
      command => "bash -c \"setfacl -m user:$(grep -E '^${uid_name}:' /etc/subuid | cut -d: -f 2):rx /var/www/vhosts/${name}\"",
      unless  => "getfacl -p -n /var/www/vhosts/${name}  | grep -qE \"^user:$(grep -E '^${uid_name}:' /etc/subuid | cut -d: -f 2):r-x\\$\"",
      require => [File["/var/www/vhosts/${name}"],User[$uid_name]];
    } -> Podman::Container[$name]
  }
}
