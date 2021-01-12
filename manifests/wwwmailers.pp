# add a common group for mailers
class webhosting::wwwmailers {
  group { 'wwwmailers':
    gid => 9999,
  }
}
