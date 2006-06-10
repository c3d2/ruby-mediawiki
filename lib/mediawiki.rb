##
# =Ruby-MediaWiki - manipulate MediaWiki pages from Ruby.
#
# Please note that documents spit out by MediaWiki *must* be valid
# XHTML (or XML)!
#
# You may not want to use MediaWiki::Wiki directly but let MediaWiki.dotfile
# create your instance. This gives you the power of the dotfile
# infrastructure. See sample apps and <tt>mediawikirc.sample</tt>.

require 'uri'
require 'logger'


# Logger is required by article.rb
module MediaWiki
  def self.logger
    if defined? @@logger
      @@logger
    else
      @@logger = Logger.new(STDERR)
    end
  end
end

require 'mediawiki/article'
require 'mediawiki/specialpage'
require 'mediawiki/category'
require 'mediawiki/minibrowser'

module MediaWiki
  class Wiki
    ##
    # The MiniBrowser instance used by this Wiki.
    # This must be readable as it's used by Article and Category
    # to fetch themselves.
    attr_reader :browser 

    ##
    # Initialize a new Wiki instance.
    # url:: [String] URL-Path to index.php (without index.php), may containt <tt>user:password</tt> combination.
    # user:: [String] If not nil, log in with that MediaWiki username (see Wiki#login)
    # password:: [String] If not nil, log in with that MediaWiki password (see Wiki#login)
    # loglevel:: [Integer] Loglevel, default is to log all messages >= Logger::WARN = 2
    def initialize(url, user = nil, password = nil, loglevel = Logger::WARN)

      if ENV['MEDIAWIKI_DEBUG']
        MediaWiki::logger.level = Logger::DEBUG
      else 
        MediaWiki::logger.level = loglevel
      end
      
      @url = URI.parse( url.match(/\/$/) ? url : url + '/' )
      @browser = MiniBrowser.new(@url)

      login( user, password ) if user and password
    end

    ##
    # Log in into MediaWiki
    #
    # This is *not* HTTP authentication
    # (put HTTP-Auth into [url] of Wiki#initialize!)
    # user:: [String] MediaWiki username
    # password:: [String] MediaWiki password
    #
    # May raise an exception if cannot authenticate
    def login( username, password )
      data = {'wpName' => username, 'wpPassword' => password, 'wpLoginattempt' => 'Log in'}
      data = @browser.post_content( @url.path + 'index.php?title=Special:Userlogin&action=submitlogin', data )
      if data =~ /<p class='error'>/
        raise "Unable to authenticate as #{username}"
      end
    end

    ##
    # Return a new Category instance with given name,
    # will be constructed with [self] (for MiniBrowser usage)
    # name:: [String] Category name (to be prepended with "Category:")
    def category(name)
      Category.new(self, name)
    end

    ##
    # Return a new Article instance with given name,
    # will be constructed with [self] (for MiniBrowser usage)
    # name:: [String] Article name
    # section:: [Fixnum] Optional section number
    def article(name, section = nil)
      Article.new(self, name, section)
    end

    ##
    # Retrieve all namespaces and their IDs, which could be used for Wiki#allpages
    # result:: [Hash] String => Fixnum
    def namespace_ids
      ids = {}
      SpecialPage.new( self, 'Special:Allpages', nil, false ).xhtml.each_element('//select[@name=\'namespace\']/option') do | o |
        ids[o.text] = o.attributes['value'].to_i
      end
      ids
    end

    ##
    # Returns the pages listed on "Special:Allpages"
    # result:: [Array] of [String] Articlenames
    def allpages()
      pages = []
      SpecialPage.new( self, 'Special:Allpages', nil, false ).xhtml.each_element('table[2]/tr/td/a') do | a |
        pages.push( a.text )
      end
      pages
    end

    ##
    # Construct the URL to a specific article
    #
    # Uses the [url] the Wiki instance was constructed with,
    # appends "index.php", the name parameter and, optionally,
    # the section.
    #
    # Often called by Article, Category, ...
    # name:: [String] Article name
    # section:: [Fixnum] Optional section number
    def article_url(name, section = nil)
      "#{@url.path}index.php?title=#{CGI::escape(name.gsub(' ', '_'))}#{section ? "&section=#{CGI::escape(section.to_s)}" : ''}"
    end

    def full_article_url(name, section=nil)
      uri = @url.dup
      uri.path, uri.query = article_url(name, section).split(/\?/, 2)
      uri.to_s
    end

  end

end

