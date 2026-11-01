set :deploy_to, "/var/www/v3.unpoly.com/"
set :branch, 'master'
# set :middleman_options, %w[--environment=production]
# Every release holds a full build of ~75 MB, 40 MB of it preview images. Nobody rolls back
# further than one release.
set :keep_releases, 3

server 'app01-prod.makandra.makandra.de', user: 'deploy-unpoly_v3_p', roles: %w(app)
server 'app02-prod.makandra.makandra.de', user: 'deploy-unpoly_v3_p', roles: %w(app)
