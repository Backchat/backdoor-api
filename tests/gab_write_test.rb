require 'test_helper.rb'

class GabWriteTest  < BackdoorTestCase
  #write tests

  def test_tagging_a_gab
    a_gab = @mary.gabs.order("random()").first
    auth_post_ok @mary, "/gabs/#{a_gab.id}", {related_user_name: "acat"}
    a_gab.reload
    assert a_gab.related_user_name == "acat", "POST to gab refused to set related user name"
    assert_json_match response_ok(generate_gab_json(a_gab, {})), last_response.body
  end

  def test_delete_a_gab
    auth_delete_ok @mary, "/gabs/#{@mary.gabs.first.id}"
    #TODO: no deleted mark on gab, we can only check messaages (which would be empty)
    auth_get_ok @mary, "/gabs/#{@mary.gabs.first.id}/messages"
    assert_json_match response_ok({messages: []}), last_response.body
  end

  def test_post_a_gab
    params = {
      receiver: {
        id: @mary.id
      },
      message: generate_message_param
    }
    auth_post_ok @john, "/gabs", params

    opt = {
      related_avatar: @mary.avatar_url,
      related_phone: '',
      related_user_name: '',
      total_count: 1,
      unread_count: 0,
      sent: true,
      clue_count: wildcard_matcher,
      id: :gab_id,
      content_cache: wildcard_matcher,
      content_summary: wildcard_matcher
    }
    match = assert_json_match response_ok(generate_gab_json(nil, opt)), last_response.body
  end

  def test_post_message
    j_gab = @john.gabs.first
    p = generate_message_param("t", 0, "123")
    auth_post_ok @john, "/gabs/#{j_gab.id}/messages", p
    result_hash = {
      message: {
        content: :content,
        kind: :kind,
        key: :key
      }.ignore_extra_keys!
    }
    match = assert_json_match response_ok(result_hash), last_response.body
    [:content, :kind, :key].each do |key|
      assert match.captures[key] == p[key], "post message returned value #{match.captures[key]} for #{key} instead of #{p[key]}"
    end
  end

  def test_post_message_puts_at_top
    j_gab = @john.gabs.first

    auth_post_ok @john, "/gabs/#{j_gab.id}/messages", generate_message_param("1")
    auth_get_ok @john, "/gabs/#{j_gab.id}/messages"
    match = assert_json_match response_ok({messages: [{content: :content_1}.ignore_extra_keys!].ignore_extra_values!}), last_response.body
    assert match.captures[:content_1] == "1", "posting a message doesn't put it at the top"

    auth_post_ok @john, "/gabs/#{j_gab.id}/messages", generate_message_param("2")
    auth_get_ok @john, "/gabs/#{j_gab.id}/messages"
    two_messages = {messages: [{content: :content_2}.ignore_extra_keys!, {content: :content_1}.ignore_extra_keys!].ignore_extra_values!}
    match = assert_json_match response_ok(two_messages), last_response.body
    assert match.captures[:content_1] == "1" && match.captures[:content_2] == "2", "posting a message doesn't put it at the top"
  end

  def test_post_message_updates_counts
    j_gab = @john.gabs.first
    count = j_gab.total_count
    unread_count = j_gab.unread_count
    m_gab = j_gab.related_gab
    m_count = m_gab.total_count
    m_unread_count = m_gab.unread_count

    auth_post_ok @john, "/gabs/#{j_gab.id}/messages", generate_message_param

    j_gab.reload
    m_gab.reload

    assert j_gab.total_count == count + 1, "writing a message doesn't update the total count"
    assert j_gab.unread_count == unread_count, "writing a message as a sender changes the sender's unread count"
    assert m_gab.total_count == m_count + 1 ,"writing a message doesn't update the receiver's total count"
    assert m_gab.unread_count == m_unread_count + 1, "writing a message doesn't update the receivers' unread count by 1"
  end
    
  def test_delete_a_message
    auth_delete @john, "/gabs/#{@john.gabs.first.id}/messages/#{@john.gabs.first.messages.first.id}"
    assert !last_response.ok?
  end

  def test_order_of_gabs_are_updated
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
    match = assert_json_match response_ok({gab: {id: :gab_id}.ignore_extra_keys!}), last_response.body
    id = match.captures[:gab_id]
    
    #check that it's at the top
    auth_get_ok @john, "/gabs"
    match = assert_json_match response_ok({gabs: [{id: :gab_id}.ignore_extra_keys!, {id: :gab_2_id}.ignore_extra_keys!].ignore_extra_values!}), last_response.body
    gab_2_id = match.captures[:gab_2_id]
    assert match.captures[:gab_id] == id, "posting a new gab does not push it to the top"

    auth_post_ok @john, "/gabs/#{gab_2_id}/messages", {content: "A new message to pop to top", kind: 0}
    
    #check the new one is pushed to the top
    auth_get_ok @john, "/gabs"
    match = assert_json_match response_ok({gabs: [{id: :gab_id}.ignore_extra_keys!, {id: :gab_2_id}.ignore_extra_keys!].ignore_extra_values!}), last_response.body
    
    assert match.captures[:gab_id] == gab_2_id, "posting a message to an existing gab does not push it to the top"
  end

  def test_request_a_clue
    j_gab = @john.gabs.where("related_user_name != 'backdoor'").first
    m_gab = j_gab.related_gab #only the related gab has clues
    clue = m_gab.clues.order("RANDOM()").first
    old_available = @mary.available_clues
    auth_post_ok @mary, "/gabs/#{m_gab.id}/clues/request/#{clue.number}"
    clue_json = {
      clue: {
        id: clue.id,
        gab_id: m_gab.id,
        field: clue.field,
        value: clue.value,
        number: clue.number
      }
    }
    assert_json_match response_ok(clue_json), last_response.body
    assert @mary.available_clues == old_available -1, "mary's clues available did not go down by 1"
  end

end
