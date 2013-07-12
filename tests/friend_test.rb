require 'test_helper.rb'
require 'webmock/minitest'

class FriendTest < BackdoorTestCase
  def teardown
    Friendship.destroy_all
  end

  def fb_friends
    {data: [{id: @john.fb_id, first_name: "John", last_name: "Wayne"},
            {id: "3", first_name: "Not", last_name:"Afriend"}]}
  end

  def stub_fb_token
    stub_request(:get, "https://graph.facebook.com/oauth/access_token").
      with(query: hash_including({})).to_return(body: "")
  end

  def stub_fb_friends_with fb
    WebMock.reset!
    stub_fb_token

    stub_request(:get, "https://graph.facebook.com/#{@mary.fb_id}/friends").
      with(query: hash_including({})).to_return(body: fb.to_json)
  end

  def test_getting_fb_friends   
    stub_fb_friends_with(fb_friends)
    @mary.fetch_fb_friends

    assert @mary.friendships.count == 1, "did not get 1 friends"
    assert @mary.friendships.first.friend == @john, "did not set friend to john"
    f = @mary.friendships.first
    assert f.first_name == "John", "did not get first name"
    assert f.last_name == "Wayne", "did not get last name"
  end

  def test_get_friends_api
    stub_fb_friends_with(fb_friends)
    @mary.fetch_fb_friends

    auth_get_ok @mary, "/friends"
    friends = {friends:
      [{id: wildcard_matcher,
         user_id: @mary.id,
         friend_id: @john.id,
         social_id: @john.fb_id,
         provider: "facebook"}].ordered!
    }
    assert_json_match response_ok(friends), last_response.body
  end
  def test_getting_fb_friends_drop
    stub_fb_friends_with(fb_friends)
    @mary.fetch_fb_friends
    stub_fb_friends_with({data: []})
    @mary.fetch_fb_friends
    assert @mary.friendships.count == 0, "did not remove friend"
  end

  def test_getting_fb_friends_add
    stub_fb_friends_with(fb_friends)
    @mary.fetch_fb_friends
    User.make!(fb_id: "4")
    new_fb = fb_friends
    new_fb[:data] << {id: "4", first_name: "Now", last_name: "Afriend"}
    stub_fb_friends_with(new_fb)
    @mary.fetch_fb_friends
    assert @mary.friendships.count == 2, "did add a new friend"
  end

  def test_fb_update
    skip "test this later"
  end
end
