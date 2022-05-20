set :scm, :middleman

namespace :deploy do
  task :remember_algolia_push do
    puts "Update the full text index with `STAGE=#{ENV['STAGE']} ALGOLIA_KEY=secret bundle exec rake algolia:push_all`"
  end

  after :finished, :remember_algolia_push
end
