web: bundle exec thin start -R config.ru -e $RACK_ENV -p $PORT
worker: VVERBOSE=1 QUEUE="message_delivery,device_cleanup" bundle exec rake resque:work
scheduler: VERBOSE=1 bundle exec rake resque:scheduler
