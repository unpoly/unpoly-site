set :deploy_to, "/opt/www/v2-pre.unpoly.com/"
set :branch, 'master'
# set :middleman_options, %w[--environment=production]
set :keep_releases, 10

server 'triskweline.de', user: 'deploy', roles: %w(app)
server 'triskweline.de', user: 'deploy', roles: %w(app)
