#!/bin/env ruby

require 'yaml'
require 'fileutils'
require 'etc'
require 'socket'

def log(str)
  puts "[#{Time.now.strftime('%d.%m.%Y %H:%M:%S')}] (#{$$}) #{str}"
end

def error_log(str)
  STDERR.puts "[#{Time.now.strftime('%d.%m.%Y %H:%M:%S')}] (#{$$}) ERROR: #{str}"
end

def security_fail(str)
  log str
  exit 1
end

def sudo(uid,gid,&blk)
  # fork off shell command to irrevocably drop all root privileges
  pid = fork do
    Process::Sys.setregid(gid,gid)
    security_fail('could not drop privileges') unless Process::Sys.getgid == gid
    security_fail('could not drop privileges') unless Process::Sys.getegid == gid
    Process::Sys.setreuid(uid,uid)
    security_fail('could not drop privileges') unless Process::Sys.getuid == uid
    security_fail('could not drop privileges') unless Process::Sys.geteuid == uid
    yield blk
  end
  Process.wait pid
end

def inform_about_error(sender, receiver, hosting, exit_code, log_msg, uid, gid)
  sudo(uid, gid) do
    text = <<EOF
Hi admins of #{hosting}

We tried to automatically update your wordpress instance. Unfortunately it failed.

Sorry for the inconvenience, but this requires *your* attention.

You might wanna have a look at your hosting and fix any present issues.
A backup of your wordpess is available in your private/ folder of your hosting.

If you are unable to fix the issue yourself or have any questions, please contact your admins.

Best regards

your friendly (but failing) wordpress updating automation

Technical details of the failure:
Exitcode: #{exit_code}

#{log_msg}
EOF
    require 'mail'
    mail = Mail.new do
      from     sender
      to       receiver
      subject  "Hosting #{hosting} - Automatic Wordpress Update failed"
      body     text
    end
    mail.delivery_method :sendmail
    mail.deliver
  end
end

sender = ARGV.shift || "root@#{Socket.gethostname}"
Dir['/var/www/vhosts/*/scripts/update_wordpress/update_wordpress.dirs'].each do |f|
  vhost_options = YAML.load_file(f)
  dir = File.dirname(f)
  log_dir = File.expand_path(File.join(File.dirname(f),'../../logs'))
  hosting = File.basename(File.dirname(File.dirname(dir)))
  if vhost_options['auto_update']
    vhost_options = YAML.load_file(File.join(File.dirname(dir),'vhost.options'))
    log "Running wordpress auto_update for #{hosting}"
    if File.file?(File.join(dir,'update_wordpress.lock'))
      error_log "update_wordpress.lock already exists for #{hosting} skipping"
    else
      run_file = File.join(dir,'update_wordpress.auto_run')
      uid = Etc.getpwnam(vhost_options['sftp_user']).uid
      gid = Etc.getgrnam(vhost_options['group']).gid
      FileUtils.touch run_file
      File.chown(uid,gid,run_file)
      result = `/opt/webhosting_user_scripts/update_wordpress/update_wordpress.rb #{run_file} 2>&1`
      exit_code = $?.to_i
      File.open(File.join(log_dir,'users-script-update_wordpress.log'),'a'){|f| f << result }
      if exit_code > 0
        error_log "Error while running update for #{hosting} - Exitcode: #{exit_code} - #{result}"
        inform_about_error(sender, vhost_options['hosting_contact'], hosting, exit_code, result, uid, gid)
      end
    end
  else
    log "NO wordpress auto_update for #{hosting}"
  end
end
