require 'rubygems'
require 'typhoeus'
def getFlickrResponse(url, params)
  url = "api.flickr.com/" + url
  result = Typhoeus::Request.get(url,
             :params => params )
  return JSON.parse(result.body)
end
