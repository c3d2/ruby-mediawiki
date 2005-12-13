require 'rexml/document'

module MediaWiki
  ##
  # The Category class represents MediaWiki categories.
  class Category
    ##
    # Create a new Category instance
    # wiki:: [Wiki] instance to be used to theive the MiniBrowser
    # name:: [String] Category name, to be prefixed with "Category:" when being fetched
    def initialize(wiki, name)
      @cached = false
      @doc = nil
      @wiki = wiki
      @name = name
    end

    ##
    # Reload the XML, will be invoked by
    # Category#articles, if not already cached.
    def reload
      @doc = REXML::Document.new(@wiki.browser.get_content(@wiki.article_url("Category:#{@name}"))).root
      @cached = true
    end

    ##
    # Which articles belong to this category?
    # result:: [Array] of [String] Article names
    def articles
      unless @cached
        reload
      end

      res = []
      @doc.each_element('//div[@id="bodyContent"]//ul/li/a') { |a,|
        res << a.attributes['title']
      }
      res
    end
  end
end
