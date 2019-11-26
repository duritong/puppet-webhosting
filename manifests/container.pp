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
  String
    $image,
  Integer[1,65535]
    $port,
  Enum['present','absent']
    $ensure             = present,
  Hash
    $configuration      = {},
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
    configuration         => $configuration + {
      containers          => {
        $name => pick($configuration['container_config'],{}) + {
          ensure         => $ensure,
          user           => $uid_name,
          uid            => $real_uid,
          gid            => $real_gid,
          homedir        => "/var/www/vhosts/${name}",
          manage_user    => false,
          image          => $image,
          publish_socket => {
            $port => {
              'dir'                     => "/var/www/vhosts/${name}/tmp/run",
              'security-opt-label-type' => 'socat_httpd_sidecar',
            },
          },
          run_flags      => {
            'security-opt-label-type' => 'httpd_container_rw_content',
          },
        }
      }
    }
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
    options            => "unix:/var/www/vhosts/${name}/tmp/run/${port}|http://${name}"
  }
  if $template_partial != 'absent' {
    Apache::Vhost::Static[$name]{
      template_partial => $template_partial
    }
  }
}
