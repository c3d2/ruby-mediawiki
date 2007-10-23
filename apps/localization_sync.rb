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


# this bot expects a fully functional local pentabarf installation

$:.unshift('../lib')

require 'mediawiki/dotfile'
require 'mediawiki/table'
require 'momomoto/momomoto'
require 'momomoto/tables'
require 'momomoto/bot_login'

class Localization_Sync

  def initialize
    @wiki = MediaWiki.dotfile

    db_config = YAML.load_file('db_config.yml')['development']
    Momomoto::Base.connect(db_config)
    Momomoto::Bot_login.authorize('ui_tagger')

    @lang = {}
    Momomoto::Language.find({:f_localized=>'t'},nil,"lower(tag)").each do | l | @lang[l.tag] = l.language_id end

    @@syncable = [
                    ['Attachment_type', :attachment_type_id, :tag, Momomoto::Attachment_type, Momomoto::Attachment_type_localized],
                    ['Conference_phase', :conference_phase_id, :tag, Momomoto::Conference_phase, Momomoto::Conference_phase_localized],
                    ['Conflict', :conflict_id, :tag, Momomoto::Conflict, Momomoto::Conflict_localized],
                    ['Conflict_level', :conflict_level_id, :tag, Momomoto::Conflict_level, Momomoto::Conflict_level_localized],
                    ['Country', :country_id, :iso_3166_code, Momomoto::Country, Momomoto::Country_localized],
                    ['Currency', :currency_id, :iso_4217_code, Momomoto::Currency, Momomoto::Currency_localized],
                    ['Event_origin', :event_origin_id, :tag, Momomoto::Event_origin, Momomoto::Event_origin_localized],
                    ['Event_role', :event_role_id, :tag, Momomoto::Event_role, Momomoto::Event_role_localized],
                    ['Event_state', :event_state_id, :tag, Momomoto::Event_state, Momomoto::Event_state_localized],
                    ['Event_type', :event_type_id, :tag, Momomoto::Event_type, Momomoto::Event_type_localized],
                    ['Im_type', :im_type_id, :tag, Momomoto::Im_type, Momomoto::Im_type_localized],
                    ['Language', :language_id, :iso_639_code, Momomoto::Language, Momomoto::Language_localized, :translated_id],
                    ['Mime_type', :mime_type_id, :mime_type, Momomoto::Mime_type, Momomoto::Mime_type_localized],
                    ['Phone_type', :phone_type_id, :tag, Momomoto::Phone_type, Momomoto::Phone_type_localized],
                    ['Role', :role_id, :tag, Momomoto::Role, Momomoto::Role_localized],
                    ['Transport', :transport_id, :tag, Momomoto::Transport, Momomoto::Transport_localized],
                    ['Ui_message', :ui_message_id, :tag, Momomoto::Ui_message, Momomoto::Ui_message_localized]
                 ]

  end

  # creates wiki pages from the data in the database
  def update_wiki
    @@syncable.each do | row |
      make_table( *row )
    end
    page = @wiki.article('Localization', 1)
    page.text = "=Localizable Tables=\n"
    @@syncable.each do | row |
      page.text += "*[[Localization/#{row[0]}|#{row[0]}]]\n"
    end
    page.submit('updating localization page')
  end

  # reads wiki pages and updates the database according to the data in the wiki
  def update_database
    @@syncable.each do | row |
      read_table( *row )
    end
  end

  def read_table(table, tag_id, tag_name, tag_class, local_class, lang_id = :language_id)
    page = @wiki.article("Localization/#{table}")
    return if page.text == ''
    t = MediaWiki::Table.parse( page.text )
    header = t.shift
    header.shift

    local_class.new.begin

    t.each do | row |
      header.each_with_index do | lang_tag, index |
        cur_tag = tag_class.find({tag_name=>row[0]})
        next unless cur_tag.length == 1
        cur_loc = local_class.find({lang_id=>@lang[header[index]],tag_id=>cur_tag[tag_id]})
        next if row[index + 1] == ''
        unless cur_loc.length == 1
          cur_loc.create
          cur_loc[lang_id] = @lang[header[index]]
          cur_loc[tag_id] = cur_tag[tag_id]
        end
        cur_loc[:name] = row[index + 1].strip
        cur_loc.write
      end
    end

    local_class.new.commit

  end

  def make_table(table, tag_id, tag_name, tag_class, local_class, lang_id = :language_id)
    tags = {}
    tag_class.find().each do | tc | tags[tc[tag_name]] = tc[tag_id] end
    local = local_class.find({lang_id=>@lang.values})

    page = @wiki.article("Localization/#{table}")

    t = MediaWiki::Table.new
    t.style = 'border="1" cellspacing="0" cellpadding="3" style="border-collapse: collapse;"'
    t.header_style = 'bgcolor="lightblue"'
    t.header = ['']
    @lang.each do | tag, id | t.header.push( tag ) end
    tags.keys.sort.each do | tag |
      row = [tag]
      @lang.each do | key, language_id |
        row.push(local.find_by_value({tag_id=>tags[tag],lang_id=>language_id}) ? local.name : '')
      end
      t.data.push( row )
    end

    page.text = "[[Localization|<< Localization]]\n" + t.text + "\n[[Category:Localization]]"
    page.submit("updating localization pages")
  end

end

s = Localization_Sync.new
s.update_database
s.update_wiki

