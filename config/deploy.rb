require "whenever/capistrano"

lock '3.4.1'
set :rbenv_ruby, '2.3.0'
set :bundle_flags, '--quiet'

set :whenever_command, lambda {"cd #{release_path} && $HOME/.rbenv/bin/rbenv exec bundle exec whenever --update-crontab #{fetch(:application)}_#{fetch(:stage)}" }

set :application, 'proyecto10'
set :repo_url, 'git@github.com:TristanPouliquen/IIC3103-Rails10.git'

set :linked_files, %w{config/database.yml config/secrets.yml config/application.yml config/boot.rb}
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
