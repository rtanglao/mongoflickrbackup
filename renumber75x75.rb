#!/usr/bin/env ruby
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

db = Mongo::Connection.new(MONGO_HOST, MONGO_PORT.to_i).db(FLICKR_DB)
if MONGO_USER
  auth = db.authenticate(MONGO_USER, MONGO_PASSWORD)
  if !auth
    raise(StandardError, "Couldn't authenticate, exiting")
    exit
  end
end

photosColl = db.collection("photos")

def renumber_photos_and_make_symlink(urls)
  urls.each_with_index do|url, i|
    uri = URI.parse(url)
    filename = uri.path.rpartition('/')[2]
    renumbered_filename = sprintf("%6.6d", i + 1) + ".jpg"
    $stderr.printf("ln -s ../%s %s\n", filename, renumbered_filename)
    File.symlink("../" + filename, renumbered_filename)
  end
end

urls = []
photosColl.find({},
                  :fields => ["datetaken", "url_sq", "id"]
                ).sort([["datetaken", Mongo::ASCENDING]]).each do |p|
  $stderr.printf("photo:%d, datetaken:%s\n", p["id"], p["datetaken"].to_s)
  url = p["url_sq"]
  urls.push(url)
end

renumber_photos_and_make_symlink(urls)

