#!/usr/bin/env ruby
require 'rubygems'
require 'json'
require 'pp'
require 'time'
require 'date'
require 'mongo'
require 'parseconfig'
require 'getFlickrResponseTyphoeus'

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

db = Mongo::Connection.new(MONGO_HOST, MONGO_PORT.to_i).db(FLICKR_DB)
if MONGO_USER
  auth = db.authenticate(MONGO_USER, MONGO_PASSWORD)
  if !auth
    raise(StandardError, "Couldn't authenticate, exiting")
    exit
  end
end

extras_str = "date_upload, date_taken, owner_name,"+
             "icon_server, original_format, last_update, geo, tags,"+
             " machine_tags, o_dims, views, media, path_alias, url_sq,"+
             "url_t, url_s, url_q, url_m, url_n, url_z, url_c, url_l, url_o"

photosColl = db.collection("photos")
MIN_DATE = Time.local(ARGV[0].to_i, ARGV[1].to_i, ARGV[2].to_i, 0, 0) # may want Time.utc if you don't want local time
MAX_DATE = Time.local(ARGV[3].to_i, ARGV[4].to_i, ARGV[5].to_i, 23, 59) # may want Time.utc if you don't want local time

min_taken_date  = MIN_DATE
max_taken_date  = MIN_DATE + (60 * 60 * 24) - 1
search_url = "services/rest/"

$stderr.printf("min_taken:%s max_taken:%s\n", min_taken_date, max_taken_date)
while min_taken_date < MAX_DATE
  photos_to_retrieve = 250
  first_page = true
  photos_per_page = 0
  page = 1
  while photos_to_retrieve > 0
    url_params = {:method => "flickr.photos.search",
      :api_key => api_key,
      :format => "json",
      :nojsoncallback => "1", 
      :woe_id => "9807",
      :content_type => "7", # all: photos, videos, etc
      :per_page     => "250",
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
    $stderr.printf("STATUS from flickr API:%s retrieved page:%d of:%d\n", photos_on_this_page["stat"],
      photos_on_this_page["photos"]["page"].to_i, photos_on_this_page["photos"]["pages"].to_i)
    photos_on_this_page["photos"]["photo"].each do|photo|
      $stderr.printf("PHOTO datetaken from flickr API:%s\n", photo["datetaken"])
      skip = false
      begin
        datetaken = Time.parse(photo["datetaken"])
      rescue ArgumentError
        $stderr.printf("Parser EXCEPTION in date:%sSKIPPED\n",photo["datetaken"])
        skip = true
      end
      if skip 
        skip = false
        next
      end
      datetaken = datetaken.utc
      $stderr.printf("PHOTO datetaken:%s\n", datetaken)
      photo["datetaken"] = datetaken
      dateupload = Time.at(photo["dateupload"].to_i)
      $stderr.printf("PHOTO dateupload:%s\n", dateupload)
      photo["dateupload"] = dateupload
      lastupdate = Time.at(photo["lastupdate"].to_i)
      $stderr.printf("PHOTO lastupdate:%s\n", lastupdate)
      photo["lastupdate"] = lastupdate
      photo["tags_array"] = photo["tags"].split
      photo["id"] = photo["id"].to_i
      id = photo["id"]
      existingPhoto =  photosColl.find_one("id" => id)
      if existingPhoto
        $stderr.printf("UPDATING photo id:%d\n",id)
        photosColl.update({"id" =>id}, photo)
      else
        $stderr.printf("INSERTING photo id:%d\n",id)
        photosColl.insert(photo)
      end
    end
  end
  min_taken_date += (60 * 60 * 24)
  max_taken_date += (60 * 60 * 24)
end
