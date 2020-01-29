require_relative 'playlist'
require_relative 'song'

$log = Syslog::Logger.new 'grooby'

def establish_db_connection
  $log.info 'Trying to connect to database'
  ActiveRecord::Base.establish_connection(
    adapter: 'sqlite3',
    database: './database.sqlite3.db'
  )
  $log.info 'Database connected'
end