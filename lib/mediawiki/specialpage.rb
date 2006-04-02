require 'mediawiki/article'

module MediaWiki
  ##
  # The SpecialPage class represents MediaWiki special pages.
  class SpecialPage < Article

    ##
    # Reload the xhtml,
    # will be automatically done by SpecialPage#xhtml if not already cached.
    def xhtml_reload
      html = @wiki.browser.get_content("#{@wiki.article_url(@name, @section)}")
      html.scan(/<!-- start content -->(.+)<!-- end content -->/m) { |content,|
        @xhtml = REXML::Document.new("<xhtml>#{content}</xhtml>").root
      }
      @xhtml_cached = true
    end

  end

end
