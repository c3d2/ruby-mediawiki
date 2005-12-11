require 'yaml'
$:.unshift('../lib')
require 'mediawiki/dotfile'

include MediaWiki

class DateUser
  attr_reader :name

  def initialize(name, hsh)
    @name = name
    @hsh = hsh
  end

  def dates
    @hsh.keys
  end

  def day(d)
    @hsh[d]
  end

  def day_class(d)
    if day(d) == nil
      nil
    elsif day(d) =~ /^[yj]/i
      true
    elsif day(d) =~ /^n/i
      false
    else
      ""
    end
  end

  def day_style(d)
    case day_class(d)
      when nil then ""
      when true then 'bgcolor="#7fff7f"'
      when false then 'bgcolor="#ff7f7f"'
      else 'bgcolor="#bfbfbf"'
    end
  end
end

class DateData
  def initialize(yaml)
    @users = []
    @error = nil
    begin
      YAML::load(yaml).each { |user,dates|
        @users << DateUser.new(user, dates)
      }
    rescue Exception => e
      puts "#{e.class}: #{e}\n#{e.backtrace.join("\n")}"
      @error = e.to_s
    end
  end

  def table
    return @error if @error
    
    s = ''

    ##
    # Collect dates
    ##
    dates = []
    dates_yes = {}
    @users.each { |user| dates += user.dates }

    ##
    # Sort dates
    ##
    dates.uniq!
    dates.sort! { |a,b|
      if a =~ /^(\d+)\.(\d+)\./
        a_day = $1
        a_month = $2
        if b =~ /^(\d+)\.(\d+)\./
          b_day = $1
          b_month = $2
          if a_month.to_i == b_month.to_i
            a_day.to_i <=> b_day.to_i
          else
            a_month.to_i <=> b_month.to_i
          end
        else
          a <=> b
        end
      else
        a <=> b
      end
    }

    ##
    # Construct header
    ##
    s += "{| border=\"1\" cellpadding=\"2\" cellspacing=\"0\" style=\"border-collapse:collapse;\"\n|-\n! \n"
    dates.each { |date|
      s += "!#{date}\n"
      dates_yes[date] = 0
    }

    ##
    # Construct rows
    ##
    @users.each { |user|
      s += "|-\n|[[User:#{user.name}|#{user.name}]]\n"
      dates.each { |date|
        s += "| #{user.day_style(date)} | #{user.day(date)}\n"
        dates_yes[date] += 1 if user.day_class(date) == true
      }
    }

    ##
    # Build summary
    ##
    s += "|-\n|'''sum(ja)'''\n"
    dates.each { |date|
      s += "|'''#{dates_yes[date]}'''\n"
    }
    s += "|}"
  end
end



wiki, conf = MediaWiki.dotfile('date determinator')
conf['pages'].each { |name|
  page = wiki.article(name)

  datasets = {}
  current_data_name = nil
  current_data_yaml = ''
  page.text.split(/\n/).each { |line|
    if line =~ /BEGIN DATA "(.+?)"/
      current_data_name = $1
      current_data_yaml = ''
    elsif line =~ /END DATA/ and current_data_name
      datasets[current_data_name] = DateData.new(current_data_yaml)
      current_data_name = nil
      current_data_yaml = ''
    elsif current_data_name
      current_data_yaml += "#{line}\n"
    end
  }


  text_old = page.text.dup

  signature = /(<!-- BEGIN TABLE ")(.+?)(" -->)(.+?)(<!-- END TABLE -->)/m
  page.text.gsub!(signature) { |part|
    begin1,name,begin2,obsolete,end1 = part.match(signature).to_a[1..-1]
    table = datasets[name] ? datasets[name].table : "DATA #{name} not found!"
    p table
    "#{begin1}#{name}#{begin2}\n#{table}\n#{end1}"
  }
  puts page.text

  if page.text != text_old
    puts "submitting"
    page.submit('Date Determinator run')
  end

  puts "done"
}
