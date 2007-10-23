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

require 'yaml'
require 'mediawiki'

module MediaWiki
  ##
  # dotfile function reads the user's MediaWiki config and
  # creates a Wiki instance.
  #
  # The filename is determined by the environment variable
  # MEDIAWIKI_RC or defaults to ~/.mediawikirc .
  #
  # A configured wiki can be chosen with the MEDIAWIKI_WIKI
  # environment variable, by the option mywiki or defaults 
  # to the wiki pointed by default.
  #
  # A robot may set [myrealm] to retrieve a second result
  # output: a section with this name in the current wiki's
  # configuration file for configuration of specific robot
  # tasks.
  def MediaWiki.dotfile(myrealm=nil,mywiki=nil)
    filename = ENV['MEDIAWIKI_RC'] || "#{ENV['HOME']}/.mediawikirc"
    dotfile = YAML::load(File.new(filename))

    wikiconf = dotfile[mywiki] || dotfile[ENV['MEDIAWIKI_WIKI'] || dotfile['default']]
    wiki = Wiki.new(wikiconf['url'], wikiconf['user'], wikiconf['password'])

    if myrealm
      [wiki, wikiconf[myrealm]]
    else
      wiki
    end
  end
end
