# Manages common things amongst webhostings
# user_access:
#   - sftp: an sftp only user will be created (*default*)
# wwwmail:
#   This will include the web run user in a group called wwwmailers.
#   This makes it easier to enable special rights on a webserver's mailserver to
#   this group.
#   - default: false
define webhosting::common(
  $ensure                = present,
  $configuration         = {},
  $uid                   = 'absent',
  $uid_name              = 'absent',
  $gid                   = 'uid',
  $gid_name              = 'absent',
  $user_access           = 'sftp',
  $password              = 'absent',
  $password_crypted      = true,
  $htpasswd_file         = 'absent',
  $ssl_mode              = false,
  $run_mode              = 'normal',
  $run_uid               = 'absent',
  $run_uid_name          = 'absent',
  $run_gid               = 'absent',
  $wwwmail               = false,
  $watch_adjust_webfiles = 'absent',
  $user_scripts          = 'absent',
  $user_scripts_options  = {},
  $nagios_check          = 'ensure',
  Variant[String,Array[String]]
    $nagios_check_domain   = 'absent',
  $nagios_check_url      = '/',
  $nagios_check_code     = '200',
  $nagios_use            = 'generic-service',
  $git_repo              = 'absent',
  $php_installation      = false,
){
  if ($run_gid == 'absent') {
    if ($gid == 'uid') {
      $real_run_gid = $uid
    } else {
      $real_run_gid = $gid
    }
  } else {
    $real_run_gid = $run_gid
  }
  if ($uid_name == 'absent'){
    $real_uid_name = $name
  } else {
    $real_uid_name = $uid_name
  }
  if ($gid_name == 'absent'){
    $real_gid_name = $real_uid_name
  } else {
    $real_gid_name = $gid_name
  }
  if ($run_uid_name == 'absent'){
    $real_run_uid_name = "${name}_run"
  } else {
    $real_run_uid_name = $run_uid_name
  }

  $vhost_path = "/var/www/vhosts/${name}"

  if ($user_access == 'sftp') or ('containers' in $configuration) {
    $real_uid = $uid ? {
      'iuid'  => iuid($real_uid_name,'webhosting'),
      default => $uid
    }
    if 'containers' in $configuration {
      if $ensure == 'present' {
        if !defined(File["${vhost_path}/tmp"]) {
          file{
            "${vhost_path}/tmp":
              ensure  => directory,
              owner   => $real_uid_name,
              group   => $real_gid_name,
              mode    => '0750',
              seltype => 'httpd_sys_rw_content_t';
          }
        }
        # Setup folder structure for general app hosting
        # Idea:
        #   - /app has readonly mounted any kind of app files
        #   - /data is a writeable webfolder in ~/www that can exposed directly
        #   - /private is a writeable (therefore in ~/data due to SELinux) but
        #              private to the webserver (therefore in ~/data/private
        #              with 0700 on ~/data)
        # '/var/www/vhosts/HOSTING/private/app': '/app:ro'
        # '/var/www/vhosts/HOSTING/data/private/data': '/private'
        # '/var/www/vhosts/HOSTING/www/data': '/data'
        file{
          "${vhost_path}/data/private":
            ensure  => directory,
            owner   => $real_uid_name,
            group   => $real_gid_name,
            mode    => '0700',
            seltype => 'httpd_sys_rw_content_t';
          "${vhost_path}/data/private/data":
            ensure  => directory,
            owner   => $real_uid_name,
            group   => $real_gid_name,
            mode    => '0770',
            seltype => 'httpd_sys_rw_content_t';
          "${vhost_path}/private/app":
            ensure  => directory,
            owner   => $real_uid_name,
            group   => $real_gid_name,
            mode    => '0755',
            seltype => 'httpd_sys_content_t';
          "${vhost_path}/tmp/run":
            ensure  => directory,
            owner   => $real_uid_name,
            group   => $real_gid_name,
            mode    => '0777',
            seltype => 'httpd_var_run_t';
        } -> Podman::Container<| tag == "user_${real_uid_name}" |>
        # we don't know the users subuid/subgid
        # Must be set if we might want to do keep-user-id
        # https://lists.podman.io/archives/list/podman@lists.podman.io/thread/LA2J5LY6SZMNMPLDGE4DKIV2CFLGPOXC/
        exec{"adjust_path_access_for_keep-user-id_${vhost_path}":
          command => "bash -c \"setfacl -m user:$(grep -E '^${real_uid_name}:' /etc/subuid | cut -d: -f 2):rx ${vhost_path}\"",
          unless  => "getfacl -p -n ${vhost_path}  | grep -qE \"^user:$(grep -E '^${real_uid_name}:' /etc/subuid | cut -d: -f 2):r-x\\$\"",
          require => [File[$vhost_path],User[$real_uid_name]];
        } -> Podman::Container<| tag == "user_${real_uid_name}" |>
      }

      $configuration['containers'].each |$con_name,$vals| {
        $run_flags = pick($vals['run_flags'],{})
        $con_values = ($vals - 'run_flags') + {
          ensure         => $ensure,
          user           => $real_uid_name,
          uid            => $real_uid,
          container_name => $con_name,
          gid            => $gid,
          homedir        => $vhost_path,
          manage_user    => false,
          logpath        => "${vhost_path}/logs",
          run_flags      => $run_flags + {
            'security-opt-label-type' => 'httpd_container_rw_content',
          },
          tag            => "user_${real_uid_name}",
        }
        podman::container{
          "${name}-${con_name}":
            * => $con_values,
        }
      }
    }

    if ($user_access == 'sftp') {
      $real_password = $password ? {
        'trocla' => trocla("webhosting_${real_uid_name}",'sha512crypt'),
        default  => $password
      }
      user::sftp_only{$real_uid_name:
        ensure           => $ensure,
        password_crypted => $password_crypted,
        homedir          => $vhost_path,
        gid              => $gid,
        uid              => $real_uid,
        password         => $real_password,
      }
      include apache::sftponly
    }
  }

  if $run_mode in ['fpm','fcgid','static'] {
    if ($user_access == 'sftp') {
      if ($ensure != 'absent') {
        User::Sftp_only[$real_uid_name]{
          homedir_mode => '0750',
        }
      }
      user::groups::manage_user{
        "apache_in_${real_gid_name}":
          ensure => $ensure,
          group  => $real_gid_name,
          user   => 'apache',
          notify => Service['apache'],
      }
      if $ensure == 'present' {
        User::Groups::Manage_user["apache_in_${real_gid_name}"]{
          require => User::Sftp_only[$real_uid_name],
        }
      }
    }
  }
  if $run_mode in ['fpm','fcgid'] {
    if ($run_uid=='absent') and ($ensure != 'absent') {
      fail("you need to define run_uid for ${name} on ${::fqdn} to use fpm or fcgid")
    }
    $real_run_uid = $run_uid ? {
      'iuid'  => iuid($real_run_uid_name,'webhosting'),
      default => $run_uid,
    }
    $shell = $::operatingsystem ? {
      /^(Debian|Ubuntu)$/ => '/usr/sbin/nologin',
      default             => '/sbin/nologin',
    }
    user::managed{$real_run_uid_name:
      ensure       => $ensure,
      manage_group => false,
      managehome   => false,
      homedir      => $vhost_path,
      uid          => $real_run_uid,
      shell        => $shell,
    }
    if ($user_access == 'sftp') {
      if ($ensure == 'absent') {
        User::Managed[$real_run_uid_name]{
          before => User::Sftp_only[$real_uid_name],
        }
      } else {
        User::Managed[$real_run_uid_name]{
          require => User::Sftp_only[$real_uid_name],
        }
      }
    }

    if $wwwmail {
      user::groups::manage_user{
        "${real_run_uid_name}_in_wwwmailers":
          ensure => $ensure,
          group  => 'wwwmailers',
          user   => $real_run_uid_name,
      }
      if ($ensure == 'present') {
        require webhosting::wwwmailers
        User::Groups::Manage_user["${real_run_uid_name}_in_wwwmailers"]{
          require => User::Managed[$real_run_uid_name],
        }
      }
    }
    if ($ensure == 'present') {
      $rreal_run_gid = $real_run_gid ? {
        'iuid'  => iuid($real_uid_name,'webhosting'),
        default => $real_run_gid,
      }
      User::Managed[$real_run_uid_name]{
        gid => $rreal_run_gid,
      }
    }
  }

  if $nagios_check != 'unmanaged' {
    if $nagios_check == 'ensure' {
      $nagios_ensure = $ensure
    } else {
      $nagios_ensure = $nagios_check
    }
    $real_nagios_check_code = $htpasswd_file ? {
      'absent'  => $nagios_check_code,
      false     => $nagios_check_code,
      default   => '401'
    }

    $default_nagios_vals = {
      ensure       => $nagios_ensure,
      check_domain => $nagios_check_domain,
      ssl_mode     => $ssl_mode,
      check_url    => $nagios_check_url,
      use          => $nagios_use,
      check_code   => $real_nagios_check_code,
    }
    nagios::service::http{
      $name:
        * => $default_nagios_vals,
    }
    if 'additional_nagios_checks' in $configuration {
      $configuration['additional_nagios_checks'].each |$n,$values| {
        nagios::service::http{
          "${name}-${n}":
            * => $default_nagios_vals + $values,
        }
      }
    }
  }

  $watch_webfiles_ensure = $ensure ? {
    'absent'  => 'absent',
    default   => $watch_adjust_webfiles,
  }
  webhosting::watch_adjust_webfiles{
    $name:
      ensure    => $watch_webfiles_ensure,
      path      => "${vhost_path}/www/",
      sftp_user => $real_uid_name,
      run_user  => $real_run_uid_name,
  }
  if $ensure != 'absent' {
    if $php_installation and $php_installation != 'system' {
      $php_inst = regsubst($php_installation,'^scl','php')
      require "::php::scl::${php_inst}"
      $scl_name = getvar("php::scl::${php_inst}::scl_name")
    } else {
      $scl_name = false
    }
    if $scl_name and !('scl' in $user_scripts_options['global']) {
      $real_user_scripts_options = deep_merge({
          'global' => { 'scl' => $scl_name },
        }, $user_scripts_options)
    } else {
      $real_user_scripts_options = $user_scripts_options
    }
    webhosting::user_scripts::manage{$name:
      base_path => $vhost_path,
      scripts   => $user_scripts,
      sftp_user => $real_uid_name,
      run_user  => $real_run_uid_name,
      web_group => $real_gid_name,
      options   => $real_user_scripts_options,
    }

    if 'mail_ratelimit' in $configuration {
      exim::ratelimit::localforward::entry{
        $real_run_uid_name:
          key       => $real_run_uid,
          ratelimit => $configuration['mail_ratelimit'];
      }
    }
  }
  if ($git_repo != 'absent') and ($ensure != 'absent') {
    webhosting::utils::clone{
      $name:
        git_repo     => $git_repo,
        documentroot => "${vhost_path}/www",
        uid_name     => $uid_name,
        run_uid_name => $real_run_uid_name,
        gid_name     => $gid_name,
        run_mode     => $run_mode,
    }
  }
}
