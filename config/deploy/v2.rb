raise "v2.unpoly.com is redirecting to unpoly.com while the latest version is 2.x. Deploy with `cap latest deploy` instead."

set :deploy_to, "/var/www/v2.unpoly.com/"
set :branch, 'master'
# set :middleman_options, %w[--environment=production]
set :keep_releases, 10

server 'app01-prod.makandra.makandra.de', user: 'deploy-unpoly_v2_p', roles: %w(app)
server 'app02-prod.makandra.makandra.de', user: 'deploy-unpoly_v2_p', roles: %w(app)
