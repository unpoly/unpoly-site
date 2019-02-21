set :deploy_to, "/var/www/unpoly.com/"
set :branch, 'master'
# set :middleman_options, %w[--environment=production]
set :keep_releases, 10

server 'c23.makandra-3.makandra.de', user: 'deploy-unpoly_p', roles: %w(app)
server 'c42.makandra-3.makandra.de', user: 'deploy-unpoly_p', roles: %w(app)
