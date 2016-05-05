# stdout is ignored, and stderror is sent normally for cron to take care of, which
# probably means it is emailed to the user whose crontab whenever writes to
set :output, "#{fetch(:shared_path)}/log/cron.log"

every 4.hours do
  rake "ftp:process"
end
