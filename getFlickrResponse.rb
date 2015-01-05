require 'rubygems'
require 'pp'
require 'nestful'

def getFlickrResponse(url, params)
  url = "api.flickr.com/" + url
  return Nestful.get url, :format => :json, :params => params
end
