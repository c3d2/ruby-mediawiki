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

begin
  require 'htree'
rescue LoadError
  MediaWiki::logger.warn("htree library missing. Cannot sanitize HTML.")
  require 'rexml/document'
end


module MediaWiki
  ##
  # The Article class represents MediaWiki articles.
  class Article
    ##
    # Article name, will be refreshed upon Article#reload
    attr_accessor :name
    ##
    # Article text, will be set by Article#reload
    attr_accessor :text
    ##
    # this Article is read_only
    attr_accessor :read_only

    ##
    # Create a new Article instance
    # wiki:: [Wiki] instance to be used to theive the MiniBrowser
    # name:: [String] Article name
    # section:: [Fixnum] Optional article section number
    # load_text:: [Boolean] Invoke Article#reload to retrieve Article#text
    def initialize(wiki, name, section = nil, load_text=true)
      @wiki = wiki
      @name = name
      @section = section

      @text = nil
      @xhtml = nil
      @xhtml_cached = false
      @wp_edittoken = nil
      @wp_edittime = nil

      reload if load_text
    end

    ##
    # Return the full article name
    #
    # This will only return @name, but may be overriden by descendants
    # to include namespaces.
    # result:: [String] Full name
    def full_name
      @name
    end

    ##
    # Return the URL of the article as configured
    #
    # This will return a nice human-readable URL if your MediaWiki
    # is configured that way, unlike the generic URL returned by
    # Wiki#full_article_url.
    # result:: [String] URL
    def url
      uri = @wiki.url.dup
      uri.path, uri.query = xhtml.elements['//li[@id="ca-nstab-main"]//a'].attributes['href'].split(/\?/, 2)
      uri.to_s
    end
    
    ##
    # Return the URL of the talk page of the article
    #
    # This will return a nice human-readable URL to the talk page
    # of an article if your MediWiki is configured that way.
    # For empty talk pages this will return an ugly URL just
    # as MediaWiki does.
    # result:: [String] URL
    def talk_url
      uri = @wiki.url.dup
      uri.path, uri.query = xhtml.elements['//li[@id="ca-talk"]//a'].attributes['href'].split(/\?/, 2)
      uri.to_s
    end

    ##
    # Get the XHTML,
    # will invoke Article#xhtml_reload if not already cached
    # result:: [REXML::Element] html root element
    def xhtml
      unless @xhtml_cached
        xhtml_reload
      end
      @xhtml
    end

    ##
    # Reload the xhtml,
    # will be automatically done by Article#xhtml if not already cached.
    def xhtml_reload
      html = @wiki.browser.get_content("#{@wiki.article_url(full_name, @section)}")
      @xhtml = to_rexml( html )
      
      @xhtml_cached = true
    end

    ##
    # Reload Article#text,
    # should be done by Article#initialize.
    def reload
      MediaWiki::logger.debug("Loading #{@wiki.article_url(full_name, @section)}&action=edit")
      parse @wiki.browser.get_content("#{@wiki.article_url(full_name, @section)}&action=edit")
    end

    class NoEditFormFound < RuntimeError
    end

    def parse(html)
      doc = to_rexml( html )
      # does not work for MediaWiki 1.4.x and is always the same name you ask for under 1.5.x
      # @name = doc.elements['//span[@class="editHelp"]/a'].attributes['title']
      if form = doc.elements['//form[@name="editform"]']
        # we got an editable article
        @text = form.elements['textarea[@name="wpTextbox1"]'].text
        begin
          form.each_element('input') { |e|
            @wp_edittoken = e.attributes['value'] if e.attributes['name'] == 'wpEditToken'
            @wp_edittime = e.attributes['value'] if e.attributes['name'] == 'wpEdittime'
          }
          @read_only = false
        rescue NoMethodError
          # wpEditToken might be missing, that's ok
        end
      else
        if doc.elements['//textarea']
          # the article is probably locked and you do not have sufficient privileges
          @text = doc.elements['//textarea'].text
          @read_only = true
        else
          raise NoEditFormFound, "Error while parsing result, no edit form found"
        end
      end
    end

    ##
    # Push the *Submit* button
    #
    # Send the modified Article#text to the MediaWiki.
    # summary:: [String] Change summary
    # minor_edit:: [Boolean] This is a Minor Edit
    # watch_this:: [Boolean] Watch this article
    def submit(summary, minor_edit=false, watch_this=false, retries=10)
      raise "This Article is read-only." if read_only
      MediaWiki::logger.debug("Posting to #{@wiki.article_url(full_name, @section)}&action=submit with wpEditToken=#{@wp_edittoken} wpEdittime=#{@wp_edittime}")
      data = {'wpTextbox1' => @text, 'wpSummary' => summary, 'wpSave' => 1, 'wpEditToken' => @wp_edittoken, 'wpEdittime' => @wp_edittime}
      data['wpMinoredit'] = 1 if minor_edit
      data['wpWatchthis'] = 'on' if watch_this
      begin
        parse @wiki.browser.post_content("#{@wiki.article_url(full_name, @section)}&action=submit", data)
      rescue NoEditFormFound
        # This means, we havn't got the preview page, but the posted article
        # So everything is Ok, but we must reload the edit page here, to get
        # a new wpEditToken and wpEdittime
        reload
        return
      rescue Net::HTTPInternalServerError
      end

      unless @wp_edittoken.to_s == '' and @wp_edittime.to_s == ''
        if (data['wpEditToken'] != @wp_edittoken) or (data['wpEdittime'] != @wp_edittime)
          if retries > 0
            submit(summary, minor_edit, watch_this, retries - 1)
          else
            raise "Re-submit limit reached"
          end
        end
      end
    end

    ##
    # Delete this article
    # reason:: [String] Delete reason
    def delete(reason)
      data = {'wpReason' => reason, 'wpEditToken' => @wp_edittoken, 'wpConfirmB' => 'Delete Page'}
      result = @wiki.browser.post_content("#{@wiki.article_url(full_name)}&action=delete", data)
    end

    ##
    # Protect this article
    # reason:: [String] Protect reason
    def protect(reason, moves_only=false)
      data = {'wpReasonProtect' => reason, 'wpEditToken' => @wp_edittoken, 'wpConfirmProtectB' => 'Protect Page'}
      data['wpMoveOnly'] = 1 if moves_only
      result = @wiki.browser.post_content("#{@wiki.article_url(full_name)}&action=protect", data)
    end

    ##
    # Unprotect this article
    # reason:: [String] Unprotect reason
    def unprotect(reason)
      data = {'wpReasonProtect' => reason, 'wpEditToken' => @wp_edittoken, 'wpConfirmProtectB' => 'Protect Page'}
      result = @wiki.browser.post_content("#{@wiki.article_url(full_name)}&action=unprotect", data)
    end

    ##
    # "what links here" url for this article
    def what_links_here_url(count = nil)
      url = @wiki.article_url("Special:Whatlinkshere/#{full_name}")
      url << "&limit=#{count}" if count
    end
    

    ##
    # What articles link to this article?
    # result:: [Array] of [String] Article names
    def what_links_here(count = nil)
      res = []
      url = what_links_here_url(count)
      links = to_rexml(@wiki.browser.get_content(url))
      links.each_element('//div[@id="bodyContent"]//ul/li/a') { |a|
        res << a.attributes['title']
      }
      res
    end
    
    def fast_what_links_here(count = nil)
      res = []
      url = what_links_here_url(count)
      content = @wiki.browser.get_content(url)
      content.scan(%r{<li><a href=".+?" title="(.+?)">.+?</a>.+?</li>}).flatten.map { |title|
        REXML::Text.unnormalize(title)
      }
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
