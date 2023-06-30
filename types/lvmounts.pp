type Webhosting::Lvmounts = Hash[
  Pattern[/^[a-zA-Z0-9_\-]+$/],
  Struct[{
      ensure                  => Optional[Enum['present','absent']],
      folder                  => String[1],
      size                    => Pattern[/^[0-9]+(G|M)$/],
      owner                   => Optional[String[1]],
      group                   => Optional[String[1]],
      mode                    => Optional[Stdlib::Filemode],
      seltype                 => Optional[String[1]],
      selinux_ignore_defaults => Optional[Boolean],
      manage_folder           => Optional[Boolean],
      mount_options           => Optional[String[1]],
      fs_type                 => Optional[Enum['ext4','xfs']],
      fs_options              => Optional[String[1]],
  }]
]
