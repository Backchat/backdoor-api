class DataClue
  attr_accessor :display
  attr_accessor :url
  attr_accessor :kind

  def value
    "#{@url}|#{@display}"
  end

  class << self
    def simple_clue(kind, display)
      c = DataClue.new
      c.kind = kind

      if kind == :gender
        file = display
        display = display.upcase
      elsif kind == :school
        file = 'school_2'
      elsif kind == :location
        file = 'city'
      elsif kind == :work
        file = 'work'
      end

      c.display = display
      c.url = '%s/clue_%s@2x.png' % [BASE_URL, file]

      return c
    end

    def custom_clue(kind, display, url)
      c = DataClue.new
      c.kind = :like
      c.display =display
      c.url = url
      return c
    end
  end
end

class FBClueGenerator
  attr_accessor :gender, :schools, :orgs, :likes, :interests, :current_work, :current_school, :current_location

  def initialize(fb_data)
    @data = fb_data

    unless @data.nil? || @data.empty?
      load_gender
      load_current_location
      load_orgs
      load_likes
    end
  end

  def load_gender
    genders = ['male', 'female']

    if genders.include?(@data['gender'])
      @gender = DataClue.simple_clue(:gender, @data['gender'])
    end
  end

  def load_current_location
    if !@data['location'].nil? && !@data['location']['name'].nil?
      @location = DataClue.simple_clue(:location, @data['location']['name'])
    end
  end

  def load_orgs
    @schools = { :current => [], :all => [] }
    @orgs = { :current => [], :all => [] }
    edu = @data['education']
    unless edu.nil? || edu.empty?
      for item in edu.reverse
        name = item['school']['name']
        @schools[:all] << name
        @schools[:current] << name if @schools[:current].empty?
      end

      @current_school = DataClue.simple_clue(:school, @schools[:current].first) unless @schools[:current].empty?
    end

    work = @data['work']
    unless work.nil? || work.empty?
      for item in work
        name = item['employer']['name']
        @orgs[:current] << name if item['end_date'].nil?
        @orgs[:all] << name
      end

      @current_work = DataClue.simple_clue(:work, @orgs[:current].first) unless @orgs[:current].empty?
    end
  end

  def load_likes
    likes = @data['likes']
    @likes = []
    unless likes.nil? || likes.empty?
      @likes = likes.map {|like|
        DataClue.custom_clue(:like, like['name'],
                         'https://graph.facebook.com/%s/picture?width=120&height=120' % like['id'])}
    end

    @likes.shuffle
  end

end

class GPPClueGenerator
  attr_accessor :gender, :schools, :orgs, :current_work, :current_school, :current_location

  def initialize(gpp_data)
    @data = gpp_data

    unless @data.nil? || @data.empty?
      load_gender
      load_current_location
      load_orgs
    end
  end

  def load_gender
    genders = ['male', 'female']

    if genders.include?(@data['gender'])
      @gender = DataClue.simple_clue(:gender, @data['gender'])
    end
  end

  def load_current_location
    unless @data['placesLived'].nil?
      current_loc = @data['placesLived'].select{ |x|  x['primary'] || x['primary'] == '1' }[0]
      @current_location = DataClue.simple_clue(:location, current_loc['value']) unless current_loc.nil? || current_loc['value'].nil? || current_loc['value'].empty?
    end
  end

  def load_orgs
    @schools = { :current => [], :all => [] }
    @orgs = { :current => [], :all => [] }
    unless @data['organizations'].nil?
      for item in @data['organizations']
        name = item['name']

        if item['type'] == 'school'
          @schools[:current] << name if item['primary']
          @schools[:all] << name
        elsif item['type'] == 'work'
          @orgs[:current] << name if item['primary']
          @orgs[:all] << name
        end
      end
    end

    @current_school = DataClue.simple_clue(:school, @schools[:current].first) unless @schools[:current].empty?
    @current_work = DataClue.simple_clue(:work, @orgs[:current].first) unless @orgs[:current].empty?
  end
end

class DataHelper

  def initialize(user)
    @user = user
  end

  def avail_clues
    fb = FBClueGenerator.new(@user.fb_data)
    gpp = GPPClueGenerator.new(@user.gpp_data)

    avail_count = CLUES_MAX

    avail_clues =
      [fb.gender || gpp.gender,
       fb.current_location || gpp.current_location,
       fb.current_work || gpp.current_work,
       fb.current_school || gpp.current_school].compact

    all_clues = avail_clues + (fb.likes||[])

    return all_clues.shuffle[0,CLUES_MAX]
  end
end
