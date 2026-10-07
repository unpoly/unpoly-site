# The Apache rules unpoly.com is served with (source/.htaccess.erb). Apache sits behind
# a proxy that ends TLS, so it sees plain http: a redirect to a bare path comes out as
# an http:// Location.
describe 'the .htaccess', type: :feature do

  def htaccess
    visit '/.htaccess'
    page.body
  end

  def rewrite_rules
    htaccess.lines.map(&:strip).grep(/\ARewriteRule /)
  end

  it 'names the https scheme in every redirect it rewrites' do
    redirects = rewrite_rules.select { |rule| rule =~ /\[[^\]]*\bR\b/ || rule =~ /\[[^\]]*R=/ }

    expect(redirects).not_to be_empty
    redirects.each do |rule|
      target = rule.split(/\s+/)[2]
      expect(target).to start_with('https://'), "#{rule} redirects without a scheme"
    end
  end

  it 'sends other hosts to unpoly.com before it maps paths to their index.html' do
    host = rewrite_rules.index { |rule| rule.include?('https://unpoly.com/') }
    index = rewrite_rules.index { |rule| rule.include?('/index.html [L]') }

    expect(host).to be < index
  end

end
