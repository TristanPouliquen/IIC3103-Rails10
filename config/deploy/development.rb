set :stage, :development
set :deploy_to, '/home/administrator/dev.integra10-rails'

set :whenever_environment, :stage
set :whenever_identifier, "#{fetch(:application)}_#{fetch(:stage)}"

server 'integra10.ing.puc.cl', user: 'administrator', roles: %w{web app db}
