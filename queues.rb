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

class InviteSMSQueue
  @queue = :invite_sms
  def self.perform i_id
    invite = Invitation.find_by_id(i_id)
    return unless invite
    client = Twilio::REST::Client.new TWILIO_SID, TWILIO_TOKEN

    to = invite.contact.phone_number
    to = to.tr('^0-9','')

    if to.length == 10 #US
      #just send it, since twilio assumes US by default
    else #assume BR
      #it should be 8 digits. the BR E184 format should be
      #"+155<digits>" 55 is the area code
      to = "+155" + to
    end

    body = invite.body + " #{Invitation::CancelMsg}"

    client.account.sms.messages.create(
                                       :from => '+13104398878',
                                       :to => to,
                                       :body => body
                                       )
    invite.delivered = true
    invite.save
  end
end
