--- !ruby/object:Gem::Specification 
rubygems_version: 0.9.4
name: ruby-mediawiki
version: !ruby/object:Gem::Version
  version: "0.1"
date: 2007-10-23 19:00:00 +02:00
summary: Ruby-MediaWiki 0.1
require_paths: 
- lib
email: stephan@spaceboyz.net
homepage: https://wiki.c3d2.de/Ruby-MediaWiki
rubyforge_project: ruby-mediawiki
description: "A library to retrieve and modify content managed by the popular MediaWiki software."
has_rdoc: true
platform: ruby
authors: 
- Sven Klemm
- Stephan Maka
- Mike Gerber
- Michael Witrant
files: 
- apps/comment_sync.rb
- apps/iso_639_leecher.rb
- apps/localization_sync.rb
- apps/speed_metal_bot.rb
- apps/wikipost.rb
- apps/date_determinator.rb
- apps/wikicat.rb
- apps/rdoc_to_wiki.rb
- lib/mediawiki/category.rb
- lib/mediawiki/specialpage.rb
- lib/mediawiki/minibrowser.rb
- lib/mediawiki/article.rb
- lib/mediawiki/dotfile.rb
- lib/mediawiki/table.rb
- lib/mediawiki.rb
- COPYING
- mediawikirc.sample
- mkrdoc.sh
- README
rdoc_options: 
- --title
- Ruby-MediaWiki
- -m
- MediaWiki
- --line-numbers
- --inline-source
dependencies: []
