#!/usr/bin/ruby

require 'net/http'
require 'rexml/document'
require 'pp'
require 'date'

def max( a, b, c )
  a = a.attributes["percent"].to_f
  b = b.attributes["percent"].to_f
  c = c.attributes["percent"].to_f
  return ( a > b ? ( a > c ? a : c ) : ( b > c ? b : c ) )
end

def cloudinesspredictions( latitude, longitude )
  url = "http://api.yr.no/weatherapi/locationforecastlts/1.1/?lat=#{latitude};lon=#{longitude}"
  xml_data = Net::HTTP.get_response(URI.parse(url)).body
  doc = REXML::Document.new(xml_data)
  predictions = {}
  REXML::XPath.each(doc, "//time") do |e| 
    location = REXML::XPath.first( e, "location")
    if location
      lowclouds = REXML::XPath.first( location, "lowClouds")
      mediumclouds = REXML::XPath.first( location, "mediumClouds")
      highclouds = REXML::XPath.first( location, "highClouds")
      if lowclouds && mediumclouds && highclouds
        predictions[ DateTime.parse( e.attributes[ "from" ] ).strftime( '%s' ).to_i ] = max( lowclouds, mediumclouds, highclouds )
      end
    end
  end
  return predictions
end

def predictcloudiness( predictions, time )
  time = time.strftime( '%s' ).to_i
  beforeprediction = nil
  beforetime = ( DateTime.now - (30/24.0) ).strftime( '%s' ).to_i
  afterprediction = nil
  aftertime = ( DateTime.now + (30/24.0) ).strftime( '%s' ).to_i
  
  predictions.each do | t, p |
    if t < time
      if t > beforetime
        beforetime = t
        beforeprediction = p
      end
    elsif t > time
      if t < aftertime
        aftertime = t
        afterprediction = p
      end
    end
  end
  if( afterprediction && beforeprediction )
    befored = ( time - beforetime )
    afterd = ( aftertime - time )
    prediction = ( ( afterprediction * befored ) + ( beforeprediction * afterd ) ) / ( befored + afterd )
    return prediction.round.to_s + "%"
  else
    return "unknown"
  end
end

cloudpredictions = cloudinesspredictions( 51.1933422, 4.4878212 )
puts predictcloudiness( cloudpredictions, DateTime.now + (1/24.0) )
