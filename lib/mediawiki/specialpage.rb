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
        @xhtml = to_rexml( "<xhtml>#{content}</xhtml>" )
      }
      @xhtml_cached = true
    end

  end

end
