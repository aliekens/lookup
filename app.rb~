require 'rubygems'
require 'sinatra'
require 'open-uri'
require 'hpricot'
require 'pp'
require 'date'
require 'active_support/all'
require 'net/http'
require 'rexml/document'

#require 'sinatra/reloader'

require 'geonames'

def cloudinesspredictions( latitude, longitude )
  url = "http://api.yr.no/weatherapi/locationforecastlts/1.1/?lat=#{latitude};lon=#{longitude}"
  xml_data = Net::HTTP.get_response(URI.parse(url)).body
  doc = REXML::Document.new(xml_data)
  predictions = {}
  REXML::XPath.each(doc, "//time") do |e| 
    location = REXML::XPath.first( e, "location")
    if location
      clouds = REXML::XPath.first( location, "cloudiness")
      if clouds
        predictions[ DateTime.parse( e.attributes[ "from" ] ).strftime( '%s' ).to_i ] = clouds.attributes["percent"].to_f
      end
    end
  end
  return predictions
end

def predictcloudiness( predictions, time )
  time = time.strftime( '%s' ).to_i
  beforeprediction = nil
  beforetime = ( DateTime.now - (30*24/24.0) ).strftime( '%s' ).to_i
  afterprediction = nil
  aftertime = ( DateTime.now + (30*24/24.0) ).strftime( '%s' ).to_i
  
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
    return prediction.round
  else
    return -1
  end
end

class Flyby
  attr_accessor :date, :starttime, :startdatetime, :endtime, :enddatetime, :magnitude, :location, :url, :description, :duration
end

def getFlybys( latitude, longitude )

  months = [ "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" ]

  flybys = []
  url = "http://www.heavens-above.com/PassSummary.aspx?lat=#{latitude}&lng=#{longitude}&satid=25544"
  doc = Hpricot( open( url, 'User-Agent' => 'http://lookup.liekens.net' ) )
  counter = 0
  # select the table that contains the flybys
  require 'pp'
  table = (doc/".standardTable")
  rows = table/"tr"
  if (table/"tr").at("td")['class'] != 'address'
    rows.each do |row| # each row contains a prediction ...
      if row.attributes[ "class" ] != "tablehead" # unless the row contains header information

        fields = []
      
        (row/"td").each do |field| 
          if (field/"a").size > 0
            element = field.at "a"
            fields << element.inner_html.strip # fields[ 0 ] = date of flyby
            fields << "http://www.heavens-above.com/" + element['href'].strip # link to more info on heavens-above.com
          else
            fields << field.inner_html.strip
          end
        end

        flyby = Flyby.new

        # extract all the information that is hidden in the table row

        year = Date.today.year
        if fields[ 0 ] != "Chris Peat"
          
          month = months.index( fields[ 0 ].split( " " )[ 1 ] ) + 1
          if month == 1 && Date.today.month == 12 # if the predicted year is in the beginning of january, but we're still december ...
            year = year + 1
          end
          if month < 10
            month = "0" + month.to_s
          end
          day = fields[ 0 ].split( " " )[ 0 ].to_i
          if day < 10
            day = "0" + day.to_s
          end 
          flyby.date = "#{year}#{month}#{day}"
        
          flyby.starttime = fields[ 3 ].gsub(/:/, "")
          hour = fields[ 3 ].split(":")[ 0 ]
          minute = fields[ 3 ].split(":")[ 1 ]
          second = fields[ 3 ].split(":")[ 2 ]
          flyby.startdatetime = DateTime.new(year,month.to_i,day.to_i,hour.to_i,minute.to_i,second.to_i)
          flyby.endtime = fields[ 9 ].gsub(/:/, "")
          hour = fields[ 9 ].split(":")[ 0 ]
          minute = fields[ 9 ].split(":")[ 1 ]
          second = fields[ 9 ].split(":")[ 2 ]
          flyby.enddatetime = DateTime.new(year,month.to_i,day.to_i,hour.to_i,minute.to_i,second.to_i)
          flyby.duration = ( ( flyby.enddatetime - flyby.startdatetime ) * 24 * 60 ).to_i
          flyby.magnitude = fields[ 2 ]
          flyby.url = fields[ 1 ].gsub( /\&[Tt][Zz]=[^\&]*/, "" )
          flyby.description = flyby.url
          flyby.location = "#{fields[4]}#{fields[5]} - #{fields[7]}#{fields[8]} - #{fields[10]}#{fields[11]}"

          flybys << flyby
          
        end

      end
      
    end
  
  end 
  
  return flybys

end

get '/' do
  erb :index
end

helpers do
  def cloudiness( cloudpredictions, datetime )
    return predictcloudiness( cloudpredictions, datetime )
  end
end

get '/flybys' do
  @latitude = params[ 'lat' ]
  @latitude = 51.2 if !@latitude
  @longitude = params[ 'lng' ]
  @longitude = 4.4830 if !@longitude
  
  @timezone = Geonames::WebService.timezone @latitude, @longitude
  @nearby = ( Geonames::WebService.find_nearby_place_name @latitude, @longitude ).first
  
  @flybys = getFlybys( @latitude, @longitude )
  
  @cloudpredictions = cloudinesspredictions( @latitude, @longitude )
  
  erb :flybys
end

get '/iss.ics' do
  
  @latitude = params[ 'lat' ]
  @latitude = 51.2 if !@latitude
  @longitude = params[ 'lng' ]
  @longitude = 4.4830 if !@longitude
  
  flybys = getFlybys( @latitude, @longitude )
  
  if params['alarm'] && params['alarmtime']
    @alarm = ( params[ 'alarm' ] == "on" )
    @alarmtime = params[ 'alarmtime' ]
  end
  
  @maximumMagnitude = 0
  if params[ 'mag']
    @maximumMagnitude = params[ 'mag' ].to_f
  end
  
  @results = getFlybys( @latitude, @longitude )

  headers 'Content-Type' => 'text/calendar'
  erb :calendar, :layout => false
  
end

