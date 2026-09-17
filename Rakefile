require_relative 'lib/unpoly/guide'

namespace :algolia do
  desc 'Push content to Algolia search'
  task :push_all do
    Unpoly::Guide::Algolia.new.push_all
  end
end

namespace :docs do
  desc 'List public selectors and events that no guide page explains (@learn-ref)'
  task :learn_refs do
    missing = Unpoly::Guide.current.features_without_learn_ref
    missing.sort.each { |feature| puts "#{feature.name} (#{feature.kind}, #{feature.interface.name})" }
    puts "#{missing.size} public selectors/events without an @learn-ref."
  end

  desc 'Check that every URL unpoly.com serves today still resolves ("no lost URL")'
  task :check_urls do
    ok = Unpoly::Guide::UrlCheck.new.run
    exit(1) unless ok
  end
end
