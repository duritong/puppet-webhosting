#!/bin/env ruby

## methods required by commons

# which option entries beside sftp_user does
# this script need?
def script_option_keys
 ['webdir']
end

# further settings files used by this script
def script_settings_files_def
  {
    'update_wordpress.dirs' => {
      'wp_directories' => ['.']
    }
  }
end

# verify security related things to that script
def script_security
  security_fail("Webdir #{options['webdir']} does not exist. Please fix!") unless File.directory?(options['webdir'])
end

# the main method
def run_script
  log "Starting wordpress upgrade"
  wp_directories.each do |wd|
    upgrade_wordpress(wd)
  end
  log "Finished wordpress upgrade"
end

## script specific methods

def wp_directories
  @wp_directories ||= load_directories
end

def file_ist
  @file_list ||= "/tmp/#{Process.pid}_#{(0...32).map{65.+(rand(26)).chr}.join('')}"
end


# sanitize that we only get directories
# within the webdirectory. So no one
# can do anything dirty.
def load_directories
  fd = load_file('update_wordpress.dirs',['wp_directories'])['wp_directories']
  Array(fd).collect do |d|
    path = File.expand_path(File.join(options['webdir'],d))
    if !File.exists?(path) || !File.directory?(path)
      log "#{path} is not a directory or doesn't exist. Skipping..."
      nil
    elsif path.start_with?("#{options['webdir']}")
      path
    else
      log "#{path} is outside the webdir #{options['webdir']}, so we're dropping it"
      nil
    end
  end.flatten.compact
end

def upgrade_wordpress(wd)
  # chowns all run user files to the sftp user
  # to ensure that we can run the upgrade
  log "Starting to upgrade wordpress in #{wd}"
  sudo(run_user_uid,group_gid) do
    cmd("find #{shellescape(path)} -user #{options['run_user']} -type d > #{file_list}")
    cmd("find #{shellescape(path)} -user #{options['run_user']} -type f >> #{file_list}")
  end
  on_filelist(File.read(file_list),run_user_uid) do |p|
    FileUtils.chown( options['sftp_user'], options['group'], p)
  end
  File.delete(file_list)

  # run the upgrade as sftp user
  log "Running the upgrade script in #{wd}"
  sudo(sftp_user_uid,group_gid) do
    cmd("/usr/local/bin/upgrade_wordpress #{shellescape(wd)}")
  end
  log "Upgrading Wordpress in #{wd} finished."
rescue => e
  log "Error while upgrading wordpress in #{wd}: #{e.message}"
end

# this will also trigger the run of the script
require "#{File.expand_path(File.join(File.dirname(__FILE__),'..','common','webscripts'))}"
