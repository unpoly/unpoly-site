require_relative 'lib/unpoly/guide'

namespace :search do
  desc 'Build the site and index it, so that search works in the preview server'
  task :index do
    # The preview server renders pages on the fly and writes no files, so there is
    # nothing for the indexer to read. A build gives it something, and the preview
    # then serves the index out of build/pagefind.
    system('bundle', 'exec', 'middleman', 'build') or exit(1)
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
