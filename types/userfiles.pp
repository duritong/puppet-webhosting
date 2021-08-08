type Webhosting::Userfiles = Hash[
  Variant[Stdlib::Unixpath, String[1]],
  Struct[{
      content    => Optional[String],
      source     => Optional[String],
      ensure     => Optional[Enum['directory','file']],
      replace    => Optional[Boolean],
      owner      => Optional[Variant[String,Integer]],
      mode       => Optional[Stdlib::Filemode],
      ensure_acl => Optional[Boolean],
  }]
]
