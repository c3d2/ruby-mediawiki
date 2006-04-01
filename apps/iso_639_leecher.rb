#!/usr/bin/env ruby

$:.unshift('../lib')

require 'mediawiki/dotfile'
require 'mediawiki/table'
require 'momomoto/momomoto'
require 'momomoto/tables'
require 'momomoto/bot_login'

  ENV['MEDIAWIKI_WIKI'] = 'wikipedia_de'

  db_config = YAML.load_file('db_config.yml')['development']
  Momomoto::Base.connect(db_config)
  Momomoto::Bot_login.authorize('ui_tagger')

  wiki = MediaWiki.dotfile
  page = wiki.article('ISO 639', 3)
  t = MediaWiki::Table.parse( page.text )

  t.shift

  t.each do | row |
    row[2].split( '/' ).each do | iso_code |
      id = Momomoto::Language.find({:iso_639_code=>iso_code})
      next unless id.length == 1
      match = row[0].match /\[\[(.*\|)?(.+)\]\]/
      name = match[2]

      local = Momomoto::Language_localized.find({:language_id=>id.language_id,:translated_id=>144})
      if local.length == 0 && name != ''
        local.create
        local.language_id = id.language_id
        local.translated_id = 144
        local.name = name
        local.write
      end

    end
  end

