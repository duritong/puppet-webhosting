#!/bin/env ruby

## methods required by commons

# which option entries beside sftp_user does
# this script need?
def script_option_keys
 ['webdir']
end

# further settings files used by this script
def script_settings_files                                                              
end

# verify security related things to that script
def script_security
  security_fail("Webdir #{options['webdir']} does not exist. Please fix!") unless File.directory?(options['webdir'])
end

# the main method
def run_script
  log "Set hosting to update mode"
  update_mode
  log "Hosting is now in update mode, you can proceed with your modifications."
  sleep 3600
  log "Update time is over. Resetting permissions."
  reset_update_mode
  log "done."
end

def perm_file
  @perm_file ||= "#{Process.pid}_#{(0...32).map{65.+(rand(26)).chr}.join}"
end

## script specific methods

def update_mode
  cmd("getfacl --absolute-names -R #{shellescape(options['webdir'])} > #{perm_file}")
  cmd("chmod -rw #{perm_file}")
  cmd("chown -R #{options['run_user']} #{shellescape(options['webdir'])}")
end

def reset_update_mode
  File.read(perm_file).each_line do |line|
    if line.start_with? '# file:' && ! line.start_with? "# file: #{options['webdir']}"
      cmd("chown -R #{options['sftp_user']} #{shellescape(options['webdir'])}")
      security_fail "Cannot correctly restore permissions, since permissions file is corrupt"
    end
  end

  cmd("setfacl --restore=#{perm_file}")
  cmd("find #{shellescape(options['webdir'])} -user #{options['sftp_user']} -type d -perm /g+w | while read dir; do" +
         "find \"$dir\" -user #{options['run_user']} -exec chmod g+Xw,o-rwx {} \;" +
       "done")
  cmd("chown -R #{options['sftp_user']} #{shellescape(options['webdir'])}")
  File.remove(perm_file)
end

require "#{File.expand_path(File.join(File.dirname(__FILE__),'..','common','webscripts'))}"
