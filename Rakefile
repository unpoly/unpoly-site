require_relative 'lib/unpoly/guide'

namespace :algolia do
  desc 'Push content to Algolia search'
  task :push_all do
    Unpoly::Guide::Algolia.new.push_all
  end
end
