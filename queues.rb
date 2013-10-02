class MessageDeliveryQueue
  @queue = :message_delivery

  def self.perform(hash)
    deliver_apn_hash(hash)
  end
end

class FriendNotificationQueue
  @queue = :friend_notification

  def self.perform(hash)
    deliver_apn_hash(hash)
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

class UpdateFBFriendsQueue
  @queue = :update_fb_friends
  def self.perform u_id
    user = User.find_by_fb_id(u_id)
    return if user.nil?
    user.fetch_fb_friends
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
  
  def self.perform i_id
    invite = Invitation.find_by_id(i_id)
    return unless invite
    client = Twilio::REST::Client.new TWILIO_SID, TWILIO_TOKEN

    to = invite.contact.phone_number
    to = to.tr('^0-9','')
    
    real_number = nil

    if to.length == 8 #assume local BR number
      real_number = "+5521" + to
    elsif to.length == 9 #assume local BR number
      real_number = "+5511" + to
    elsif to.starts_with? "021" #long distance BR number
      rest_of_number = to[3..-1]
      real_number = "+55" + rest_of_number
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
