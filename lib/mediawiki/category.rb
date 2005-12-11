require 'rexml/document'

module MediaWiki
  class Category
    def initialize(wiki, name)
      @cached = false
      @doc = nil
      @wiki = wiki
      @name = name
    end

    def reload
      @doc = REXML::Document.new(@wiki.browser.get_content(@wiki.article_url("Category:#{@name}"))).root
      @cached = true
    end

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
