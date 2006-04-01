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
      s += "\n"
    when SM::Flow::LI
      if flow.label =~ /:$/
        s += "; #{flow.label}\n: #{flow.body}\n"
      elsif flow.label =~ /^[ \*]$/
        s += "#{flow.label} #{flow.body}\n"
      else
        s += "* '''#{flow.label}:''' #{flow.body}\n"
      end
    when SM::Flow::P
      s += "#{flow.body}\n\n"
    else
      puts "Unknown Flow: #{flow.inspect}"
  end
  s.gsub!(/&quot;/, '"')
  s.gsub!(/<b>(.+?)<\/b>/, '\'\'\'\1\'\'\'')
  s.gsub!(/<i>(.+?)<\/i>/, '\'\'\1\'\'')
  s.gsub!(/<tt>(.+?)<\/tt>/, '<em>\1</em>')
  s
end


classes = []
methods = {}

find("../rdoc-ri") { |file|
  next unless file =~ /\.yaml$/
  ri = YAML::load(File.new(file))
  case ri
    when RI::ClassDescription
      classes << ri
    when RI::MethodDescription
      methods[ri.full_name] = ri
    else
      puts "Unknown Description: #{ri.inspect}"
  end
}

classes.sort! { |a,b|
  a.full_name <=> b.full_name
}

text = ''
classes.each { |klass|
  text += "==#{klass.full_name}==\n\n"
  text += "Inherited from '''#{klass.superclass}'''\n\n" if klass.superclass
  text += wiki_format(klass.comment || [])
  klass.attributes.each { |attribute|
    text += "===#{klass.full_name}##{attribute.name} (#{attribute.rw})===\n\n"
    text += wiki_format(attribute.comment || [])
    text += "\n"
  }
  klass.class_methods.each { |methodname|
    method = methods["#{klass.full_name}::#{methodname.name}"]
    text += "===#{method.full_name}#{method.params}===\n\n"
    text += wiki_format(method.comment || [])
    text += "\n"
  }
  klass.instance_methods.each { |methodname|
    method = methods["#{klass.full_name}##{methodname.name}"]
    text += "===#{method.full_name}#{method.params}===\n\n"
    text += wiki_format(method.comment || [])
    text += "\n"
  }
}

if true # Dry run?
  puts text
  exit
end

wiki, conf = MediaWiki.dotfile('rdoc to wiki')
article = wiki.article(conf['page'])
article.text = "=#{conf['title']}=\n\n" + text
article.submit("I can even document myself :-)")
