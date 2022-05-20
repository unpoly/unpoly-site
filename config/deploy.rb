set :scm, :middleman

after 'deploy:finished' do
  puts "Update the full text index with `STAGE=#{ENV['STAGE']} ALGOLIA_KEY=secret bundle exec rake algolia:push_all`"
end
