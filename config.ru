root_dir = File.expand_path(File.dirname(__FILE__))
app_file = File.join(root_dir, 'stadiumchorus.rb')

require app_file

set :environment, (ENV['RACK_ENV'] || "development").to_sym

run Sinatra::Application
