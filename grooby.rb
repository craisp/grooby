require_relative 'gems'
require_relative 'helper'

def save_configuration
  File.open('grooby.conf', 'w') { |f| f.puts $conf.to_yaml  }
end

def load_configuration
  if File.exist?('grooby.conf')
    $conf = YAML::load_file('grooby.conf')
  else
    $conf[:player_mode] = "card"
    save_configuration()
  end
end

def init_mpd
  $log.info 'Initializing MPD'
  
  $mpd = MPD.new
  $mpd.connect
  $mpd.pause = true
end

def start_card_reader
  require_relative 'card_reader'
  init_card_reader()
  $card_thread = Thread.new{card_control()}
  $card_reader_started = true
end

def init_buttons
  $log.info 'Initializing buttons'
  
  $pause_button = 26
  $vol_up_button = 19
  $vol_down_button = 16
  $previous_button = 20
  $next_button = 21
  
  # $halt_switch = 13

  $control_buttons = [$pause_button, $vol_up_button, $vol_down_button, $previous_button, $next_button]
  
  RPi::GPIO.set_numbering :bcm
  
  $control_buttons.each do |button|
    RPi::GPIO.setup button, as: :input, pull: :down
  end
  
  # RPi::GPIO.setup $halt_switch, as: :input, pull: :down
end

def start_playlist(card_uid)
  $log.info 'Starting Playlist ' + card_uid
  
  playlist = Playlist.find(card_uid)
  
  if playlist.present?
    $mpd.stop
    $mpd.clear
    $mpd.send_command :load, "card_#{card_uid}"
    $mpd.play
    
    playlist.listen_count += 1
    playlist.save
  end
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
      if $conf[:player_mode] == "card"
        $conf[:player_mode] = "button"
      else
        $conf[:player_mode] = "card"
        start_card_reader() unless $card_reader_started
      end
      save_configuration()
    when 2
      require_relative 'webserver'
      
      start_card_reader() unless $card_reader_started
      $webserver_thread = Thread.new{Webserver.run!}
    when 3
      puts 'vol_down_button'
    end
  end
  while($control_buttons.map{|button| RPi::GPIO.high? button}.any?)
    sleep(0.1)
  end
  sleep(0.05)
end

def volume_up
  new_volume = $mpd.volume + 5
  
  if new_volume <= 100
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
    case $conf[:player_mode]
    when "card"
      if RPi::GPIO.high? $pause_button
        toggle_pause
        wait_for_release_or_another_button
      end
      $mpd.next && $log.info('skipping forward') && sleep(1) if RPi::GPIO.high? $next_button
      $mpd.previous && $log.info('skipping back') && sleep(1) if RPi::GPIO.high? $previous_button
      volume_up && sleep(0.2) if RPi::GPIO.high? $vol_up_button
      volume_down && sleep(0.2) if RPi::GPIO.high? $vol_down_button
    when "button"
      $control_buttons.each do |button|
        if RPi::GPIO.high? button
          if button != $current_playlist_button
            playlist = Playlist.find_by(button_number: button)
            start_playlist(playlist.card_uid) if playlist.present?
            $current_playlist_button = button
            wait_for_release_or_another_button if button == $pause_button
          else
            $mpd.next && $log.info('skipping forward') && sleep(1)
            wait_for_release_or_another_button if button == $pause_button
          end
        end
      end
    end
    sleep(0.05)
  end
end

def halt_control
  $log.info 'Start listening for halt'
  
  while(!$ready_for_halt)
    $ready_for_halt = RPi::GPIO.low? $halt_switch
    sleep(0.5)
  end
end
 
# MAIN

$log.info 'grooby is grooving up'

$ready_for_halt = false

$current_configuration_card_uid = nil
$webserver_thread = nil
$conf = {}
$card_reader_started = false
$current_playlist_button = nil

load_configuration()

init_buttons()
init_mpd()
establish_db_connection()

# halt_thread = Thread.new{halt_control()}
button_thread = Thread.new{button_control()}
$card_thread = nil

start_card_reader() if $conf[:player_mode] == "card"

$webserver_thread.join if !$webserver_thread.nil?
$card_thread.join if !$card_thread.nil?
button_thread.join
