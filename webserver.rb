require 'sinatra'
require 'active_record'
require 'haml'
require 'fileutils'
require 'securerandom'

def generate_playlist_file(playlist)
  data = ""
  playlist.songs.order(:sort_index).each do |song|
    data += "#{playlist.card_uid}/#{song.uuid}\n"
  end

  File.open("/var/lib/mpd/playlists/card_#{playlist.card_uid}.m3u", 'w') do |f|
    f.write data
  end
  
  $mpd.rescan
end

class Webserver < Sinatra::Base
  after do
    ActiveRecord::Base.connection.close
  end

  set :bind, '0.0.0.0'
  set :views, Proc.new { File.join(root, "webserver", "views") }
  set :public_folder, Proc.new { File.join( root, "webserver", "vendor" ) }
  set :method_override, true

  get '/' do
    haml :root, format: :html5, layout: :layout
  end
  
  get '/playlisten' do
    @playlists = Playlist.all
    haml :"playlists/index", format: :html5, layout: :layout
  end
  
  get '/playlisten/neu' do
    @playlist = Playlist.new(card_uid: $current_configuration_card_uid)
    
    card_uid_present = $current_configuration_card_uid.present?
    card_uid_valid = card_uid_present && Playlist.find_by(card_uid: $current_configuration_card_uid).nil?
    
    buttons = ["Pause", "Lauter", "Leiser", "Zurück", "Weiter"]
    
    button_select = $control_buttons.each_with_index.map{ |button, i|
                      if Playlist.find_by(button_number: button).nil?
                        [button, buttons[i]]
                      end
                    }
    
    haml :"playlists/new", format: :html5, layout: :layout, locals: {card_uid_present: card_uid_present, card_uid_valid: card_uid_valid, button_select: button_select}
  end
  
  get '/playlisten/:card_uid' do
    @playlist = Playlist.find(params['card_uid'])
    haml :"playlists/show", format: :html5, layout: :layout
  end
  
  post '/playlisten' do
    playlist = Playlist.new
    playlist.card_uid = params[:card_uid]
    playlist.title = params[:title]
    playlist.button_number = params[:button_number] === "" ? nil : params[:button_number]
    if playlist.save
      status 201
      redirect to("/playlisten/#{params[:card_uid]}")
    else
      "Fehler beim Anlegen der Playlist"
      status 501
    end
  end
  
  post '/playlisten/:card_uid/songs' do
    @playlist = Playlist.find(params['card_uid'])
    old_filename = params[:file][:filename]
    file = params[:file][:tempfile]
    
    $log.info "New file received for playlist #{params['card_uid']}: #{old_filename}"
    
    dirname = "/var/lib/mpd/music/#{params['card_uid']}"
    unless File.directory?(dirname)
      FileUtils.mkdir_p(dirname)
    end
    
    song = Song.new(playlist: @playlist)
    song.title = old_filename.split('.')[0..-2].join('.')
    
    new_filename = SecureRandom.uuid + "." + old_filename.split('.').last
    
    File.open("#{dirname}/#{new_filename}", 'wb') do |f|
      f.write(file.read)
    end
    
    song.uuid = new_filename
    song.sort_index = @playlist.songs.any? ? @playlist.songs.pluck(:sort_index).sort.last + 1 : 0
    
    status 501 unless song.save
    
    generate_playlist_file(@playlist)
    
    status 201
  end
  
  delete '/playlisten/:card_uid' do
    playlist = Playlist.find(params['card_uid'])
    if playlist.present?
      FileUtils.rm_rf("/var/lib/mpd/music/#{params['card_uid']}")
      File.delete("/var/lib/mpd/playlists/card_#{params['card_uid']}.m3u")
      playlist.destroy
      
      $mpd.rescan
      redirect '/playlisten'
    end
  end
end