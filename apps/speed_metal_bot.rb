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

wiki, conf = MediaWiki.dotfile('speed metal bot')
category_name = conf['category']
user_prefix = conf['user prefix']
template_name = conf['template']

category = wiki.category(category_name)
template = wiki.article("Template:#{template_name}")

puts "Category #{category_name}: #{category.articles.inspect}"

users = []
projects = []
category.articles.each { |name|
  if name.index(user_prefix) and name.index('/').nil?
    prefix, name = name.split(/:/, 2)
    users << name
  else
    projects << name
  end
}

### Construct template ###
newtemplate = "<div align=\"center\" style=\"border: 1px solid black; clear: right;\">\n" +
              "<div style=\"float: left; width: 64px; height: 64px;>[[Bild:Speed metal coding 64x64.jpg|left]]</div>\n" +
              "<div style=\"margin-left: 70px; background-color: #e64200; font-size: large; height: 1.5em;\">'''Rübÿ Spëëd Mëtäl Cödïng'''</div>\n" +
              "<div style=\"margin-left: 70px;\">'''Coders:''' "
users.each_with_index { |user,i|
  newtemplate += " | " if i > 0
  newtemplate += "[[User:#{user}|#{user}]]"
}

newtemplate += "</div>\n" +
               "<div style=\"margin-left: 70px;\">'''Projects:''' "
projects.each_with_index { |project,i|
  newtemplate += " | " if i > 0
  newtemplate += "[[#{project}]]"
}
newtemplate += "<br/></div>\n" +
               "</div>\n"

### Submit template ###
if template.text != newtemplate
  template.text = newtemplate
  template.submit("Speed metal bot run", true)
end

### Let template be used by all in category ###
category.articles.each { |name|
  article = wiki.article(name)
  unless article.text.index("{{#{template_name}}}")
    puts "#{article.name} is in category but doesn't use template"
    article.text.gsub!(/\n+$/, '')
    article.text += "\n\n\n\n{{#{template_name}}}"
    article.submit("This page must use the #{template_name} template!!!111")
  end
}
