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

namespace :skill do
  desc 'Build the unpoly-docs skill, then run its search tests and ranking queries against it'
  task :test do
    # SKIP_SKILL=1 is the conscious way to do without; a missing Python is not.
    next puts('Skipping the skill tests (SKIP_SKILL=1).') if ENV['SKIP_SKILL']
    system('python3', '--version', out: File::NULL, err: File::NULL) or
      abort('rake skill:test needs Python 3.8 or later as `python3` on the PATH. Install it, or skip the skill with SKIP_SKILL=1.')

    # Only the skill's files (and the HTML pages they render) are built, into the
    # existing build/. The after_build steps still check and pack the skill.
    env = { 'SKIP_CHECK_LINKS' => '1', 'SKIP_SEARCH_INDEX' => '1' }
    system(env, 'bundle', 'exec', 'middleman', 'build', '--glob', 'skills/**/*', '--no-clean') or exit(1)
    system('bundle', 'exec', 'rspec', 'spec/build/skill_search_spec.rb') or exit(1)
  end
end
