class Playlist < ActiveRecord::Base
  has_many :songs, dependent: :destroy
  
  validates_presence_of :card_uid
  validates_uniqueness_of :card_uid
  validates_presence_of :title
end