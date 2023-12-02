type Webhosting::Cronjobs = Hash[
  Pattern[/^[a-zA-Z0-9_\-]+$/],
  Struct[{
      cmd                    => String[1],
      ensure                 => Optional[Enum['present','absent']],
      group                  => Optional[String[1]],
      supplementary_groups   => Optional[Array[String[1]]],
      on_calendar            => Optional[String],
      randomize_delay_sec    => Optional[String],
      read_write_directories => Optional[Array[Stdlib::Unixpath]],
      uses_podman            => Optional[Boolean],
  }]
]
