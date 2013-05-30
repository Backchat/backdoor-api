#!/usr/bin/env ruby

require './api'

feedback = Grocer.feedback(
  certificate:  APN_CERT,
  gateway:      APN_GATEWAY,
  passphrase:   '',
  port:         2196,
  retries:      3
)

feedback.each do |attempt|
  puts attempt.device_token, attempt.updated_at
  
  #device = Device.find_by_device_token(attempt.device_token)
  #next if device.nil?
  #device.destroy if attempt.timestamp > device.updated_at
end
