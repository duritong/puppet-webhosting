#!/bin/env ruby

require 'etc'

## methods required by commons

# which option entries beside sftp_user does
# this script need?
def script_option_keys
 ['webdir']
end

# further settings files used by this script
def script_settings_files_def
  {
    'adjust_permissions.dirs' => {
      :uid => sftp_user_uid,
      :gid => group_gid,
      :reject_mmask => 0007 }
  }
end

# verify security related things to that script
def script_security
  security_fail("Webdir #{options['webdir']} does not exist. Please fix!") unless File.directory?(options['webdir'])
end

# the main method
def run_script
  log "Starting to adjust permissions"
  directories['only_webreadable'].each { |path| adjust(path, 'u+rwX,g-w,o-rwx' ) }
  directories['web_writable'].each { |path| adjust(path, 'u+rwX,g+rwX,o-rwx' ) }
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
      if !File.exists?(path) || !File.directory?(path)
        log "#{path} is not a directory or doesn't exist. Skipping..."
        nil
      elsif path.start_with? "#{options['webdir']}"
        path
      else
        log "#{path} is outside the webdir #{options['webdir']}, so we're dropping it"
        nil
      end
    end.flatten.compact
    res
  end
end

# file name to pass the list of files to chown from the unprivileged find process to the mother process
def file_list
  @file_list ||= "/tmp/#{Process.pid}_#{(0...32).map{65.+(rand(26)).chr}.join('')}"
end

def adjust(path, permissions)

  # chowns all run user files to the sftp user
  sudo(run_user_uid,group_gid) do
    cmd("find #{shellescape(path)} -user #{options['run_user']} -type d > #{file_list}")
    cmd("find #{shellescape(path)} -user #{options['run_user']} -type f >> #{file_list}")
  end
  on_filelist(File.read(file_list),run_user_uid) do |p|
    FileUtils.chown( options['sftp_user'], options['group'], p)
  end
  File.delete(file_list)

  # chmod runs as sftp user, which should own all the relevant files now
  sudo(sftp_user_uid,group_gid) do
    cmd("chmod -R #{permissions} #{shellescape(path)}")
  end
  log "Adjusted #{path} with #{permissions} and #{options['sftp_user']}:#{options['group']}"
rescue => e
  log "Error while adjusting path #{path}: #{e.message}"
end

# this will also trigger the run of the script
require "#{File.expand_path(File.join(File.dirname(__FILE__),'..','common','webscripts'))}"
