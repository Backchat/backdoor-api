require 'machinist/active_record'

User.blueprint do
  autocreated {false}
  registered {true}
  fake {false}
  featured {false}
  tokens {[Token.make]}
end

Token.blueprint do 
  access_token {"#{sn}"}
end

def mock_users
  #Mock factory user
  User.make!(phone: "", fb_id: FACTORY_USER_UID)

  #TODO fix this mock for fb info. bit brittle  
  fb_data = {
    'likes' => [{'id' => 1, 'name' => "John"}, {'id' => 2, 'name' => "Fred"} ],
  }
  u = [User.make!(phone: "1234567890", fb_id: "1", fb_data: fb_data), User.make!(phone: "2345678901", fb_id: "2")]

  #TODO perhaps its best not to do it this way
  g = Gab.my_create(u[0], u[1], "", u[1].phone)
  g.create_message_from_params(content: "test message", kind:MESSAGE_KIND_TEXT)

  u
end
