set :stage, :development
set :deploy_to, '/home/administrator/dev.integra10-rails'

server 'integra10.ing.puc.cl', user: 'administrator', roles: %w{web app db}
