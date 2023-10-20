# configure some default variables
class webhosting (
  $cron_timer_defaults = {
    on_calendar         => 'daily',
    randomize_delay_sec => '1d',
  },
) {
}
