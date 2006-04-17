#!/usr/bin/env ruby

$:.unshift('../lib')
require 'mediawiki/dotfile'

if ARGV.size != 3
  puts "Usage: #{$0} <Article name> <file> <comment>"
  exit
end

wiki = MediaWiki.dotfile
a = wiki.article(ARGV[0])
a.text = File.new(ARGV[1]).readlines.to_s
a.submit(ARGV[2])
