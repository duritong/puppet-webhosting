#!/bin/env ruby

## methods required by commons

# which option entries beside sftp_user does
# this script need?
def script_option_keys
 ['webdir']
end

# further settings files used by this script
def script_settings_files_def                                                             
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
  log ''
  240.times do
    sleep 30
    unless File.exists?(@run_file)
      break
    end
  end
  log "Update mode is over. Resetting permissions."
  reset_update_mode
  log "done."
end

# file name to store the old permissions
@perm_file = "/tmp/#{(0...32).map{65.+(rand(26)).chr}.join}"
def perm_file
  @perm_file
end

## script specific methods

def update_mode
  sudo(sftp_user_uid,group_gid) do
    cmd("getfacl --absolute-names -R #{shellescape(options['webdir'])} > #{perm_file}")
  end
  FileUtils.chmod 0400, "#{perm_file}"

  sudo(sftp_user_uid,group_gid) do
    cmd("chmod -R 'g+rwX' #{shellescape(options['webdir'])} 2>&1")
  end
end

def reset_update_mode
  sudo(sftp_user_uid,group_gid) do
    cmd("setfacl --restore=#{perm_file}")
  end
  File.delete(perm_file)

  # set group write permissions to newly created files, if they are in a 
  # preexisting folder, which has group write permissions:
  # --
  # First collect preexisting directories with group write access
  dirs = cmd("find #{shellescape(options['webdir'])} -user #{options['sftp_user']} -type d -perm /g+w")
  on_filelist(dirs,sftp_user_uid) do |path|
    # collect any newly created file or folder within and make 
    # them writeable by the group
    dirs = cmd("find #{shellescape(path)} -user #{options['run_user']} -type d")
    files = cmd("find #{shellescape(path)} -user #{options['run_user']} -type f")
    on_filelist(dirs,run_user_uid) do |path|
      FileUtils.chmod(0770,path)
    end
    on_filelist(files,run_user_uid) do |path|
      FileUtils.chmod(0660,path)
    end
  end

  #chown newly created files
  chown_R(run_user_uid,options['sftp_user'])
end

def chown_R(from_uid,to)
  from_uid.is_a?(Integer) && to.is_a?(String) or fail
  files =  cmd("find #{shellescape(options['webdir'])} -user #{from_uid} -type d")
  files << cmd("find #{shellescape(options['webdir'])} -user #{from_uid} -type f")
  on_filelist(files,from_uid) do |path|
    FileUtils.chown( to, options['group'], path )
  end
end

require "#{File.expand_path(File.join(File.dirname(__FILE__),'..','common','webscripts'))}"
