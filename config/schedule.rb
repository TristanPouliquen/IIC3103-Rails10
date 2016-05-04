# stdout is ignored, and stderror is sent normally for cron to take care of, which
# probably means it is emailed to the user whose crontab whenever writes to
set :output, {:standard => nil}

every 4.hours do
  rake "ftp:process"
end
