#!/usr/bin/env ruby

$:.unshift('../lib')
require 'mediawiki/dotfile'

wiki, conf = MediaWiki.dotfile('speed metal bot')
category = conf['category']
user_prefix = conf['user prefix']
template_name = conf['template']

category = wiki.category(category)
template = wiki.article("Template:#{template_name}")

articles_template = template.what_links_here

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
newtemplate = "<div align=\"center\" style=\"border: 1px solid black;\">\n" +
              "<div style=\"background-color: #e64200;\">'''Rübÿ Spëëd Mëtäl Cödïng'''</div>\n" +
              "<div style=\"float: left; width: 64px; height: 64px;>[[Bild:Speed metal coding 64x64.jpg|left]]</div>\n" +
              "<div style=\"margin-left: 70px;\"><br/>'''Coders:''' "
users.each_with_index { |user,i|
  newtemplate += " | " if i > 0
  newtemplate += "[[User:#{user}|#{user}]]"
}

newtemplate += "</div>\n" +
               "<div style=\"margin-left: 70px;\">\n----\n'''Projects:''' "
projects.each_with_index { |project,i|
  newtemplate += " | " if i > 0
  newtemplate += "[[#{project}]]"
}
newtemplate += "<br/> </div>\n" +
               "</div>"

### Submit template ###
if template.text != newtemplate
  template.text = newtemplate
  template.submit("Speed metal bot run", true)
end

### Let template be used by all in category ###
(category.articles - articles_template).each { |name|
  article = wiki.article(name)
  unless article.text.index("{{#{template_name}}}")
    article.text.gsub!(/\n+$/, '')
    article.text += "\n\n{{#{template_name}}}"
  end
  article.submit("This page must use the #{template_name} template!!!111")
}
