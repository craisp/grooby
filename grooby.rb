require 'mfrc522'
require 'ruby-mpd'

$r = MFRC522.new

def init_mpd
  $mpd = MPD.new
  $mpd.connect
  $mpd.stop
  $mpd.clear
end

def start_playlist(card_uid)
  $mpd.stop
  $mpd.clear
  $mpd.where({file: card_uid}, {add: true})
  $mpd.play
end

def card_control
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

init_mpd()

card_thread = Thread.new{card_control()}
card_thread.join
