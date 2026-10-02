# Every page family, loaded directly. The baseline the navigation suites compare against.
PAGES = {
  'landing'   => '/',
  'learnhub'  => '/learn',
  'learnpage' => '/targeting-fragments',
  'apihub'    => '/api',
  'apimod'    => '/up.link',
  'apifeat'   => '/up.render',
  'apisel'    => '/up-accept',
  'changes'   => '/changes',
  'support'   => '/support',
  'imprint'   => '/imprint',
  'privacy'   => '/privacy',
  'install'   => '/install',
}

Shoot.suite 'direct', widths: [1280, 390], description: 'every family on direct load' do |b|
  PAGES.each { |name, path| b.visit(path); b.shot("direct-#{name}") }
  b.visit('/'); b.shot('direct-landing-full', full: true)
end
