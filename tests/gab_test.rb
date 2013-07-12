# test gab CRUD endpoints
require 'test_helper.rb'

class GabTest < BackdoorTestCase

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
      @john.gabs.all.map {|g| generate_gab_json(g, {})[:gab]}.ordered!
    }
    assert_json_match response_ok(gabs), last_response.body
  end

  def test_get_a_gab
    auth_get_ok @john, "/gabs/#{@john.gabs.first.id}"
    assert_json_match response_ok(generate_gab_json(@john.gabs.first,{})), last_response.body
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

end
