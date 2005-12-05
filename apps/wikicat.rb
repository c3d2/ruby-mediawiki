#!/usr/bin/env ruby

$:.unshift('../lib')
require 'mediawiki/dotfile'

if ARGV.size != 1
  puts "Usage: #{$0} <Article name>"
  exit
end

wiki = MediaWiki.dotfile
puts wiki.article(ARGV[0]).text
