load 'deploy' if respond_to?(:namespace) # cap2 differentiator

set :deploy_to, "/var/www/upjs.io/"
set :user, "deploy-upjs_p"
set :use_sudo, false
set :deploy_via, :remote_cache
set :copy_exclude, [ '.git' ]
set :clear_cache, :false

set :repository,  "git@code.makandra.de:makandra/upjs-guide.git"
set :scm, :git

server "c23.makandra.makandra.de", :app, :web, :primary => true
server "c42.makandra.makandra.de", :app, :web

ssh_options[:forward_agent] = true

namespace :deploy do

  task :restart do
  end

  task :start do
  end

  task :stop do
  end

  task :migrate do
  end

  task :finalize_update do
  end

end

task :fix_remote_cache, :role => :app do
  if fetch(:deploy_via) == :remote_cache
    run "cd #{shared_path}/cached-copy; git remote set-url origin #{fetch(:repository)}"
  end
end
