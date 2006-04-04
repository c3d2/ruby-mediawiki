begin
  require 'htree'
rescue LoadError
  STDERR.puts( 'htree library missing. Cannot sanitize HTML.' )
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
      puts "Loading #{@wiki.article_url(full_name, @section)}&action=edit"
      parse @wiki.browser.get_content("#{@wiki.article_url(full_name, @section)}&action=edit")
    end

    def parse(html)
      doc = to_rexml( html )
      # does not work for MediaWiki 1.4.x and is always the same name you ask for under 1.5.x
      # @name = doc.elements['//span[@class="editHelp"]/a'].attributes['title']
      form = doc.elements['//form[@name="editform"]']
      @text = form.elements['textarea[@name="wpTextbox1"]'].text
      begin
        form.each_element('input') { |e|
          @wp_edittoken = e.attributes['value'] if e.attributes['name'] == 'wpEditToken'
          @wp_edittime = e.attributes['value'] if e.attributes['name'] == 'wpEdittime'
        }
      rescue NoMethodError
        # wpEditToken might be missing, that's ok
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
      puts "Posting to #{@wiki.article_url(full_name, @section)}&action=submit with wpEditToken=#{@wp_edittoken} wpEdittime=#{@wp_edittime}"
      data = {'wpTextbox1' => @text, 'wpSummary' => summary, 'wpSave' => 1, 'wpEditToken' => @wp_edittoken, 'wpEdittime' => @wp_edittime}
      data['wpMinoredit'] = 1 if minor_edit
      data['wpWatchthis'] = 'on' if watch_this
      begin
        parse @wiki.browser.post_content("#{@wiki.article_url(full_name, @section)}&action=submit", data)
      rescue NoMethodError
        # This means, we havn't got the preview page, but the posted article
        # So everything is Ok, but we must reload the edit page here, to get
        # a new wpEditToken and wpEdittime
        reload
        return
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
    # What articles link to this article?
    # result:: [Array] of [String] Article names
    def what_links_here
      res = []
      links = to_rexml(@wiki.browser.get_content(@wiki.article_url("Spezial:Whatlinkshere/#{full_name}")))
      links.each_element('//div[@id="bodyContent"]//ul/li/a') { |a|
        res << a.attributes['title']
      }
      res
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
