=begin
    This file is part of Ruby-MediaWiki.

    Ruby-MediaWiki is free software: you can redistribute it and/or
    modify it under the terms of the GNU General Public License as
    published by the Free Software Foundation, either version 3 of the
    License, or (at your option) any later version.

    Ruby-MediaWiki is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Ruby-MediaWiki.  If not, see
    <http://www.gnu.org/licenses/>.
=end


require 'uri'
require 'logger'

begin
  require 'htree'
rescue LoadError
  MediaWiki::logger.warn("htree library missing. Cannot sanitize HTML.")
  require 'rexml/document'
end

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

##
# =Ruby-MediaWiki - manipulate MediaWiki pages from Ruby.
#
# Please note that documents spit out by MediaWiki *must* be valid
# XHTML (or XML)!
#
# You may not want to use MediaWiki::Wiki directly but let MediaWiki.dotfile
# create your instance. This gives you the power of the dotfile
# infrastructure. See sample apps and <tt>mediawikirc.sample</tt>.
module MediaWiki
  ##
  # There's no need for any language attribute, the "Special:" prefix
  # works in any MediaWiki, regardless of localization settings.
  class Wiki
    ##
    # The MiniBrowser instance used by this Wiki.
    # This must be readable as it's used by Article and Category
    # to fetch themselves.
    attr_reader :browser 
    
    ##
    # The URL-Path to index.php (without index.php) as given 
    # to Wiki#initialize
    attr_reader :url
    
    ##
    # Initialize a new Wiki instance.
    # url:: [String] URL-Path to index.php (without index.php), may contain <tt>user:password</tt> combination.
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
      # Get wpLoginToken
      data = @browser.get_content( @url.path + 'index.php?title=Special:UserLogin' )
      doc = to_rexml( data )
      wp_logintoken = nil
      if form = doc.elements['//form[@name="userlogin"]']
        form.each_element('input') { |e|
          wp_logintoken = e.attributes['value'] if e.attributes['name'] == 'wpLoginToken'
        }
      end
      MediaWiki::logger.debug("Logging in with wpLoginToken=#{wp_logintoken}")

      data = {'wpName' => username, 'wpPassword' => password, 'wpLoginattempt' => 'Log in', 'wpRemember' => 1, 'wpLoginToken' => wp_logintoken}
      data = @browser.post_content( @url.path + 'index.php?title=Special:Userlogin&action=submitlogin', data )
      if data =~ /<p class='error'>/ or data =~ /<div class="errorbox">/
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
    #
    # TODO: Handle big wikis with chunked Special:Allpages
    # namespace_id:: Optional namespace for article index (see Wiki#namespace_ids to retrieve id)
    # result:: [Array] of [String] Articlenames
    def allpages(namespace_id=nil)
      # Dirty, but works
      article_name = 'Special:Allpages'
      article_name += "&namespace=#{namespace_id}" if namespace_id

      pages = []
      SpecialPage.new( self, article_name, nil, false ).xhtml.each_element('table[2]/tr/td/a') do | a |
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
  
  protected
    def to_rexml( html )
      if Class.constants.member?( 'HTree' )
        rexml = HTree( html ).to_rexml
      else
        rexml = REXML::Document.new( html )
      end
      rexml.root
    end

  end

end

