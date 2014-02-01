web: bundle exec unicorn -p $PORT -c ./unicorn.rb -E $RACK_ENV config.ru 
message_worker: QUEUE="message_delivery,friend_notification" bundle exec rake resque:work
low_pri_worker: QUEUE="feedback_delivery,abuse_report_delivery,device_cleanup" bundle exec rake resque:work
friends_worker: QUEUE="update_friends" bundle exec rake resque:work
invite_worker: QUEUE="invite_sms, invite_sms_parse" bundle exec rake resque:work
all_workers: QUEUE=* bundle exec rake resque:work
scheduler: bundle exec rake resque:scheduler
