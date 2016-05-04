set :stage, :production
set :deploy_to, '/home/administrator/integra10-rails'

server 'integra10.ing.puc.cl', user: 'administrator', roles: %w{web app db}
