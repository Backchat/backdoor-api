class DataHelper

  def initialize(user)
    @user = user
  end

  def load_gender
    fb = @user.fb_data
    gpp = @user.gpp_data
    genders = ['male', 'female']

    if genders.include?(fb['gender'])
      return fb['gender']
    elsif genders.include?(gpp['gender'])
      return gpp['gender']
    else
      return nil
    end
  end

  def load_location
    fb = @user.fb_data
    gpp = @user.gpp_data

    if gpp['placesLived'].nil?
      gpp_place = nil
    else
      gpp_place = gpp['placesLived'].select{ |x| x['primary'] == '1' }[0]
    end

    if !fb['location'].nil? && !fb['location']['name'].nil?
      return fb['location']['name']
    elsif !gpp_place.nil?
      return gpp_place['value']
    else
      return nil
    end

  end

  def load_fb_family
    fb = @user.fb_data['family']

    return [] if !fb.kind_of?(Array)
    return fb.map { |x| x['id'] }
  end

  
  def load_gpp_schools
    gpp = @user.gpp_data

    ret = { :current => [], :all => [] }

    return ret if gpp['organizations'].nil?

    for item in gpp['organizations']
      next if item['type'] != 'school'
      name = item['name']
      ret[:current] << name if item['primary'] == true
      ret[:all] << name
    end

    ret 
  end

  def load_gpp_works
    gpp = @user.gpp_data['organizations']

    ret = { :current => [], :all => [] }

    return ret if gpp.nil?

    for item in gpp
      next if item['type'] != 'work'
      name = item['name']
      ret[:current] << name if item['primary'] == true
      ret[:all] << name
    end

    ret 
  end

  def load_fb_schools
    fb = @user.fb_data['education']
    ret = { :current => [], :all => [] }

    return ret if fb.nil?

    for item in fb.reverse
      name = item['school']['name']
      ret[:all] << name
      ret[:current] << name if ret[:current].empty?
    end

    ret
  end

  def load_fb_works
    fb = @user.fb_data['work']
    ret = { :current => [], :all => [] }

    return ret if fb.nil?

    for item in fb
      name = item['employer']['name']
      ret[:current] << name if item['end_date'].nil?
      ret[:all] << name
    end

    ret
  end

  def load_school
    gp = self.load_gpp_schools
    fb = self.load_fb_schools

    if gp[:current].count > 0
      return gp[:current][0]
    elsif fb[:current].count > 0
      return fb[:current][0]
    elsif fb[:all].count > 0
      return fb[:all][0]
    elsif gp[:all].count > 0
      return gp[:all][0]
    end
  end

  def load_work
    gp = self.load_gpp_works
    fb = self.load_fb_works
    if gp[:current].count > 0
      return gp[:current][0]
    elsif fb[:current].count > 0
      return fb[:current][0]
    end
  end


  def load_fb_likes
    fb = @user.fb_data['likes']

    ret = []

    return ret if fb.nil?

    for item in fb
      ret << '%s|%s' % ['https://graph.facebook.com/%s/picture?width=120&height=120' % item['id'], item['name']]
    end

    return ret
  end

  def load_fb_interests
    fb = @user.fb_data['interests']

    ret = []

    return ret if fb.nil?

    for item in fb
      ret << item['name']
    end

    return ret
  end

  def load_like
    likes = self.load_fb_likes
    return likes.sample
  end

  def load_likes
    return self.load_fb_likes
  end

  def load_work
    fb = @user.fb_data
    gpp = @user.gpp_data

    if !fb['work'].nil? && fb['work'].kind_of?(Array) && fb['work'].count > 0
      fb_work = fb['work'][0]
    else
      fb_work = nil
    end

    gpp_work = self.load_gpp_works[:current][0]

    if !fb_work.nil? && !fb_work['employer'].nil? && !fb_work['employer']['name'].nil?
      return fb_work['employer']['name']
    elsif !gpp_work.nil?
      return gpp_work
    end
  end

  def load_edu
    fb = @user.fb_data
    gpp = @user.gpp_data

    fb_edu = fb['education']
    if !fb_edu.nil? && fb_edu.kind_of?(Array)
      fb_edu = fb_edu[0]
    else
      fb_edu = nil
    end

    gpp_edu = self.load_gpp_schools[:current][0]

    if !fb_edu.nil? && !fb_edu['school'].nil? && !fb_edu['school']['name'].nil?
      return fb_edu['school']['name']
    else
      return gpp_edu
    end
  end

  def load_name
    fb_name = @user.fb_data['name']
    gpp_name = @user.gpp_data['displayName']
    return fb_name unless fb_name.blank?
    return gpp_name unless gpp_name.blank?
    return nil
  end

  def load
    ret = {}

    [:gender, :location, :work, :school, :likes, :name].each do |key|
      begin
        method = 'load_%s' % key
        ret[key] = self.send(method)
      rescue
        ActiveRecord::Base.logger.error $!.class.to_s + ': ' + $!.message
        ActiveRecord::Base.logger.error $!.backtrace.join("\n")
        ret[key] = nil
      end
    end
    ret
  end

  def avail_clues
    data = self.load

    avail_count = CLUES_MAX

    avail_likes = data[:likes]
    avail_clues = []

    [:gender, :location, :work, :school].each do |key|
      if !data[key].blank?
        if key == :gender
          file = data[key]
        elsif key == :school
          file = 'school_2'
        elsif key == :location
          file = 'city'
        elsif key == :work
          file = 'work'
        end

        url = '%sclue_%s@2x.png' % [BASE_URL, file]
        avail_clues << [key, '%s|%s' % [url, data[key]]]
      end
    end

    avail_likes.each do |like|
      break if avail_clues.length >= avail_count
      avail_clues << [:like, like]
    end

    return avail_clues
  end
end
