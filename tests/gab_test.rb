# test gab CRUD endpoints
require 'test_helper.rb'

class GabTest < BackdoorTestCase
  self.i_suck_and_my_tests_are_order_dependent! #TODO, just related around post

  def johns_first_gab
    {
      gab: {
        clue_count: 0,
        id: @john.gabs.first.id,
        related_avatar: @mary.avatar_url,
        related_phone: '',
        related_user_name: '',
        last_date: wildcard_matcher,
        sent: true,
        total_count: 1,
        unread_count: 0,
        content_cache: @john.gabs.first.content_cache,
        content_summary: @john.gabs.first.content_summary
      }
    }
  end

  def generate_message_json message, opt={}
    m =
      {
      content: message.content,
      deleted: message.deleted,
      key: wildcard_matcher,
      read: message.read,
      secret: "",
      sent: message.sent,
      created_at: wildcard_matcher,
      id: Fixnum,
      kind: message.kind,
      user_id: message.user_id
    }

    m[:gab_id] = message.gab.id #TODO ? if opt[:include_gab_id]

    return m
  end

  def johns_first_messages opt={}, extra_messages=[]
    f_gab = @john.gabs.first
    f_m = f_gab.messages.first

    m =  [
          generate_message_json(f_m, opt)
         ]
    m.concat extra_messages
    m.ordered!
  end

  def test_get_gabs
    auth_get_ok @john, '/gabs'
    gabs = {
      gabs:
      [
       johns_first_gab
      ].ordered!
    }
    assert_json_match response_ok(gabs), last_response.body
  end

  def test_get_a_gab
    auth_get_ok @john, "/gabs/#{@john.gabs.first.id}"
    assert_json_match response_ok(johns_first_gab), last_response.body
  end

  def test_post_a_gab
    auth_post @john, "/gabs/#{@john.gabs.first.id}"
    assert !last_response.ok?
  end

  def test_delete_a_gab
    auth_delete_ok @mary, "/gabs/#{@mary.gabs.first.id}"
    #TODO: no deleted mark on gab, we can only check messaages (which would be empty)
    auth_get_ok @mary, "/gabs/#{@mary.gabs.first.id}/messages"
    assert_json_match response_ok({messages: []}), last_response.body
  end

  def test_get_an_extended_gab
    auth_get_ok @john, "/gabs/#{@john.gabs.first.id}", {extended: true}
    extended = johns_first_gab.clone
    extended[:gab][:messages] = johns_first_messages()
    assert_json_match response_ok(extended), last_response.body
  end

  def test_get_messages
    auth_get_ok @john, "/gabs/#{@john.gabs.first.id}/messages"
    messages = {messages: johns_first_messages()} # {include_gab_id: false})
    assert_json_match response_ok(messages), last_response.body
  end

  def test_post_message
    j_gab = @john.gabs.first
    params = {
      content: "A new message",
      kind: 0, #TODO fixme
      key: "123"
    }
    auth_post_ok @john, "/gabs/#{j_gab.id}/messages", params
    new_message = j_gab.messages.last
    result_hash = {
      message: generate_message_json(new_message)
    }
    match = assert_json_match response_ok(result_hash), last_response.body
  end

  def test_delete_a_message
    auth_delete @john, "/gabs/#{@john.gabs.first.id}/messages/#{@john.gabs.first.messages.first.id}"
    assert !last_response.ok?
  end
end
