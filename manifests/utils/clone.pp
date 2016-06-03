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
  git::clone{$name:
    git_repo        => $git_repo,
    projectroot     => $documentroot,
    cloneddir_user  => $uid_name,
    cloneddir_group => $gid_name,
    before          => File[$documentroot],
  }
  if $run_mode == 'fcgid' {
    Git::Clone[$name]{
      require => [User::Sftp_only[$uid_name],
                  User::Managed[$run_uid_name] ],
    }
  } else {
    Git::Clone[$name]{
      require => User::Sftp_only[$uid_name],
    }
  }
}
