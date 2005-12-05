require 'net/http'
require 'net/https'
require 'cgi'

module MediaWiki
  class MiniBrowser
    def initialize( url )
      @url = url
      @http = Net::HTTP.new( @url.host, @url.port )
      @http.use_ssl = true if @url.class == URI::HTTPS
      @user_agent = 'WikiBot'
      @cookies = {}
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

    def get_content(url)
      retries = 10

      @http.start { |http|
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
            puts "Redirecting to #{response['Location']}"
            retries -= 1
            url = response['Location']
          else
            raise "Unknown Response: #{response.inspect}"
        end
      }
    end

    def post_content( url, data )
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
          add_cookie( response['Set-Cookie']) if response['Set-Cookie']
          return response.body
        when Net::HTTPRedirection
        then
          puts "Redirecting to #{response['Location']}"
          add_cookie( response['Set-Cookie']) if response['Set-Cookie']
          return get_content(response['Location'])
        else
          raise "Unknown Response: #{response.inspect}"
      end
    end
  end
end
