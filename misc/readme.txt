To reset database:

1. Kill services

kill server
kill resque


2. Reset data

$ cd /home/dan/youtell-api
$ ./misc/resetdb


3. Start services

$ ./misc/server
$ ./misc/resque

