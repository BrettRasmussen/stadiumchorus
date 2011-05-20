namespace :db do
  desc "Migrate the database"
  task :migrate do
    puts <<-EOS
    Migration through rake is not set up yet.  Install racksh, then:
      $ RACK_ENV=whatever racksh
      racksh$ ActiveRecord::Migrator.migrate("db/migrate")
    EOS
  end

  desc "back up the database to home box"
  task :backup do
    if !%w[development test].include?(ENV['RACK_ENV'])
      puts %x{scp -P 202 db/production.sl3 twoedge.dyndns.org:wk/stadiumchorus/stadiumchorus/db/}
    end
  end
end
