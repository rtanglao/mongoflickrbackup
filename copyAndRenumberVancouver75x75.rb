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
require 'fileutils'

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

def copy_photos_and_make_symlink(urls)
  urls.each_with_index do|url, i|
    uri = URI.parse(url)
    filename = uri.path.rpartition('/')[2]
    renumbered_filename = sprintf("%6.6d", i + 1) + ".jpg"
    $stderr.printf("cp ../%s %s\n", filename, renumbered_filename)
    FileUtils.cp("../" + filename, renumbered_filename)
  end
end

urls = []
query = {}
query["woeid"] =  {"$in" => ["26332807","26332813","9807","23404908",
"55855889","26332808","26332809","23404939","23404944","26332811","23405256",
"23404951","23404960","55855888","23405264","55855887","26332812","23404977",
"23404979","55855620","55998921","23405270","23405266","23404994"]
}

photosColl.find(query,
                  :fields => ["datetaken", "url_sq", "id", "woeid"]
                ).sort([["datetaken", Mongo::ASCENDING]]).each do |p|
  $stderr.printf("photo:%d, datetaken:%s\n", p["id"], p["datetaken"].to_s)
  url = p["url_sq"]
  urls.push(url)
end

copy_photos_and_make_symlink(urls)

