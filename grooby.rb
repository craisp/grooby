require 'mfrc522'
require 'ruby-mpd'
require 'rpi_gpio'
require 'syslog/logger'
require 'active_record'

def init_card_reader
  $log.info 'Initializing card reader'

  $r = MFRC522.new
end

def init_mpd
  $log.info 'Initializing MPD'
  
  $mpd = MPD.new
  $mpd.connect
  $mpd.stop
  $mpd.clear
end

def init_buttons
  $log.info 'Initializing buttons'
  
  $pause_button = 20
  $vol_up_button = 26
  $vol_down_button = 19
  $previous_button = 16
  $next_button = 21

  $control_buttons = [$pause_button, $vol_up_button, $vol_down_button, $previous_button, $next_button]
  
  RPi::GPIO.set_numbering :bcm
  
  $control_buttons.each do |button|
    RPi::GPIO.setup button, as: :input, pull: :down
  end
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
      puts 'previous_button'
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

def card_control
  $log.info 'Start listening to Cards'
  
  while(true)
    begin

      if $r.picc_request(MFRC522::PICC_REQA)
        uid, sak = $r.picc_select
        uid = uid.pack('C*').unpack('H*')[0]
        start_playlist(uid)
        $r.picc_halt
      end


    rescue Exception => e

      puts "Exception #{e}"

    end
    sleep(0.2)
  end
end

def button_control
  $log.info 'Start listening to buttons'
  
  while(true)
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
  

$log = Syslog::Logger.new 'grooby'
$log.info 'grooby is grooving up'

init_card_reader()
init_buttons()
init_mpd()

card_thread = Thread.new{card_control()}
button_thread = Thread.new{button_control()}
card_thread.join
button_thread.join