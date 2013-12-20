class NotificationQueue
  def self.perform(hash)
    pusher = Grocer.pusher(
                           certificate:  APN_CERT,
                           passphrase:   '',
                           gateway:      APN_GATEWAY
                           )

    ActiveRecord::Base.logger.info "#{hash}"
    apn_final_hash = hash["apn_hash"].merge({"sound" => 'default'})
    
    hash["apn_device_tokens"].each do |token|
      notification = Grocer::Notification.new(apn_final_hash.merge({"device_token" => token}))
      pusher.push(notification)
    end      

    if hash["gcm_device_tokens"].present?
      gcm_pusher = GCM.new(GCM_SECRET_KEY)
      gcm_pusher.push hash["gcm_device_tokens"], hash["google_hash"]
      gcm_pusher.close
    end
  end
end

class MessageDeliveryQueue
  @queue = :message_delivery
  def self.perform(hash)
    NotificationQueue.perform hash
  end
end

class FriendNotificationQueue
  @queue = :friend_notification

  def self.perform(hash)
    NotificationQueue.perform(hash)
  end
end

class DeviceCleanupQueue
  @queue = :device_cleanup

  def self.perform
    feedback = Grocer.feedback(
      certificate:  APN_CERT,
      gateway:      APN_GATEWAY,
      passphrase:   '',
      port:         2196,
      retries:      3
    )

    feedback.each do |attempt|
      device = Device.find_by_device_token(attempt.device_token)
      next if device.nil?
      device.destroy if attempt.timestamp > device.updated_at
    end
  end

end

class FeedbackDeliveryQueue
  @queue = :feedback_delivery

  def self.perform(id)
    fb = Feedback.find_by_id(id)
    return if fb.nil?

    user = fb.user
    user_name = user.get_name || 'Anonymous user'
    from = "%s <%s>" % [user_name, user.email]

    body = fb.content
    body = body + "\n\nRating: %s" % fb.rating if fb.rating != 0

    Pony.mail(
      :to => FEEDBACK_EMAIL,
      :via => :smtp,
      :via_options => SMTP_SETTINGS,
      :subject => 'New feedback' % user_name,
      :from => from,
      :reply_to => fb.user.email,
      :body => body,
    )
  end
end

class AbuseReportDeliveryQueue
  @queue = :abuse_report_delivery

  def self.perform(id)
    ar = AbuseReport.find_by_id(id)
    return if ar.nil?

    user = ar.user
    user_name = user.get_name || 'Anonymous user'
    from = "%s <%s>" % [user_name, user.email]

    body = ar.content

    Pony.mail(
      :to => ABUSE_REPORT_EMAIL,
      :via => :smtp,
      :via_options => SMTP_SETTINGS,
      :subject => 'Abuse report from %s (#%s)' % [user_name, user.id],
      :from => from,
      :reply_to => user.email,
      :body => body,
    )
  end
end

class UpdateFriendsQueue
  @queue = :update_friends
  def self.perform user_id, access_token, is_new, provider
    user = User.find_by_id(user_id)
    return if user.nil?

    if provider == FACEBOOK_PROVIDER
      user.fetch_fb_friends is_new
    elsif provider == GPP_PROVIDER
      user.fetch_gpp_friends access_token, is_new
    end
  end
end

class InviteSMSParseQueue
  @queue = :invite_sms_parse
  
  def self.perform contacts, body, user_id
    user = User.find_by_id(user_id)
    return if user.nil?
    contacts.each do |number|
      contact = Contact.find_by_phone_number number
      contact = Contact.create!(phone_number: number, enabled: true) unless contact

      invitation = user.invitations.build(contact_id: contact.id,
                                           body: body,
                                           delivered: false)
      invitation.save
    end
  end
end

class InviteSMSQueue
  @queue = :invite_sms

  br_operators = [96, 51, 27, 28, 98, 85, 84, 14, 47, 49, 65, 32,
                  12, 71, 12, 36, 35, 21, 19, 56, 91, 13, 10, 45,
                  37, 42, 25, 63, 87, 46, 26, 23, 57, 89, 11, 52,
                  72, 95, 65, 61, 31, 53, 62, 48, 24, 69, 43, 81,
                  18, 54, 34, 41, 17, 16, 38, 75, 15, 58]

  br_zones = [ 79, 91, 31, 95, 61, 67, 65, 48, 85, 62, 83, 43, 96, 82,
               92, 84, 63, 51, 69, 81, 68, 21, 71, 98, 11, 86, 27]

  def self.perform i_id
    invite = Invitation.find_by_id(i_id)
    return unless invite
    client = Twilio::REST::Client.new TWILIO_SID, TWILIO_TOKEN

    to = invite.contact.phone_number
    to = to.tr('^0-9','')
    
    real_number = nil

    if to.length == 8 
      # we have (probably) a local BR number.
      # can't do anything.
      #assume it's rio de janireo
      real_number = "+5521" + to
    elsif to.length == 9
      # we have (probably) a local BR number.
      # can't do anything.
      # we assume it's sao paulo
      real_number = "+5511" + to
    elsif to.starts_with? "0" 
      #this may be a international text number, or a BR inter-country number...
      next_two_digits = to[1,2]
      value = Integer(next_to_digits)
      br = false
      if br_operators.include? value
        # the next two digits ought to be the city code
        next_two_digits = to[3,2]
        zone = Integer(next_to_digits)
        if br_zones.include? zone
          # this is a inter-country BR call
          rest_of_number = to[5..-1]
          real_number = "+55" + zone + rest_of_number
          br = true
        end
      end
      if not br
        #international. take a stab at extracting the exit code out
        #this really actually needs to know the country we are in..we'll
        #likely fuck up here and txt the wrong number.
        #try ony 00 and 011 which covers 90% of the countries in the world
        if to[1] == "0"
          rest_of_number = to[2..-1]
          real_number = "+" + rest_of_number
        elsif next_two_digits == "11"
          rest_of_number = to[3..-1]
          real_number = "+" + rest_of_number
        end
      end
    else 
      #assume a local US number..
      real_number = to
    end

    body = invite.body + " #{Invitation::CancelMsg}"

    puts "PHONE: Turning #{to} to #{real_number}"
    client.account.sms.messages.create(
                                       :from => TWILIO_NUMBER,
                                       :to => real_number,
                                       :body => body
                                       )
    invite.delivered = true
    invite.save
  end
end
