require 'test_helper.rb'

class ClueTest < BackdoorTestCase
  def test_clue_creations
    assert @mary.available_clues == CLUES_DEFAULT, "buying purchase via ruby didn't work"
    assert @mary.gabs.first.clue_count == 2, "related gab created via my_create didn't get 2 clues from fb_data"
  end

end
