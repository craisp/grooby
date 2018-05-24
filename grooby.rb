require_relative 'gems'
require_relative 'helper'

def init_mpd
  $log.info 'Initializing MPD'
  
  $mpd = MPD.new
  $mpd.connect
  $mpd.pause = true
end

def init_buttons
  $log.info 'Initializing buttons'
  
  $pause_button = 20
  $vol_up_button = 26
  $vol_down_button = 19
  $previous_button = 16
  $next_button = 21
  
  $halt_switch = 13

  $control_buttons = [$pause_button, $vol_up_button, $vol_down_button, $previous_button, $next_button]
  
  RPi::GPIO.set_numbering :bcm
  
  $control_buttons.each do |button|
    RPi::GPIO.setup button, as: :input, pull: :down
  end
  
  RPi::GPIO.setup $halt_switch, as: :input, pull: :down
end

def start_playlist(card_uid)
  $log.info 'Starting Playlist ' + card_uid
  
  $mpd.stop
  $mpd.clear
  $mpd.where({file: card_uid}, {add: true})
  $mpd.play
end

def toggle_pause
  new_state = !$mpd.paused?
  
  $log.info 'Toggling pause to ' + new_state.to_s
  
  $mpd.pause = new_state
end

def wait_for_release_or_another_button
  sleep(0.05)
  loop do
    buttons_states = $control_buttons.map{|button| RPi::GPIO.high? button}
    buttons_without_pause_states = buttons_states[1..-1]
    break if buttons_states.none? || buttons_without_pause_states.any?
  end
  sleep(0.05)
  if $control_buttons.map{|button| RPi::GPIO.high? button}.any?
    sleep(3)
    second_button = $control_buttons[1..-1].map{|button| RPi::GPIO.high? button}.find_index(true)
    case second_button
    when 0
      puts 'vol_up_button'
    when 1
      puts 'vol_down_button'
    when 2
      require_relative 'webserver'
      $webserver_thread = Thread.new{Webserver.run!}
    when 3
      puts 'next_button'
    end
  end
  while($control_buttons.map{|button| RPi::GPIO.high? button}.any?)
  end
  sleep(0.05)
end

def volume_up
  new_volume = $mpd.volume + 5
  
  if new_volume <= 80
    $mpd.volume = new_volume
    $log.info 'Setting volume to ' + new_volume.to_s
  end
end

def volume_down
  new_volume = $mpd.volume - 5
  
  if new_volume >= 40
    $mpd.volume = new_volume
    $log.info 'Setting volume to ' + new_volume.to_s
  end
end

def button_control
  $log.info 'Start listening to buttons'
  
  while(!$ready_for_halt)
    if RPi::GPIO.high? $pause_button
      toggle_pause
      wait_for_release_or_another_button
    end
    $mpd.next && $log.info('skipping forward') && sleep(1) if RPi::GPIO.high? $next_button
    $mpd.previous && $log.info('skipping back') && sleep(1) if RPi::GPIO.high? $previous_button
    volume_up && sleep(0.2) if RPi::GPIO.high? $vol_up_button
    volume_down && sleep(0.2) if RPi::GPIO.high? $vol_down_button
  end
end

def halt_control
  $log.info 'Start listening for halt'
  
  while(!$ready_for_halt)
    $ready_for_halt = RPi::GPIO.low? $halt_switch
    sleep(0.5)
  end
end
  
$log.info 'grooby is grooving up'

$ready_for_halt = false

$current_configuration_card_uid = nil
$webserver_thread = nil

require_relative 'card_reader.rb'
init_card_reader()

init_buttons()
init_mpd()
establish_db_connection()

halt_thread = Thread.new{halt_control()}
card_thread = Thread.new{card_control()}
button_thread = Thread.new{button_control()}

$webserver_thread.join if !$webserver_thread.nil?
card_thread.join
button_thread.join

