#!/usr/bin/env ruby
require 'rubygems'
require 'json'
require 'pp'
require 'time'
require 'date'
require 'mongo'
require 'parseconfig'
require 'getFlickrResponse'

flickr_config = ParseConfig.new('flickr.conf').params
api_key = flickr_config['api_key']

if ARGV.length < 6
  puts "usage: #{$0} yyyy mm dd yyyy mmm dd -v"
  exit
end

MONGO_HOST = ENV["MONGO_HOST"]
raise(StandardError,"Set Mongo hostname in ENV: 'MONGO_HOST'") if !MONGO_HOST
MONGO_PORT = ENV["MONGO_PORT"]
raise(StandardError,"Set Mongo port in ENV: 'MONGO_PORT'") if !MONGO_PORT
MONGO_USER = ENV["MONGO_USER"]
# raise(StandardError,"Set Mongo user in ENV: 'MONGO_USER'") if !MONGO_USER
MONGO_PASSWORD = ENV["MONGO_PASSWORD"]
# raise(StandardError,"Set Mongo user in ENV: 'MONGO_PASSWORD'") if !MONGO_PASSWORD
FLICKR_DB = ENV["FLICKR_DB"]
raise(StandardError,"Set Mongo flickr database name in ENV: 'FLICKR_DB'") if !FLICKR_DB
FLICKR_USER = ENV["FLICKR_USER"]
raise(StandardError,"Set flickr user name in ENV: 'FLICKR_USER'") if !FLICKR_USER

db = Mongo::Connection.new(MONGO_HOST, MONGO_PORT.to_i).db(FLICKR_DB)
if MONGO_USER
  auth = db.authenticate(MONGO_USER, MONGO_PASSWORD)
  if !auth
    raise(StandardError, "Couldn't authenticate, exiting")
    exit
  end
end

extras_str = "description, license, date_upload, date_taken, owner_name, icon_server,"+
             "original_format, last_update, geo, tags, machine_tags, o_dims, views,"+
             "media, path_alias, url_sq, url_t, url_s, url_m, url_z, url_l, url_o"

photosColl = db.collection("photos")
# from first date to last date do

photos_to_retrieve = 250
first_page = true
photos_per_page = 0
page = 1
MIN_DATE = Time.local(ARGV[0].to_i, ARGV[1].to_i, ARGV[2].to_i, 0, 0) # may want Time.utc if you don't want local time
MAX_DATE = Time.local(ARGV[3].to_i, ARGV[4].to_i, ARGV[5].to_i, 23, 59) # may want Time.utc if you don't want local time

min_taken_date  = MIN_DATE
max_taken_date  = MIN_DATE + (60 * 60 * 24) - 1
$stderr.printf("min_taken:%s max_taken:%s\n", min_taken_date, max_taken_date)
while min_taken_date < MAX_DATE
  while photos_to_retrieve > 0
    search_url = "services/rest/"
    url_params = {:method => "flickr.photos.search",
      :api_key => api_key,
      :format => "json",
      :nojsoncallback => "1", 
      :content_type => "7", # all: photos, videos, etc
      :per_page     => "250",
      :user_id => FLICKR_USER, 
      :extras =>  extras_str,
      :sort => "date-taken-asc", 
      :page => page.to_s,
      :min_taken_date => min_taken_date.to_i.to_s,
      :max_taken_date => max_taken_date.to_i.to_s 
    }
    photos_on_this_page = getFlickrResponse(search_url, url_params)
    if first_page
      first_page = false
      photos_per_page = photos_on_this_page["photos"]["perpage"].to_i
      photos_to_retrieve = photos_on_this_page["photos"]["total"].to_i - photos_per_page
    else
      photos_to_retrieve -= photos_per_page
    end
    page += 1
    PP::pp(photos_on_this_page, $stderr)
    # print JSON.generate(photos_on_this_page), "\n"
  end
  min_taken_date += (60 * 60 * 24)
  max_taken_date += (60 * 60 * 24)
end
