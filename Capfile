load 'deploy'

set :deploy_to, "/var/www/unpoly.com/"
set :user, "deploy-unpoly_p"
set :use_sudo, false
set :keep_releases, 10

server "c23.makandra.makandra.de", :app, :web, :primary => true
server "c42.makandra.makandra.de", :app, :web

ssh_options[:forward_agent] = true

namespace :deploy do
  task :build_files do
    run_locally 'middleman build'
  end

  task :update_code do

    local_path = File.join(Dir.pwd, 'build', '.')
    remote_path = File.join(release_path, 'build')

    run "mkdir -p #{remote_path}"
    top.upload local_path, remote_path, via: :scp, recursive: true
  end
end

before 'deploy:update_code', 'deploy:build_files'
after 'deploy:restart', 'deploy:cleanup' # https://makandracards.com/makandra/1432-capistrano-delete-old-releases
