#!/bin/env ruby

## methods required by commons

# which option entries beside sftp_user does
# this script need?
def script_option_keys
 ['group','webdir']
end

# further settings files used by this script
def script_settings_files
  [ 'adjust_permissions.dirs' ]
end

# verify security related things to that script
def script_security(sftp_user_uid)
  unless File.stat(settings_files['adjust_permissions.dirs']).uid == sftp_user_uid
    security_log("The file containing the directories to adjust (#{files['adjust_permissions.dirs']}) is not owned by the sftp user. This is a security violation! Exiting...") 
  end
  security_log("Webdir #{options['webdir']} does not exist. Please fix!") unless File.directory?(options['webdir'])
end

# the main method
def run_script
  log "Starting to adjust permissions"
  directories['only_webreadable'].each { |path| adjust(path, 'u+rw,g-w,o-rwx') }
  directories['web_writable'].each { |path| adjust(path, 'u+rw,g+w,o-rwx') }
  log "Finished adjusting permissions"
end

## script specific methods

def directories
  @directories ||= load_directories
end

# sanitize that we only get directories
# within the webdirectory. So no one
# can do anything dirty.
def load_directories
  load_file('adjust_permissions.dirs',['web_writable','only_webreadable']).inject({}) do |res,items|
    k,v = items
    res[k] = v.collect do |item|
      path = File.expand_path(File.join(options['webdir'],item))
     if !File.exists?(path)
        log "#{path} does not exist. Skipping..."
     elsif path =~ /^#{Regexp.escape(options['webdir'])}/
        path
     else
        log "#{path} is outside the webdir #{options['webdir']}, so we're dropping it"
       nil
     end
    end.flatten.compact
    res
  end
end

def chmod_R(path, permissions)
  cmd("chmod -R #{permissions} #{shellescape(path)} 2>&1")
end

def chown_R(user,group,path)
  cmd("chown -R --no-dereference #{user}:#{group} #{shellescape(path)} 2>&1")
end

def adjust(path, permissions)
  chmod_R(path, permissions)
  chown_R(options['sftp_user'], options['group'], path)
  log "Adjusted #{path} with #{permissions} and #{options['sftp_user']}:#{options['group']}"
rescue => e
  log "Error while adjusting path #{path}: #{e.message}"
end

# this will also trigger the run of the script
require "#{File.expand_path(File.join(File.dirname(__FILE__),'..','common','webscripts'))}"
