#!/bin/env ruby

## methods required by commons

# which option entries beside sftp_user does
# this script need?
def script_option_keys
 []
end

# further settings files used by this script
def script_settings_files_def
  {
    'ssh_authorized_keys.keys' => {}
  }
end

# verify security related things to that script
def script_security
end

# the main method
def run_script
  log "Starting managing sshkeys"
  file_path = settings_files['ssh_authorized_keys.keys']
  sudo(sftp_user_uid,group_gid) do
    keys = []
    ignored_keys = []
    IO.foreach(file_path) do |line|
      line.chomp!
      # only allow a certain set of keys
      # and ignore comment lines
      if m = line.match(/^(ssh-rsa|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521|ssh-ed25519) ([A-Za-z0-9=\/\+]+)( )?/)
        keys << "#{m[1]} #{m[2]}"
      elsif line !~ /^#/ && !line.empty?
        ignored_keys << "Ignoring following line as it's not a supported key: #{line}"
      end
    end
    File.open("/var/www/ssh_authorized_keys/#{options['sftp_user']}",'w') do |f|
      f << "# Generated at #{Time.now.to_s}\n"
      f << keys.join("\n")
      f << "\n"
    end
    ignored_keys.each do |k|
      log "Ignored the following keyline as not matching the allowed pattern: #{k}"
    end
    log "Wrote #{keys.size} keys to the authorized_keys file"
  end
  log "Finished managing sshkeys"
  return true
end

# this will also trigger the run of the script
require "#{File.expand_path(File.join(File.dirname(__FILE__),'..','common','webscripts'))}"
