
module MediaWiki

  ##
  # The MediaWiki::Table class is used to parse existing
  # tables from mediawiki articles and to create tables
  # from arrays. Currently only the mediawiki pipe syntax is
  # supported.
  class Table
    ##
    # Initialize a Table instance
    # data:: [Array]
    # header:: [Array]
    def initialize( data = [], header = [] )
      @data = data
      @header = header
    end

    attr_accessor :style, :header_style, :row_style, :data, :header

    ##
    # Creates the mediawiki markup to be put in an article
    def text
      markup = "{| #{@style}\n"
      markup += "|---- #{@header_style}\n" if @header_style unless @header.empty?
      markup += @header.collect{ | col | "!#{col}\n" }.join('') unless @header.empty?
      @data.each do | row |
        markup += "|---- #{@row_style}\n"
        markup += row.collect{ | col | "|#{col}\n" }.join('')
      end
      markup += "|}"
      markup
    end

    ##
    # Parses the wiki markup of a table and returns a 2-dimensional
    # array representing rows and columns of the table. Currently only
    # the mediawiki pipe syntax is supported.
    # text:: [String]
    def self.parse( text )
      table, row = nil, nil
      text.each_line do | line |
        if line.match( /^\{\|/ )
          table, row = [], []
        elsif table.nil?
          # ignoring line probably not belonging to a table
        elsif line.match( /^ *\|\}/ )
          # end of table
          table.push( row ) unless row.empty?
          return table
        elsif line.match( /^ *\|-/ )
          # new row
          table.push( row ) unless row.empty?
          row = []
        elsif match = line.match( /^ *(!|\|)$/ )
          # cell without text
          row.push( "" )
        elsif match = line.match( /^ *!(.+)$/ )
          # header line with cell(s)
          match[1].split( /\|\||!!/, -1 ).each do | column | row.push( column.strip ) end
        elsif match = line.match( /^ *\|(.+)$/ )
          # ordinary line with cell(s)
          match[1].split( '||', -1 ).each do | column | row.push( column.strip ) end
        elsif match = line.match( /^ *[^!|][^|]*$/ )
          # multiline cell
          row[-1] += "\n" + line
        else
          raise "Error parsing the following line: #{line.inspect}"
        end
      end
      []
    end

  end

end

