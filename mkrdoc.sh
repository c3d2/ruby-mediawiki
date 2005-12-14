#!/bin/sh
rdoc --inline-source --line-numbers --op rdoc lib/mediawiki.rb lib/mediawiki/*.rb
rdoc --inline-source --line-numbers --op rdoc-ri -f ri lib/mediawiki.rb lib/mediawiki/*.rb
