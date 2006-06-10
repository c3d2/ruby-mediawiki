require 'net/http'
require 'net/https'
require 'cgi'

module MediaWiki
  ##
  # The MiniBrowser is used to perform GET and POST requests
  # over HTTP and HTTPS, supporting:
  # * HTTP-Auth encoding in URLs (proto://user:password@host/...)
  # * Cookie support
  # * HTTP Redirection (max. 10 in a row)
  #
  # All interaction with MiniBrowser is normally done by
  # MediaWiki::Wiki.
  class MiniBrowser
    ##
    # Initialize a MiniBrowser instance
    # url:: [URI::HTTP] or [URI::HTTPS]
    def initialize(url)
      @url = url
      @http = Net::HTTP.new( @url.host, @url.port )
      @http.use_ssl = true if @url.class == URI::HTTPS
      @user_agent = 'WikiBot'
      @cookies = {}
    end

    ##
    # Add cookies to the volatile cookie cache
    # cookies:: [Array]
    def add_cookie(cookies)
      cookies.each do | c |
        c.gsub!(/;.*$/, '')
        if match = c.match(/([^=]+)=(.*)/)
          @cookies[match[1]] = match[2]
        end
      end
    end

    ##
    # Get the cookie cache in a serialized form ready for HTTP.
    # result:: [String]
    def cookies
      c = @cookies.collect do | key, value | "#{key}=#{value}" end
      c.join(";")
    end

    ##
    # Perform a GET request
    #
    # This method accepts 10 HTTP redirects at max.
    # url:: [String]
    # result:: [String] Document
    def get_content(url)
      retries = 10

      @http.start { |http|
        loop {
          raise "too many redirects" if retries < 1

          request = Net::HTTP::Get.new(url, {'Content-Type' => 'application/x-www-form-urlencoded',
                                              'User-Agent' => @user_agent,
                                              'Cookie' => cookies})
          request.basic_auth(@url.user, @url.password) if @url.user
          response = http.request(request)

          case response 
            when Net::HTTPSuccess, Net::HTTPNotFound then 
              return response.body
            when Net::HTTPRedirection then
              MediaWiki::logger.debug("Redirecting to #{response['Location']}")
              retries -= 1
              url = response['Location']
            else
              raise "Unknown Response: #{response.inspect}"
          end
        }
      }
    end

    ##
    # Perform a POST request
    #
    # Will switch to MiniBrowser#get_content upon HTTP redirect.
    # url:: [String]
    # data:: [Hash] POST data
    # result:: [String] Document
    def post_content(url, data)
      post_data = data.collect { | key, value | "#{CGI::escape(key.to_s)}=#{CGI::escape(value.to_s)}" }.join('&')
      response = nil

      @http.start { |http|
        request = Net::HTTP::Post.new(url, {'Content-Type' => 'application/x-www-form-urlencoded',
                                             'User-Agent' => @user_agent,
                                             'Cookie' => cookies})
        request.basic_auth(@url.user, @url.password) if @url.user
        response = http.request(request, post_data)
      }

      case response 
        when Net::HTTPSuccess 
        then
          begin
            add_cookie( response.get_fields('Set-Cookie') ) if response['Set-Cookie']
          rescue NoMethodError
            add_cookie( response['Set-Cookie'] ) if response['Set-Cookie']
          end
          return response.body
        when Net::HTTPRedirection
        then
          MediaWiki::logger.debug("Redirecting to #{response['Location']}")
          begin
            add_cookie( response.get_fields('Set-Cookie') ) if response['Set-Cookie']
          rescue NoMethodError
            add_cookie( response['Set-Cookie'] ) if response['Set-Cookie']
          end
          return get_content(response['Location'])
        else
          raise "Unknown Response: #{response.inspect}"
      end
    end
  end
end
