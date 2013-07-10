# test gab CRUD endpoints
require 'test_helper.rb'

class GabTest < BackdoorTestCase
  self.i_suck_and_my_tests_are_order_dependent! #TODO, just related around post

  def generate_gab_json gab, opt
    {
      gab: {
        clue_count: gab.clue_count,
        id: gab.id,
        related_avatar: opt[:related_avatar]||gab.related_avatar,
        related_phone: opt[:related_phone]||gab.related_phone,
        related_user_name: opt[:related_user_name]||gab.related_user_name,
        last_date: wildcard_matcher,
        sent: true,
        total_count: opt[:total_count]||gab.total_count,
        unread_count: opt[:unread_count]||gab.unread_count,
        content_cache: gab.content_cache,
        content_summary: gab.content_summary
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
       generate_gab_json(@john.gabs.first, {})[:gab]
      ].ordered!
    }
    assert_json_match response_ok(gabs), last_response.body
  end

  def test_get_a_gab
    auth_get_ok @john, "/gabs/#{@john.gabs.first.id}"
    assert_json_match response_ok(generate_gab_json(@john.gabs.first,{})), last_response.body
  end

  def test_post_a_gab
    params = {
      receiver: {
        id: @mary.id
      },
      message: {
        content: "A new gab for a new day",
        kind: 0
      }
    }
    auth_post_ok @john, "/gabs", params
    new_gab = @john.gabs.last
    opt = {
      related_avatar: @mary.avatar_url,
      related_phone: '',
      related_user_name: '',
      total_count: 1,
      unread_count: 0,
      sent: true
    }
    assert_json_match response_ok(generate_gab_json(new_gab, opt)), last_response.body
  end

  def test_delete_a_gab
    auth_delete_ok @mary, "/gabs/#{@mary.gabs.first.id}"
    #TODO: no deleted mark on gab, we can only check messaages (which would be empty)
    auth_get_ok @mary, "/gabs/#{@mary.gabs.first.id}/messages"
    assert_json_match response_ok({messages: []}), last_response.body
  end

  def test_get_an_extended_gab
    auth_get_ok @john, "/gabs/#{@john.gabs.first.id}", {extended: true}
    extended = generate_gab_json @john.gabs.first, {}
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
