
module MediaWiki

  class Table
    # takes the wiki markup of a table and returns a 2-dimensional array representing the rows and columns of the first table
    def self.parse( text )
      table, row = nil, nil
      text.each_line do | line |
        if line.match( /^\{\|/ )
          table, row = [], []
        elsif table.nil?
          # ignoring line probably not belonging to a table
        elsif line.match( /^\|\}/ )
          table.push( row ) unless row.empty?
          return table
        elsif line.match( /^\|-/ )
          table.push( row ) unless row.empty?
          row = []
        elsif match = line.match( /^(!|\|)(.*)$/ )
          if match[2] == ""
            row.push( "" )
          else
            match[2].split( '||', 1 ).each do | column | row.push( column.strip ) end
          end
        else
          raise "Error parsing the following line: #{line.inspect}"
        end
      end
      []
    end

  end

end

