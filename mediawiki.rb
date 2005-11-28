#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'cgi'
require 'rexml/document'

class Mediawiki

  class Wiki
  
    def initialize( url )
      @url = URI.parse( url.match(/\/$/) ? url : url + '/' )
      @http = Net::HTTP.new( @url.host )
      @user_agent = 'WikiBot'
      @cookies = {}
    end

    def login( username, password )
      data = {'wpName' => username, 'wpPassword' => password, 'wpLoginattempt' => 'Log in'}
      data = post_content( @url.path + 'index.php?title=Special:Userlogin&action=submitlogin', data )
      if data =~ /<p class='error'>/
        raise "Unable to authenticate as #{username}"
      end
    end

    def add_cookie( cookies )
      cookies.each do | c |
        c.gsub!(/;.*$/, '')
        if match = c.match(/([^=]+)=(.*)/)
          @cookies[match[1]] = match[2]
        end
      end
    end

    def cookies
      c = @cookies.collect do | key, value | "#{key}=#{value}" end
      c.join(";")
    end

    def get_content( name, retries = 10 )
      raise "too many redirects" if retries < 1
      header = {}
      header['Content-Type'] = 'application/x-www-form-urlencoded'
      header['User-Agent'] = @user_agent
      header['Cookie'] = cookies
      response, data = @http.get( name, header )
      case response 
        when Net::HTTPSuccess, Net::HTTPNotFound
        then 
          return data
        when Net::HTTPRedirection
        then
          puts "Redirecting to #{response['Location']}"
          return get_content(response['Location'], retries - 1 )
        else
          p response
          raise "Unknown Response"
      end
    end

    def post_content( url, data )
      header = {}
      header['Content-Type'] = 'application/x-www-form-urlencoded'
      header['User-Agent'] = @user_agent
      header['Cookie'] = cookies
      post_data = data.collect do | key, value | "#{CGI::escape(key.to_s)}=#{CGI::escape(value.to_s)}" end
      response, data = @http.post( url, post_data.join('&'), header )
      case response 
        when Net::HTTPSuccess 
        then 
          add_cookie( response.response.get_fields('Set-Cookie')) if response.response['Set-Cookie']
          return data
        when Net::HTTPRedirection
        then
          puts "Redirecting to #{response['Location']}"
          add_cookie( response.response.get_fields('Set-Cookie')) if response.response['Set-Cookie']
          return get_content(response['Location'])
        else
          p response
          raise "Unknown Response"
      end
    end

    def article( name )
      Article.new(self, name)
    end

    def article_url(name)
      "#{@url.path}index.php?title=#{CGI::escape(name)}"
    end

  end

  class Article
    attr_accessor :name, :text
    
    def initialize(wiki, name, load_text=true)
      @wiki = wiki
      @name = name

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
      html = @wiki.get_content("#{@wiki.article_url(@name)}")
      html.scan(/<!-- start content -->(.+)<!-- end content -->/m) { |content,|
        @xhtml = REXML::Document.new("<xhtml>#{content}</xhtml>").root
      }
      
      @xhtml_cached = true
    end

    def reload
      puts "Loading #{@wiki.article_url(@name)}&action=edit"
      doc = REXML::Document.new(@wiki.get_content("#{@wiki.article_url(@name)}&action=edit")).root
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

    ##
    # TODO: minor_edit, watch_this
    def submit(summary, minor_edit=false, watch_this=false)
      puts "Posting to #{@wiki.article_url(@name)}&action=submit"
      data = {'wpTextbox1' => @text, 'wpSummary' => summary, 'wpSave' => 1, 'wpEditToken' => @wp_edittoken, 'wpEdittime' => @wp_edittime}
      result = @wiki.post_content("#{@wiki.article_url(@name)}&action=submit", data)
      # TODO: Was edit successful? (We received the document anyways)
    end
  end

end

