#!/usr/bin/env ruby

# == Synopsis
# 
# Twitter client
# 
# == Usage
#   ruby twit.rb [ -h | --help ] [ -r | --recent ] [ message ]
#   message::
#     Message to post
#   recent::
#     List recent
#
# == Installation
#
# You must do "gem install htmlentities" or "sudo gem install htmlentities"
#
# Your username and password are stored in ~/.twitter as a YAML file
#     ---
#     username: me
#     password: secret

require 'net/http'
require 'uri'
require 'yaml'
require 'getoptlong'
require 'rdoc/usage'
require 'test/unit/testcase'
require 'rexml/document'
require 'htmlentities'

class TwitterClient
  def initialize
    config = YAML.load_file("#{ENV['HOME']}/.twitter")
    @username = config["username"]
    @password = config["password"]
  end

  def status=(s)
    if s.length == 0
      puts "no message"
    elsif s.length > 140
      puts "too long message, #{s.length} chars"
    else
      puts "\"#{s}\" (#{s.length})"
      res = Net::HTTP.post_form(URI.parse("http://#{@username}:#{@password}@twitter.com/statuses/update.json"), { 'status' => s })
      case res
      when Net::HTTPSuccess, Net::HTTPRedirection
        # puts res.body
      else
        res.error!
      end
    end
  end

  def recent_xml
    Net::HTTP.start('twitter.com') { |http|
      req = Net::HTTP::Get.new("/statuses/friends_timeline.xml")
      req.basic_auth @username, @password
      response = http.request(req)
      # puts response.body
      return response.body
    }
  end
  
  def print_recent
    doc = REXML::Document.new recent_xml
    out = ""
    doc.elements.to_a("statuses/status").reverse.each { |status|
      coder = HTMLEntities.new
   
      screen_name = coder.decode(status.elements['user/screen_name'].text)
      created_at = coder.decode(status.elements['created_at'].text)
      text = coder.decode(status.elements['text'].text)
      col = 72
      text.gsub!(/(.{1,#{col}})( +|$\n?)|(.{1,#{col}})/, "\\1\\3\n") 
      
      out += "#{screen_name}, #{created_at}:\n#{text}\n"
    }
    puts out
  end
end

class TwitterTest < Test::Unit::TestCase
  class TwitterClient < TwitterClient
    # Don't test this
    def status=(s)
      return true
    end
  end
  
  def setup
  end
  
  def test_update_status
    tc = TwitterClient.new
    assert tc.status="hello"
  end
  
  def test_recent_xml_doesnt_get_authentication_error
    tc = TwitterClient.new
    res = tc.recent_xml
    assert res
    assert !(res =~ /<error>Could not authenticate you.<\/error>/), "Couldn't authenticate"
  end
end

tc = TwitterClient.new
if ARGV.length == 0 then require 'test/unit/ui/console/testrunner' else
  opts = GetoptLong.new(
    [ '--help', '-h', GetoptLong::NO_ARGUMENT ],
    [ '--recent', '-r', GetoptLong::NO_ARGUMENT ]
  )

  something = false
  opts.each do |opt, arg|
    case opt
      when '--help'
        RDoc::usage
        something = true
      when '--recent'
        tc.print_recent
        something = true
    end
  end
  if not something
    tc.status = ARGV.join(" ")
  end
end
