# clone a repository for a webhosting
define webhosting::utils::clone(
  $git_repo,
  $documentroot,
  $uid_name,
  $gid_name,
  $run_uid_name,
  $run_mode,
){
  # create webdir
  # for the cloning, $documentroot needs to be absent
  if $run_mode in ['fpm','fcgid'] {
    $req = [User::Sftp_only[$uid_name], User::Managed[$run_uid_name] ]
  } else {
    $req = User::Sftp_only[$uid_name]
  }
  $default_git_params = {
    projectroot     => $documentroot,
    cloneddir_user  => $uid_name,
    cloneddir_group => $gid_name,
    require         => $req,
  }
  if $git_repo =~ Hash {
    $git_options = $git_repo
  } else {
    $git_options = {
      git_repo        => $git_repo,
    }
  }
  create_resources('git::clone',{ "${name}" => $git_options },$default_git_params)
}
