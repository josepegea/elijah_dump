# Utility methods for parsing data, Madrid.rb style

class String
  
  def parse_madrid_rb_time
    timereg = self.match(/(hora|time)\:\s*(\d+\:\d+)h?/i)
    return $2
  end

  def parse_madrid_rb_venue
    venue = nil
    venuereg = self.match(/(lugar|venue)\:\s*(.*)/i)
    if $2
      venue = $2.gsub(/\s*\(mapa\)\s*/i, '')
    end
    return venue
  end
  
end

