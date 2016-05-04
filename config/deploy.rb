lock '3.4.1'

require "whenever/capistrano"
set :whenever_command, "bundle exec whenever"

set :rbenv_ruby, '2.3.0'
set :bundle_flags, '--quiet'

set :application, 'proecto10'
set :repo_url, 'git@github.com:TristanPouliquen/IIC3103-Rails10.git'

set :linked_files, %w{config/database.yml config/secrets.yml config/application.yml}
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
