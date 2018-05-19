require 'mfrc522'
require 'ruby-mpd'

$r = MFRC522.new
$mpd = MPD.new
$mpd.connect
$mpd.stop
$mpd.clear

def card_control
  while(true)
    begin

      if $r.picc_request(MFRC522::PICC_REQA)
        uid, sak = $r.picc_select
        uid = uid.pack('C*').unpack('H*')[0]
        case uid
        when "195ba9c5"
          $mpd.stop
          $mpd.clear
          $mpd.where({ album: "Phantasma"}, {add:true})
          $mpd.play
        when "f4771be3"
          $mpd.stop
          $mpd.clear
          $mpd.where({ album: "Dilation"}, {add:true})
          $mpd.play
        else
          puts "unbekannte Karte"
        end
        $r.picc_halt
      end


    rescue Exception => e

      puts "Exception #{e}"

    end
    sleep(0.2)
  end
end

card_thread = Thread.new{card_control()}
card_thread.join
