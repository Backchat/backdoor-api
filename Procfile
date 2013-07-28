web: bundle exec thin start -R config.ru -e $RACK_ENV -p $PORT
message_worker: QUEUE="message_delivery,friend_notification" bundle exec rake resque:work
low_pri_worker: QUEUE="feedback_delivery,abuse_report_delivery,device_cleanup" bundle exec rake resque:work
fb_worker: QUEUE="update_fb_friends" bundle exec rake resque:work
all_workers: QUEUE=* bundle exec rake resque:work
scheduler: bundle exec rake resque:scheduler
