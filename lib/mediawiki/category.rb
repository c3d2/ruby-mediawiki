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
