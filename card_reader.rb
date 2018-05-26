require 'mfrc522'

def init_card_reader
  $log.info 'Initializing card reader'

  $r = MFRC522.new
end

def card_control
  $log.info 'Start listening to Cards'
  
  while(!$ready_for_halt)
    begin

      if $r.picc_request(MFRC522::PICC_REQA)
        uid, sak = $r.picc_select
        uid = uid.pack('C*').unpack('H*')[0]
        $current_configuration_card_uid = uid
        start_playlist(uid)
        $r.picc_halt
      end


    rescue Exception => e

      puts "Exception #{e}"

    end
    sleep(1)
  end
end