type Webhosting::Cronjobs = Hash[
  Pattern[/^[a-zA-Z0-9_\-]+$/],
  Struct[{
      ensure                 => Optional[Enum['present','absent']],
      cmd                    => String[1],
      group                  => String[1],
      supplementary_groups   => Array[String[1]],
      on_calendar            => Optional[String],
      randomize_delay_sec    => Optional[String],
      read_write_directories => Optional[Array[Stdlib::Unixpath]],
      uses_podman            => Optional[Boolean],
  }]
]
