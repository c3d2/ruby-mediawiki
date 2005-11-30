require 'rexml/document'

module MediaWiki
  class Article
    attr_accessor :name, :text
    
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

    def xhtml
      unless @xhtml_cached
        xhtml_reload
      end
      @xhtml
    end

    def xhtml_reload
      html = @wiki.browser.get_content("#{@wiki.article_url(@name, @section)}")
      html.scan(/<!-- start content -->(.+)<!-- end content -->/m) { |content,|
        @xhtml = REXML::Document.new("<xhtml>#{content}</xhtml>").root
      }
      
      @xhtml_cached = true
    end

    def reload
      puts "Loading #{@wiki.article_url(@name, @section)}&action=edit"
      doc = REXML::Document.new(@wiki.browser.get_content("#{@wiki.article_url(@name, @section)}&action=edit")).root
      @name = doc.elements['//span[@class="editHelp"]/a'].attributes['title']
      form = doc.elements['//form[@name="editform"]']
      @text = form.elements['textarea[@name="wpTextbox1"]'].text
      begin
        @wp_edittoken = form.elements['input[@name="wpEditToken"]'].attributes['value']
        @wp_edittime = form.elements['input[@name="wpEdittime"]'].attributes['value']
      rescue NoMethodError
        # wpEditToken might be missing, that's ok
      end
    end

    def submit(summary, minor_edit=false, watch_this=false)
      puts "Posting to #{@wiki.article_url(@name, @section)}&action=submit"
      data = {'wpTextbox1' => @text, 'wpSummary' => summary, 'wpSave' => 1, 'wpEditToken' => @wp_edittoken, 'wpEdittime' => @wp_edittime}
      data['wpMinoredit'] = 1 if minor_edit
      data['wpWatchthis'] = 'on' if watch_this
      result = @wiki.browser.post_content("#{@wiki.article_url(@name, @section)}&action=submit", data)
      # TODO: Was edit successful? (We received the document anyways)
    end
  end

end

