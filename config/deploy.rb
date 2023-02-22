set :scm, :middleman

namespace :deploy do

  task :set_stage_env do
    ENV['STAGE'] = fetch(:stage).to_s
  end

  after :starting, :set_stage_env

  task :remember_algolia_push do
    puts "Update the full text index with `STAGE=#{fetch(:stage)} ALGOLIA_KEY=secret bundle exec rake algolia:push_all`"
  end

  after :finished, :remember_algolia_push
end
