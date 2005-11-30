#!/usr/bin/env ruby

require 'uri'

require 'mediawiki/article'
require 'mediawiki/minibrowser'

module MediaWiki
  class Wiki
    attr_accessor :browser
  
    def initialize(url)
      @url = URI.parse( url.match(/\/$/) ? url : url + '/' )
      @browser = MiniBrowser.new(@url.host, @url.user, @url.password)
    end

    def login( username, password )
      data = {'wpName' => username, 'wpPassword' => password, 'wpLoginattempt' => 'Log in'}
      data = @browser.post_content( @url.path + 'index.php?title=Special:Userlogin&action=submitlogin', data )
      if data =~ /<p class='error'>/
        raise "Unable to authenticate as #{username}"
      end
    end

    def article(name)
      Article.new(self, name)
    end

    def article_url(name)
      "#{@url.path}index.php?title=#{CGI::escape(name)}"
    end

  end

end

