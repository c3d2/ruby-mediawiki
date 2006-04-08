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
