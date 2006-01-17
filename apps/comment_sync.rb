#!/usr/bin/env ruby

$:.unshift('../lib')
require 'postgres'
require 'yaml'
require 'mediawiki'
require 'mediawiki/dotfile'
require 'mediawiki/table'

class SQL_Parser
  # returns a hash with the tablename as key
  def self.parse( sql )
    tables = {}
    current = nil
    sql.each_line do | line |
      line.gsub!(/,$/, '')
      next if line.match(/^ *$/) or line.match(/BEGIN/) or line.match(/COMMIT/)
      if match = line.match(/CREATE TABLE ([a-z_]+) *\(/)
        current = match[1]
        tables[match[1]] = {:field_names => [], :field => {}}
      elsif line.match(/\) *(WITHOUT OIDS)?;/)
        current = nil
      elsif current
        if match = line.match(/^ +([a-z_0-9]+) +(.*)$/)
          tables[current][:field_names].push( match[1] )
          tables[current][:field][match[1]] = match[2].gsub(/(NOT NULL|UNIQUE|DEFAULT|CHECK).*/, '')
        elsif match = line.match(/^ *(FOREIGN KEY|PRIMARY KEY|CHECK|UNIQUE)/)
        else
          puts "unparsed line: #{line}"
        end
      else
       puts "unrecognized line: #{line.inspect}"
      end
    end
    tables
  end
end

# reads and writes comment to/from the database
class SQL_Comments

  # setup database connection
  def initialize( config )
    @connection = PGconn.connect( config['host'], config['port'], nil, nil, config['database'], config['username'], config['password'])
  end

  def escape( data )
    data.gsub("\\",'').gsub("'", "''")
  end

  def escape_ident( data )
    data.gsub("\\",'').gsub('"', '')
  end

  def get_table_description( table )
    @connection.exec("SELECT description
                        FROM pg_description
                             INNER JOIN pg_class ON ( pg_class.oid = pg_description.objoid )
                       WHERE pg_description.objsubid = 0 AND
                             pg_class.relname = '#{escape(table)}';"
                     ).entries.flatten[0]
  end

  def set_table_description( table, text )
    @connection.exec("COMMENT ON TABLE \"#{escape_ident(table)}\" IS #{text.to_s == "" ? 'NULL' : "'#{escape(text.strip)}'"};")
  end

  def set_column_description( table, column, text )
    @connection.exec("COMMENT ON COLUMN \"#{escape_ident(table)}\".\"#{escape_ident(column)}\" IS #{text.to_s == "" ? 'NULL' : "'#{escape(text.strip)}'"};")
  end

  def get_column_description( table, column )
    @connection.exec("SELECT description
                        FROM pg_description
                             INNER JOIN pg_class ON ( pg_class.oid = pg_description.objoid )
                             INNER JOIN pg_attribute ON
                                ( pg_attribute.attrelid = pg_description.objoid AND
                                  pg_description.objsubid = pg_attribute.attnum )
                       WHERE pg_class.relname = '#{escape(table)}' AND
                             pg_attribute.attname = '#{escape(column)}'"
                     ).entries.flatten[0]
  end

end


class Comment_Synchronizer

  def initialize( wiki, config, sql)
    @wiki = MediaWiki.dotfile
    @sql = SQL_Comments.new(config)
    @tables = SQL_Parser.parse( sql )
  end

  # update wiki with content from database
  def update_wiki
    # generate index page
    page = @wiki.article('Database/Tables')
    page.text = "This is a list of all tables used in pentabarf\n\n"
    @tables.keys.sort.each do | table |
      page.text += "*[[Database/Tables/#{table.capitalize}|#{table}]]\n"
    end
    page.text += "[[Category:Database]]"
    page.submit('generating list of tables')

    # create one page for each table
    @tables.keys.sort.each do | table |
      page = @wiki.article("Database/Tables/#{table.capitalize}")

      # create wiki page
      page.text = @sql.get_table_description( table ).to_s + "\n"
      # table header
      page.text += "==Columns==\n"
      t = MediaWiki::Table.new
      t.style = 'border="1" cellspacing="0" cellpadding="3"'
      t.header_style = 'bgcolor="lightblue"'
      t.header = ['field name', 'datatype', 'description']

      @tables[table][:field_names].each do | field_name |
        t.data.push([field_name, @tables[table][:field][field_name], @sql.get_column_description( table, field_name)])
      end
      page.text += t.text
      page.text += "\n[[Category:Database]]\n"
      puts page.text
      page.submit("updating page for table #{table}")

    end
  end

  # write documentation from wiki into database
  def update_database
    # fetch content from all wiki pages and put it in the database
    @tables.keys.sort.each do | table |

      # get the section containing the general description
      page = @wiki.article("Database/Tables/#{table.capitalize}", 0)
      @sql.set_table_description( table, page.text )

      # get the section containing the column table
      page = @wiki.article("Database/Tables/#{table.capitalize}", 1)
      state = :description
      column = ''
      # parse wiki text
      MediaWiki::Table.parse( page.text ).each do | column |
        next if column[0] == 'field name' # this is the header column
        @sql.set_column_description( table, column[0], column[2] )
      end
    end
  end


end

  db_config = YAML.load_file('db_config.yml')['development']
  #db_config = {'host' => 'localhost', 'port' => 5432, 'database' => 'pentabarf', 'username' => 'joe', 'password' => 'secret'}
  sql = `svnlook cat /var/subversion/pentabarf /trunk/sql/tables.sql`

  bot = Comment_Synchronizer.new( :pentabarf, db_config, sql )
  bot.update_database
  bot.update_wiki

