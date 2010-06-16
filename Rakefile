namespace :db do
  desc "back up the database to home box"
  task :backup do
    if !%w[development test].include?(ENV['RACK_ENV'])
      puts %x{scp -P 202 db/production.sl3 twoedge.dyndns.org:wk/stadiumchorus/stadiumchorus/db/}
    end
  end
end
