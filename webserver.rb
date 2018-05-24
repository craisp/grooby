require 'sinatra'
require 'active_record'
require 'haml'
require 'pry'

class Webserver < Sinatra::Base
  after do
    ActiveRecord::Base.connection.close
  end

  set :bind, '0.0.0.0'
  set :views, Proc.new { File.join(root, "webserver", "views") }

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
    binding.pry
    playlist = Playlist.new
    playlist.card_uid = params[:card_uid]
    playlist.title = params[:title]
    playlist.button_number = params[:button_number] === "" ? nil : params[:button_number]
    if playlist.save
      "super"
    else
      "fehler"
    end
  end
end