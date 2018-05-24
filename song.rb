class Song < ActiveRecord::Base
  belongs_to :playlist

  validates_presence_of :uuid
  validates_uniqueness_of :uuid
  validates_presence_of :sort_index
  validates_presence_of :playlist_id
  validates_presence_of :title
end