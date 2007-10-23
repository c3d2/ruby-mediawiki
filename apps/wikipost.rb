#!/usr/bin/env ruby
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
