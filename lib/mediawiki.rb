#!/usr/bin/env ruby

require 'uri'

require 'mediawiki/article'
require 'mediawiki/minibrowser'

module MediaWiki
  class Wiki
    attr_accessor :browser
  
    def initialize(url, user = nil, password = nil)
      #if url.class == Symbol
      #  config = YAML.load_file("#{ENV['HOME']}/.mediawikirc")[url.to_s]
      #  url = config['url']
      #  user = config['user'] unless user
      #  password = config['password'] unless password
      #end

      @url = URI.parse( url.match(/\/$/) ? url : url + '/' )
      @browser = MiniBrowser.new(@url)
      login( user, password ) if user and password
    end

    def login( username, password )
      data = {'wpName' => username, 'wpPassword' => password, 'wpLoginattempt' => 'Log in'}
      data = @browser.post_content( @url.path + 'index.php?title=Special:Userlogin&action=submitlogin', data )
      if data =~ /<p class='error'>/
        raise "Unable to authenticate as #{username}"
      end
    end

    def article(name, section = nil)
      Article.new(self, name, section)
    end

    def article_url(name, section = nil)
      "#{@url.path}index.php?title=#{CGI::escape(name)}#{section ? "&section=#{CGI::escape(section.to_s)}" : ''}"
    end

  end

end

