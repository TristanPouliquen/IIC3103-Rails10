env :PATH, ENV['PATH']
# stdout is ignored, and stderror is sent normally for cron to take care of, which
# probably means it is emailed to the user whose crontab whenever writes to
set :output, "/home/administrator/integra10-rails/shared/log/cron.log"

every 4.hours do
  rake "ftp:process"
  rake "stock:emptyRecepcion"
  rake "stock:emptyPulmon"
end

every 2.hours do
  rake 'update:dispatch'
end

every 10.minutes do
	rake "stock:update"
end

every 1.hour do
  rake "aqmp:consume"
end

every 1.day do
  rake "bi:saldo"
  rake "bi:stock"
end
