#!/usr/bin/env ruby

require 'yaml'
require 'rdoc/ri/ri_reader'

$:.unshift('../lib')
require 'mediawiki/dotfile'


def find(dir, &block)
  Dir.foreach(dir) { |file|
    next if file =~ /^\./

    path = "#{dir}/#{file}"
    if File.directory?(path)
      find(path) { |f| yield f }
    else
      yield path
    end
  }
end

def wiki_format(flow)
  s = ''
  case flow
    when Array
      flow.each { |subflow|
        s += wiki_format(subflow)
      }
    when SM::Flow::LIST
      flow.contents.each { |subflow|
        s += wiki_format(subflow)
      }
    when SM::Flow::LI
      s += "* '''#{flow.label}''' #{flow.body}\n"
    when SM::Flow::P
      s += "#{flow.body}\n\n"
    else
      puts "Unknown Flow: #{flow.inspect}"
  end
  s.gsub!(/&quot;/, '"')
  s.gsub!(/<b>(.+?)<\/b>/, '\'\'\'\1\'\'\'')
  s.gsub!(/<i>(.+?)<\/i>/, '\'\'\1\'\'')
  s
end

def belongs_to_class?(classname, methodname)
  c = classname.split(/::|#/)
  m = methodname.split(/::|#/)
  m.pop
  c == m
end

classes = []
methods = []

find("../rdoc-ri") { |file|
  next unless file =~ /\.yaml$/
  ri = YAML::load(File.new(file))
  case ri
    when RI::ClassDescription
      classes << ri
    when RI::MethodDescription
      methods << ri
    else
      puts "Unknown Description: #{ri.inspect}"
  end
}

classes.sort! { |a,b|
  a.full_name <=> b.full_name
}
methods.sort! { |a,b|
  a.full_name <=> b.full_name
}

text = ''
classes.each { |klass|
  text += "==#{klass.full_name}==\n\n"
  text += wiki_format(klass.comment || [])
  methods.each { |method|
    if belongs_to_class?(klass.full_name, method.full_name)
      text += "===#{method.full_name}===\n"
      text += wiki_format(method.comment || [])
      text += "\n"
    end
  }
}


wiki, conf = MediaWiki.dotfile('rdoc to wiki')
article = wiki.article(conf['page'])
article.text = "=#{conf['title']}=\n\n" + text
article.submit("I can even document myself :-)")
