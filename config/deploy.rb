# config valid only for current version of Capistrano
set :rbenv_ruby, '2.3.0'

set :application, 'proecto10'
set :repo_url, 'git@github.com:TristanPouliquen/IIC3103-Rails10.git'

set :deploy_to, '/home/administrator/integra10-rails'

set :linked_files, %w{config/database.yml}
set :linked_dirs, %w{bin log tmp/pids tmp/cache tmp/sockets vendor/bundle public/system}

namespace :deploy do

  desc 'Restart application'
  task :restart do
    on roles(:app), in: :sequence, wait: 5 do
      execute :touch, release_path.join('tmp/restart.txt')
    end
  end

  after :publishing, 'deploy:restart'
  after :finishing, 'deploy:cleanup'
end