# stdout is ignored, and stderror is sent normally for cron to take care of, which
# probably means it is emailed to the user whose crontab whenever writes to
set :output, "/home/administrator/integra10-rails/shared/log/cron.log"

every 4.hours do
  rake "ftp:process"
end

every 10.minutes do
	rake "stock:update"
end
