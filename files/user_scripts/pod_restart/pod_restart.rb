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
    'pod_restart.pods' => {
      :uid => sftp_user_uid,
      :gid => group_gid,
      :reject_mmask => 0007,
    }
  }
end

# verify security related things to that script
def script_security
end

# the main method
def run_script
  log "Starting to restart..."
  ['pods','containers'].each do |w|
    unless items[w].empty?
      log "Starting to restart #{w}"
      items[w].each { |n| stop(w,n) }
    end
  end
  log "Finished restarting..."
  return true
end

## script specific methods

def items
  @config ||= load_items
end

# sanitize that we only get pods & containers
def load_items
  load_file('pod_restart.pods',['pods','containers']).inject({}) do |res,items|
    k,v = items
    res[k] = v.map do |n|
      if n =~ /^[A-Za-z0-9\.\-_]+$/
        n
      else
        log "Name '#{n}' is not a valid name"
        nil
      end
    end.flatten.compact
    res
  end
end

def stop(what, name)
  # chmod runs as sftp user, which should own all the relevant files now
  log "Stopping #{what} '#{name}'"
  sudo(sftp_user_uid,group_gid) do
    cmd("XDG_RUNTIME_DIR=/run/pods/#{sftp_user_uid} podman #{what} stop '#{name}'")
  end
  log "Stopped #{what} '#{name}' - Restart will be triggered soon..."
rescue => e
  log "Error while restarting #{what} '#{name}': #{e.message}"
end

# this will also trigger the run of the script
require "#{File.expand_path(File.join(File.dirname(__FILE__),'..','common','webscripts'))}"
