# Manages common things amongst webhostings
# user_access:
#   - sftp: an sftp only user will be created (*default*)
# wwwmail:
#   This will include the web run user in a group called wwwmailers.
#   This makes it easier to enable special rights on a webserver's mailserver to
#   this group.
#   - default: false
define webhosting::common (
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
  Variant[Enum['absent'], Array[String[1]]] $user_scripts = 'absent',
  $user_scripts_options  = {},
  $nagios_check          = 'ensure',
  Optional[Variant[String,Array[String]]] $nagios_check_domain = undef,
  $nagios_check_url      = '/',
  $nagios_check_code     = '200',
  $nagios_use            = 'generic-service',
  $git_repo              = 'absent',
  $php_installation      = false,
) {
  if $run_gid == 'absent' {
    if ($gid == 'uid') {
      $real_run_gid = $uid
    } else {
      $real_run_gid = $gid
    }
  } else {
    $real_run_gid = $run_gid
  }
  if $uid_name == 'absent' {
    $real_uid_name = $name
  } else {
    $real_uid_name = $uid_name
  }
  if $gid_name == 'absent' {
    $real_gid_name = $real_uid_name
  } else {
    $real_gid_name = $gid_name
  }
  if $run_uid_name == 'absent' {
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
        $vhost_tmp_dir = "${vhost_path}/tmp"
        if !defined(File[$vhost_tmp_dir]) {
          file {
            $vhost_tmp_dir:
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
        file {
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
          "${vhost_tmp_dir}/run":
            ensure  => directory,
            owner   => $real_uid_name,
            group   => $real_gid_name,
            mode    => '0777',
            seltype => 'httpd_var_run_t';
        } -> Podman::Container<| tag == "user_${real_uid_name}" |>
        # we don't know the users subuid/subgid
        # Must be set if we might want to do keep-user-id
        # https://lists.podman.io/archives/list/podman@lists.podman.io/thread/LA2J5LY6SZMNMPLDGE4DKIV2CFLGPOXC/
        exec { "adjust_path_access_for_keep-user-id_${vhost_path}":
          command => "bash -c \"setfacl -m user:$(grep -E '^${real_uid_name}:' /etc/subuid | cut -d: -f 2):rx ${vhost_path}\"",
          unless  => "getfacl -p -n ${vhost_path}  | grep -qE \"^user:$(grep -E '^${real_uid_name}:' /etc/subuid | cut -d: -f 2 | head -n 1):r-x\\$\"",
          require => [File[$vhost_path],User[$real_uid_name]];
        } -> Podman::Container<| tag == "user_${real_uid_name}" |>

        $container_config_directory = "/var/www/vhosts/${name}/private/container-config"
        file {
          $container_config_directory:
            ensure => directory,
            owner  => $real_uid_name,
            group  => $real_gid_name,
        }
      }

      # we can't yet use keep-id on EL7 as we need cgroupv2 for
      # that
      if versioncmp($facts['os']['release']['major'],'8') < 0 {
        $default_user_run_flags = {
          'user'                    => '1000:0',
        }
      } else {
        $default_user_run_flags = {
          'userns'                  => 'keep-id',
          'user'                    => '1000:GID',
        }
      }
      $default_run_flags = $default_user_run_flags + {
        'security-opt-label-type' => 'httpd_container_rw_content',
        'read-only'               => true,
      }

      $configuration['containers'].each |$con_name,$vals| {
        $hosting_run_flags = pick($vals['run_flags'],{})
        $route = pick($vals['route'],{})
        $publish_socket = pick($vals['publish_socket'],{})
        $publish_options = {
          'dir'                     => "/var/www/vhosts/${name}/tmp/run",
          'security-opt-label-type' => 'socat_httpd_sidecar',
        }
        $publis_socket_2 = Hash($route.map |$e| {
          if $e[1] =~ Hash {
            $port = $e[1]['port']
          } elsif $e[1] =~ Stdlib::Port {
            $port = $e[1]
          } else {
            $port = Integer($e[1].split(/\//)[0])
          }
          [$port, $publish_options]
        })

        $con_config = { 'config_directory' => $container_config_directory } + pick($vals['configuration'], {})
        $pod_system_config = {
          'volumes_containers_gid_share' => true,
          'tmp_dir'                      => $vhost_tmp_dir,
        } + pick($vals['pod_system_config'], {})
        if $ensure == 'present' {
          $auth = pick($vals['auth'],{})
          podman::container::auth {
            "user-${name}-${con_name}":
              auth     => $auth,
              path     => "${container_config_directory}/auth-${con_name}-registry.yaml",
              replace  => false,
              user     => $real_uid_name,
              group    => $real_gid_name,
              owner    => $real_uid_name,
              con_name => "${name}-${con_name}",
              mode     => '0600',
              order    => '040',
          }
        }

        $con_values = $vals + {
          ensure            => $ensure,
          user              => $real_uid_name,
          uid               => $real_uid,
          container_name    => $con_name,
          gid               => $gid,
          homedir           => $vhost_path,
          manage_user       => false,
          logpath           => "${vhost_path}/logs",
          run_flags         => $default_run_flags + $hosting_run_flags,
          tag               => "user_${real_uid_name}",
          publish_socket    => $publis_socket_2 + $publish_socket,
          pod_system_config => $pod_system_config,
          configuration     => $con_config,
        }
        podman::container {
          "${name}-${con_name}":
            * => $con_values - ['route'],
        }
      }
    }

    if $user_access == 'sftp' {
      $real_password = $password ? {
        'trocla' => trocla("webhosting_${real_uid_name}",'sha512crypt'),
        default  => $password
      }
      user::sftp_only { $real_uid_name:
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
    if $user_access == 'sftp' {
      if $ensure != 'absent' {
        User::Sftp_only[$real_uid_name] {
          homedir_mode => '0750',
        }
      }
      user::groups::manage_user {
        "apache_in_${real_gid_name}":
          ensure => $ensure,
          group  => $real_gid_name,
          user   => 'apache',
          notify => Service['apache'],
      }
      if $ensure == 'present' {
        User::Groups::Manage_user["apache_in_${real_gid_name}"] {
          require => User::Sftp_only[$real_uid_name],
        }
      }
    }
  }
  if $run_mode in ['fpm','fcgid'] {
    if ($run_uid=='absent') and ($ensure != 'absent') {
      fail("you need to define run_uid for ${name} on ${facts['networking']['fqdn']} to use fpm or fcgid")
    }
    $real_run_uid = $run_uid ? {
      'iuid'  => iuid($real_run_uid_name,'webhosting'),
      default => $run_uid,
    }
    user::managed { $real_run_uid_name:
      ensure       => $ensure,
      manage_group => false,
      managehome   => false,
      homedir      => $vhost_path,
      uid          => $real_run_uid,
      shell        => '/sbin/nologin',
    }
    if $user_access == 'sftp' {
      if $ensure == 'absent' {
        User::Managed[$real_run_uid_name] {
          before => User::Sftp_only[$real_uid_name],
        }
      } else {
        User::Managed[$real_run_uid_name] {
          require => User::Sftp_only[$real_uid_name],
        }
      }
    }

    if $wwwmail {
      user::groups::manage_user {
        "${real_run_uid_name}_in_wwwmailers":
          ensure => $ensure,
          group  => 'wwwmailers',
          user   => $real_run_uid_name,
      }
      if $ensure == 'present' {
        require webhosting::wwwmailers
        User::Groups::Manage_user["${real_run_uid_name}_in_wwwmailers"] {
          require => User::Managed[$real_run_uid_name],
        }
      }
    }
    if $ensure == 'present' {
      $rreal_run_gid = $real_run_gid ? {
        'iuid'  => iuid($real_uid_name,'webhosting'),
        default => $real_run_gid,
      }
      User::Managed[$real_run_uid_name] {
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
    nagios::service::http {
      $name:
        * => $default_nagios_vals,
    }
    if 'additional_nagios_checks' in $configuration {
      $configuration['additional_nagios_checks'].each |$n,$values| {
        nagios::service::http {
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
  webhosting::watch_adjust_webfiles {
    $name:
      ensure    => $watch_webfiles_ensure,
      path      => "${vhost_path}/www/",
      sftp_user => $real_uid_name,
      run_user  => $real_run_uid_name,
  }

  logrotate::rule { "cron-${name}": }
  $cron_jobs = assert_type(Webhosting::Cronjobs,pick($configuration['cron_jobs'],{}))
  if !empty($cron_jobs) {
    Logrotate::Rule["cron-${name}"]{
      ensure       => $ensure,
      path         => "${vhost_path}/logs/${name}-cron-*.log",
      compress     => true,
      copytruncate => true,
      dateext      => true,
      create       => true,
      create_mode  => '0640',
      create_owner => 'root',
      create_group => $gid_name,
      su           => true,
      su_user      => 'root',
      su_group     => $gid_name,
    }
  } else {
    Logrotate::Rule["cron-${name}"]{
      ensure => 'absent',
    }
  }
  # actual content parsing comes more below
  $cron_jobs.each |$cron_name,$cron_vals| {
    if $ensure == 'absent' {
      $_ensure = 'absent'
    } else {
      $_ensure = pick($cron_vals['ensure'],$ensure)
    }
    systemd::timer {
      "webhosting-${name}-${cron_name}.timer":
        ensure => $_ensure,
    }
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
      $real_user_scripts_options = deep_merge( {
          'global' => { 'scl' => $scl_name },
      }, $user_scripts_options)
    } else {
      $real_user_scripts_options = $user_scripts_options
    }

    if 'containers' in $configuration and $user_scripts != 'absent' {
      $_user_scripts = unique($user_scripts + $webhosting::user_scripts::container_scripts)
      $pods = $configuration['containers'].keys.map |$con_name| {
        $vals = $configuration['containers'][$con_name]
        if 'deployment_mode' in $vals and $vals['deployment_mode'] =~ /pod$/ {
          $con_name
        } elsif 'publish_socket' in $vals and !empty($vals['publish_socket']) {
          "pod-${con_name}"
        } else {
          undef
        }
      }.filter |$val| { $val =~ NotUndef }
      $containers = $configuration['containers'].keys.map |$con_name| {
        $vals = $configuration['containers'][$con_name]
        if 'deployment_mode' in $vals and $vals['deployment_mode'] !~ /pod$/ {
          $con_name
        } elsif !('deployment_mode' in $vals) and (!('publish_socket' in $vals) or empty($vals['publish_socket'])) {
          $con_name
        } else {
          undef
        }
      }.filter |$val| { $val =~ NotUndef }
      $_real_user_scripts_options = $real_user_scripts_options + {
        pod_restart => {
          pods       => $pods,
          containers => $containers,
        } + pick($real_user_scripts_options[pod_restart],{}),
      }
    } else {
      $_user_scripts = $user_scripts
      $_real_user_scripts_options = $real_user_scripts_options
    }
    webhosting::user_scripts::manage { $name:
      base_path => $vhost_path,
      scripts   => $_user_scripts,
      sftp_user => $real_uid_name,
      run_user  => $real_run_uid_name,
      web_group => $real_gid_name,
      options   => $_real_user_scripts_options,
    }

    if 'mail_ratelimit' in $configuration {
      exim::ratelimit::localforward::entry {
        $real_run_uid_name:
          key       => $real_run_uid,
          ratelimit => $configuration['mail_ratelimit'];
      }
    }
    if !empty($cron_jobs) {
      require systemd::mail_on_failure
    }
    $cron_jobs.each |$cron_name,$cron_vals| {
      $timer_params = $webhosting::cron_timer_defaults.merge($cron_vals.filter |$i| { $i[0] in ['on_calendar', 'randomize_delay_sec'] })
      $service_params = {
        cron_name => $cron_name,
        name      => $name,
        user      => $uid_name,
        group     => $gid_name,
      }.merge($cron_vals.filter |$i| { $i[0] in ['cmd','read_write_directories'] })
      Systemd::Timer["webhosting-${name}-${cron_name}.timer"] {
        timer_content   => epp('webhosting/cron/cron.timer.epp', $timer_params),
        service_content => epp('webhosting/cron/cron.service.epp', $service_params),
        active          => true,
        enable          => true,
      }
      rsyslog::confd {
        "${name}-cron-${cron_name}":
          ensure  => $ensure,
          content => epp('podman/rsyslog-confd.epp',{
            programname  => "webhosting-${name}-${cron_name}",
            service_name => "webhosting-${name}-${cron_name}",
            logpath      => "${vhost_path}/logs",
            logfile_name => "${name}-cron-${cron_name}",
            group        => $gid_name,
          }),
      } -> file {
        # manage file to workaround
        # https://access.redhat.com/solutions/3967061
        # logrotate is handled by the general wildcard
        "${vhost_path}/logs/${name}-cron-${cron_name}.log":
          ensure => file,
          mode   => '0640',
          owner  => 'root',
          group  => $gid_name,
      }
    }
  }
  if ($git_repo != 'absent') and ($ensure != 'absent') {
    webhosting::utils::clone {
      $name:
        git_repo     => $git_repo,
        documentroot => "${vhost_path}/www",
        uid_name     => $uid_name,
        run_uid_name => $real_run_uid_name,
        gid_name     => $gid_name,
        run_mode     => $run_mode,
    }
  }
  if ($ensure != 'absent') and ('user_files' in $configuration) {
    $user_files = assert_type(Webhosting::Userfiles,$configuration['user_files'])
    $user_files_defaults = {
      owner                   => $uid_name,
      group                   => $gid_name,
      mode                    => '0640',
    }
    $user_files.each |$k,$v| {
      if $k =~ Stdlib::Unixpath {
        $_k = $k
      } else {
        $_k = "${vhost_path}/${k}"
      }
      if 'content' in $v {
        if $v['content'] =~ /\AERB:/ {
          $tmp_content = template($v['content'].regsubst(/\AERB:/,''))
          if $tmp_content =~ /%%TROCLA_/ {
            $_content = trocla::gsub($tmp_content, { prefix => "webhosting_${name}_", })
          } else {
            $_content = $tmp_content
          }
          $_v = $v.merge( { content => Sensitive($_content) })
        } elsif $v['content'] =~ /%%TROCLA_/ {
          $_v = $v.merge( { content => Sensitive(trocla::gsub($v['content'], { prefix => "webhosting_${name}_", })) })
        } else {
          $_v = $v
        }
      } else {
        $_v = $v
      }
      file {
        $_k:
          * => $user_files_defaults + $_v,
      }
    }
  }
  if ($ensure != 'absent') and ('puppet_classes' in $configuration) and !($configuration['puppet_classes'].empty) {
    include $configuration['puppet_classes']
  }

  if 'additional_firewall_rules' in $configuration {
    $default_fw_rules = {
      source      => '$FW',
      destination => 'net',
      proto       => 'tcp',
      order       => 240,
      action      => 'ACCEPT',
      shorewall6  => false,
    }

    $configuration['additional_firewall_rules'].each |$n,$rule| {
      shorewall::rule{
        "${name}-${n}":
          * => $default_fw_rules + $rule;
      }
    }
  }

  if (versioncmp($facts['os']['release']['major'],'8') > 0) and ('mysql_dbs' in $configuration) {
    $configuration['mysql_dbs'].each |$db,$options| {
      assert_type(String[1,64], $db)
      $db_ensure  = $ensure ? {
        'absent' => 'absent',
        default  => pick($options['ensure'],$ensure),
      }
      mysql_database { $db:
        ensure  => $db_ensure,
        charset => pick($options['charset'],'utf8'),
        collate => pick($options['collate'],'utf8_general_ci'),
        require => File['/root/.my.cnf'],
      }
      $db_username = pick($options['username'],$db)
      assert_type(String[1,80],$db_username)
      mysql_user{"${db_username}@127.0.0.1":
        ensure        => $db_ensure,
        password_hash => trocla("mysql_${db_username}",'mysql'),
        require       => Mysql_database[$db],
      }
      if $db_ensure == 'present' {
        mysql_grant{"${db_username}@127.0.0.1/${db}.*":
          user       => "${db_username}@127.0.0.1",
          table      => "${db}.*",
          privileges => pick($options['privileges'],'all'),
          require    => Mysql_user["${db_username}@127.0.0.1"],
        }
      }
    }
  }

  if (versioncmp($facts['os']['release']['major'],'8') > 0) {
    $pma_path = "${vhost_path}/data/pma"
    $pma_config_path = "${vhost_path}/etc/pma"
    phpmyadmin::instance {
      $name:
        config_dir => $pma_config_path,
        base_dir   => $pma_path,
        dbs        => $configuration['mysql_dbs'],
        run_user   => $real_run_uid_name,
        group      => $gid_name,
    }
    php::fpm {
      "${name}-pma":
        php_inst_class  => undef,
        workdir         => $pma_path,
        logdir          => "${vhost_path}/logs",
        logfile_name    => "pma-fpm-error.log",
        tmpdir          => "${pma_path}/tmp",
        run_user        => $real_run_uid_name,
        run_group       => $gid_name,
        additional_envs => { "PHPMYADMIN_CONFIG" => "${pma_config_path}/config.php" },
        php_settings    => {
          engine                => 'On',
          'upload_max_filesize' => '80M',
          'post_max_size'       => '90M',
          upload_tmp_dir        => "${pma_path}/php_uploads",
          'session.save_path'   => "${pma_path}/php_sessions",
          error_log             => "${vhost_path}/logs/pma-php_error_log",
          open_basedir          => "/usr/share/phpMyAdmin/:/usr/share/doc/phpMyAdmin/html/:/var/lib/phpMyAdmin/:${pma_config_path}:${pma_path}/:/etc/phpMyAdmin/:/etc/pki/tls/certs/ca-bundle.crt"
        },
    } -> logrotate::rule { "pma-${name}": }
    if ('mysql_dbs' in $configuration) and ($configuration['activate_pma'] == true) {
      Phpmyadmin::Instance[$name] {
        ensure => $ensure,
      }
      Php::Fpm["${name}-pma"] {
        ensure => $ensure,
      }
      Logrotate::Rule["pma-${name}"]{
        ensure       => $ensure,
        path         => "${vhost_path}/logs/pma-php_error_log",
        compress     => true,
        copytruncate => true,
        dateext      => true,
        create       => true,
        create_mode  => '0640',
        create_owner => $real_run_uid_name,
        create_group => $gid_name,
        su           => true,
        su_user      => $real_run_uid_name,
        su_group     => $gid_name,
      }
    } else {
      Phpmyadmin::Instance[$name] {
        ensure   => 'absent',
      }
      Php::Fpm["${name}-pma"] {
        ensure   => 'absent',
      }
      Logrotate::Rule["pma-${name}"]{
        ensure => 'absent',
      }
    }
  }
}
