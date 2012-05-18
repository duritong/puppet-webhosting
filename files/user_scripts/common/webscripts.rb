# common functions for webscripts

require 'fileutils'
require 'yaml'

def usage
  puts "USAGE: #{File.basename(__FILE__)} /path/to/file.run"
  exit 1
end

def options
  @options ||= load_options
end

def settings_files
  @settings_files ||= check_settings_files
end

def script_name
  @script_name ||= File.basename($0,'.rb')
end

def load_file(file, required_keys)
  res = YAML.load_file(settings_files[file]) || {}
  unless required_keys.all? { |k| res.keys.include?(k) }
    security_log "File #{settings_files[file]} does not contain all the required settings: #{required_keys.join(', ')}. Please fix!"
  end
  res
end

def lockfile
  @lockfile ||= File.join(@base_dir,"#{script_name}.lock")
end

def log(str)
  puts "[#{Time.now.strftime('%d.%m.%Y %H:%M:%S')}] (#{$$}) #{str}"
end

def security_log(str)
  log str
  exit 1
end

def load_options
  load_file(options_filename,option_keys)
end

def options_filename
  @options_file ||= "#{script_name}.options"
end

def option_keys
  @option_keys ||= [ 'sftp_user' ] | script_option_keys
end

def check_settings_files
  files = [ "#{script_name}.options" ] | script_settings_files
  files.inject({}) do |res,file|
    file_path = File.expand_path(File.join(@base_dir,file))
    security_log("#{file} does not exist.") unless File.exists?(file_path) 
    res[file] = file_path
    res
  end
end

@run_file = ARGV.shift
usage if @run_file.nil? || !File.exists?(@run_file = File.expand_path(@run_file))

@base_dir = File.dirname(@run_file)

# Verify various security related things
sftp_user_uid = Etc.getpwnam(options['sftp_user']).uid
security_log("The run file is not owned by the sftp user. This is a security violation! Exiting...") unless File.stat(@run_file).uid == sftp_user_uid
security_log("The options file (#{settings_files[options_filename]}) is not owned by myself. This is a security violation! Exiting...") unless File.owned?(settings_files[options_filename])

# test script specific security things
script_security(sftp_user_uid)

if File.exists?(lockfile)
  pid = File.read(lockfile).chomp
  if File.directory?("/proc/#{pid}")
    security_log "Lockfile #{lockfile} exists with pid #{pid} and this process still seems to be running. Exiting..."
  else
    log "Overwrite staled lockfile #{lockfile}. Old pid was #{pid}, but this process seems not to be running anymore."
  end
end
begin
  File.open(lockfile,'w'){|f| f << $$ }
  run_script
ensure
  File.delete(@run_file)
  File.delete(lockfile)
end
