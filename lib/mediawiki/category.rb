require 'rexml/document'
require 'mediawiki/article'

module MediaWiki
  ##
  # The Category class represents MediaWiki categories.
  class Category < Article
    ##
    # This returns the full article name prefixed with "Category:"
    # instead of the name, which should not carry a prefix.
    def full_name
      "Category:#{@name}"
    end

    ##
    # Calls the reload function of the super-class (Article#reload)
    # but removes the prefix (namespace) then.
    #
    # Use to full_name to obtain the name with namespace.
    def reload
      super
      @name.sub!(/^.+?:/, '')
    end
    
    ##
    # Which articles belong to this category?
    # result:: [Array] of [String] Article names
    def articles
      res = []
      xhtml.each_element('//div[@id="bodyContent"]//ul/li/a') { |a,|
        res << a.attributes['title']
      }
      res
    end
  end
end
