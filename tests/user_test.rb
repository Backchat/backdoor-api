require 'test_helper.rb'

class UserTest < BackdoorTestCase
  def test_new_user_gets_welcome
    u = User.new
    u.save
    assert u.gabs.count == 1, "welcome gab not sent"
    assert u.gabs.first.messages.count == 1, "welcome gab message not sent"
  end
end
