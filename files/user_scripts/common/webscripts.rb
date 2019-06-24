# common functions for webscripts

require 'fileutils'
require 'yaml'
require 'tempfile'

STDOUT.sync = true
STDERR.sync = true

def usage
  puts "USAGE: #{File.basename(__FILE__)} /path/to/file.run"
  exit 1
end

# maps filenames to validated paths
def settings_files
  @settings_files || settings_files_map_and_check!
end

def settings_files_map_and_check!
  @settings_files = _settings_files_map_and_check(settings_files_def)
  @settings_files.merge!(_settings_files_map_and_check(script_settings_files_def))
end

def _settings_files_map_and_check(files)
  return {} unless files
  res = {}
  files.each do |file, options|
    file_path = File.expand_path(File.join(@base_dir,file))
    stat = File.stat(file_path)
    security_fail("#{file} does not exist.") unless File.exists?(file_path)
    security_fail("#{file} has insecure permissions. Expected uid to be #{options[:uid]}") unless options[:uid].nil? || stat.uid == options[:uid]
    security_fail("#{file} has insecure permissions. Expected gid to be #{options[:gid]}") unless options[:gid].nil? || stat.gid == options[:gid]
    security_fail("#{file} has insecure permissions. Mode should not apply to mask #{options[:reject_mmask]}") unless options[:reject_mmask].nil? || (stat.mode & options[:reject_mmask] == 0)
    res[file] = file_path
  end
  res
end

def settings_files_def
  {
    options_filename => {
      :uid => 0,
      :reject_mmask => 0027 }
  }
end

def options
  @options ||= load_options
end

def script_name
  @script_name ||= File.basename($0,'.rb')
end

def stringify(object)
  case object
  when Hash
    Hash[ object.collect {|k,v| [k.to_s, stringify(v)] } ]
  when Array
    object.collect {|v| stringify(v) }
  else
    object.to_s
  end
end

# gives you the parsed content of
# a file, but only if all required keys
# are in.
def load_file(file, required_keys)
  file_path = settings_files[file]
  res = YAML.load_file(file_path) || {}
  unless required_keys.all? { |k| res.keys.include?(k) }
    security_fail "File #{settings_files[file]} does not contain all the required settings: #{required_keys.join(', ')}. Please fix!"
  end
  # stringify keys and values for security reasons
  stringify(res)
end

def lockfile
  @lockfile ||= File.join(@base_dir,"#{script_name}.lock")
end

def log(str)
  puts "[#{Time.now.strftime('%d.%m.%Y %H:%M:%S')}] (#{$$}) #{str}"
end

def security_fail(str)
  log str
  exit 1
end

def load_options
  load_file(options_filename,option_keys)
end

def options_filename
  "../vhost.options"
end

def option_keys
  @option_keys ||= [ 'sftp_user', 'run_user', 'group' ] | script_option_keys
end

def sftp_user_uid
  @stp_user_uid ||= Etc.getpwnam(options['sftp_user']).uid
end

def run_user_uid
  @run_user_uid ||= Etc.getpwnam(options['run_user']).uid
end

def group_gid
  @group_gid ||= Etc.getgrnam(options['group']).gid
end

def cmd(str, abort_on_error = true)
  result = `#{str} 2>&1`
  exit_code = $?.to_i
  if exit_code > 0
    msg = "Error occured: Cmd: #{str} - Exitcode: #{exit_code} - #{result}"
    log msg
    raise msg if abort_on_error
  end
  result
end

def shellescape(str)
  # An empty argument will be skipped, so return empty quotes.
  return "''" if str.empty?

  str = str.dup

  # Process as a single byte sequence because not all shell
  # implementations are multibyte aware.
  str.gsub!(/([^A-Za-z0-9_\-.,:\/@\n])/n, "\\\\\\1")

  # A LF cannot be escaped with a backslash because a backslash + LF
  # combo is regarded as line continuation and simply ignored.
  str.gsub!(/\n/, "'\n'")

  return str
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
  pid, status = Process.wait2(pid)
  return status
end

def on_filelist(list,owner)
  list.each_line do |path|
    path = File.expand_path(path.chomp)
    if path.start_with? "#{options['webdir']}"
      if (File.directory?(path)||File.file?(path))
        if File.stat(path).uid == owner
          yield path
        else
          log "#{path} does not belong to #{run_user_uid}"
        end
      else
        log "#{path} does not exist or is not a directory nor a file"
      end
    else
      log "#{path} is not in the webdir"
    end
  end
end

def with_tempfile(&blk)
  tf = Tempfile.new("#{Process.pid}_")
  tf.close
  yield tf.path
ensure
  tf.unlink
end

success = true
begin
  @run_file = ARGV.shift
  usage if @run_file.nil? || !File.exists?(@run_file = File.expand_path(@run_file))

  @base_dir = File.dirname(@run_file)

  # Verify various security related things
  security_fail("The run file is not owned by the sftp user. This is a security violation! Exiting...") unless File.stat(@run_file).uid == sftp_user_uid

  # test script specific security things
  script_security

  Dir[File.join(@base_dir,'..','*/*.lock')].each do |el|
    existing_lockfile = File.expand_path(el)
    if File.exists?(existing_lockfile)
      pid = File.read(existing_lockfile).chomp.to_i
      script_name = File.basename(existing_lockfile, '.lock')
      if File.directory?("/proc/#{pid}")
        security_fail "Lockfile for #{script_name} exists with pid #{pid} and this process still seems to be running. Exiting..."
      else
        log "Removing staled lockfile for #{script_name}. Old pid was #{pid}, but this process seems not to be running anymore."
        File.unlink(existing_lockfile)
      end
    end
  end

  File.open(lockfile,'w'){|f| f << $$ }
  success = run_script
rescue => e
  log "Error while running script: #{e.message}"
  success = false
ensure
  File.delete(@run_file) if File.exists?(@run_file)
  File.delete(lockfile)
end

exit success ? 0 : 1
