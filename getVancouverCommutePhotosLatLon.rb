#!/usr/bin/env ruby
require 'json'
require 'pp'
require 'time'
require 'date'
require 'mongo'
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
query = {}
metrics_start = Time.utc(ARGV[0], ARGV[1], ARGV[2], 0, 0)
metrics_stop = Time.utc(ARGV[3], ARGV[4], ARGV[5], 23, 59, 59)
metrics_stop += 1
query = {"datetaken" => {"$gte" => metrics_start, "$lt" => metrics_stop}}
query["woeid"] =  {"$in" => ["26332807","26332813","9807","23404908",
"55855889","26332808","26332809","23404939","23404944","26332811","23405256",
"23404951","23404960","55855888","23405264","55855887","26332812","23404977",
"23404979","55855620","55998921","23405270","23405266","23404994"]
}

photosColl.find(query,
                  :fields => ["woeid", "latitude", "longitude", "datetaken"]
                ).sort([["datetaken", Mongo::ASCENDING]]).each do |p|
  datetaken_local = p["datetaken"].getlocal
  wday = datetaken_local.wday
  hour = datetaken_local.hour
  if (wday > 0  && wday < 6) && ((hour > 6 && hour < 11) || (hour > 14 && hour < 19))
    printf("[%s,%s],\n",  p["latitude"].to_s, p["longitude"].to_s)
  end
  # $stderr.printf("photo datetaken:%s, lat:%s, lon:%s\n", p["datetaken"].to_s, p["latitude"].to_s, p["longitude"].to_s)  
end


