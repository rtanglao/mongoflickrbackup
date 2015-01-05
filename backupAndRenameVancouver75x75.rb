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

def  renumber(filename, file_number)
  renumbered_filename = sprintf("RENUMBERED/%6.6d", file_number) + ".jpg"
  $stderr.printf("ln -s %s %s\n", filename, renumbered_filename)
  File.symlink("../" + filename, renumbered_filename)
end

def fetch_1_at_a_time(urls)

  easy = Curl::Easy.new
  easy.follow_location = true
  file_number = 0

  urls.each do|url|
    easy.url = url
    uri = URI.parse(url)
    filename = uri.path.rpartition('/')[2]
    $stderr.print "filename:'#{filename}'"
    $stderr.print "url:'#{url}' :"
    if File.exist?(filename)
      $stderr.printf("skipping EXISTING filename:%s\n", filename)
      file_number += 1
      renumber(filename, file_number)
      next
    end
    try_count = 0
    begin
      File.open(filename, 'wb') do|f|
        easy.on_progress {|dl_total, dl_now, ul_total, ul_now| $stderr.print "="; true }
        easy.on_body {|data| f << data; data.size }   
        easy.perform
        $stderr.puts "=> '#{filename}'"
      end
    rescue Curl::Err::ConnectionFailedError => e
      try_count += 1
      if try_count < 4
        $stderr.printf("Curl:ConnectionFailedError exception, retry:%d\n",\
                       try_count)
        sleep(10)
        retry
      else
        $stderr.printf("Curl:ConnectionFailedError exception, retrying FAILED\n")
        raise e
      end
    end
    file_number += 1
    renumber(filename, file_number)
  end
end

urls = []
query = {}
metrics_start = Time.utc(ARGV[0], ARGV[1], ARGV[2], 0, 0)
metrics_stop = Time.utc(ARGV[3], ARGV[4], ARGV[5], 23, 59, 59)
metrics_stop += 1
query = {"datetaken" => {"$gte" => metrics_start, "$lt" => metrics_stop}}

photosColl.find(query,
                  :fields => ["datetaken", "url_sq", "id", "cityphototaken"]
                ).sort([["datetaken", Mongo::ASCENDING]]).each do |p|
  $stderr.printf("photo:%d, datetaken:%s\n", p["id"], p["datetaken"].to_s)
  if p["cityphototaken"] == "vancouver.bc.canada"
    $stderr.printf("pushing url_sq\n")
    urls.push(p["url_sq"]) if !p["url_sq"].nil?
  end
end

$stderr.printf("FETCHING:%d 75x75 thumbnails\n", urls.length)

fetch_1_at_a_time(urls)

