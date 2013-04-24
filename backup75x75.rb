#!/usr/bin/env ruby
require 'rubygems'
require 'json'
require 'curb'
require 'pp'
require 'time'
require 'date'
require 'mongo'
require 'parseconfig'
require 'uri'

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

photosColl = db.collection("photos")

def fetch_1_at_a_time(urls)

  easy = Curl::Easy.new
  easy.follow_location = true

  urls.each do|url|
    easy.url = url
    uri = URI.parse(url)
    filename = uri.path.rpartition('/')[2]
    $stderr.print "filename:'#{filename}'"
    $stderr.print "url:'#{url}' :"
    if File.exist?(filename)
      $stderr.printf("skipping EXISTING filename:%s\n", filename)
      next
    end
    File.open(filename, 'wb') do|f|
      easy.on_progress {|dl_total, dl_now, ul_total, ul_now| $stderr.print "="; true }
      easy.on_body {|data| f << data; data.size }   
      easy.perform
      $stderr.puts "=> '#{filename}'"
    end
  end
end

urls = []
photosColl.find({},
                  :fields => ["datetaken", "url_sq", "id"]
                ).sort([["datetaken", Mongo::ASCENDING]]).each do |p|
  $stderr.printf("photo:%d, datetaken:%s\n", p["id"], p["datetaken"].to_s)
  urls.push(p["url_sq"]) if !p["url_sq"].nil?
end

$stderr.printf("FETCHING:%d 75x75 thumbnails\n", urls.length)

fetch_1_at_a_time(urls)

