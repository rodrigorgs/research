#!/usr/bin/env ruby

# Generic database utils 

require 'sequel'

class Database
  def initialize(url)
    @db = Sequel.connect(url)    
  end

  # Some typical methods implement by subclasses
  # def create_tables
  # def create_views
  # def modify_tables
  # def insert_stub_...
  # def compute_missing_...

  def pk_for_table(table)
    return 'id'
  end

  # Insert a row with given values into table if it not exists already.
  def insert_unique(table, values)
    ret = false
      @db.transaction do
      dataset = @db[table].filter(values)
      count = dataset.count
      if count == 0
        @db[table].insert(values)
        ret = true
      elsif count > 1
        raise RuntimeError, 'More than 1 row returned.'
      end
    end

    return ret
  end

  # Insert a row with given values into table if it not exists already.
  # Returns the pk of the existing/inserted row. 
  def insert_unique_get_pk(table, values)
    insert_unique(table, values)
    pkcolumn = pk_for_table(table).to_sym
    return @db[table].filter(values).first[pkcolumn]
  end

  # Iterator for rows selected by the dataset `ds', returned in random
  # order. Useful for parallelizing computations on table.
  #
  # `column' is the column used to sort. If it's nil, the primary key
  # column is used
  #
  # Guaranteed to work only on PostgreSQL
  def each_random_row(ds, column=nil, &block)
    column = pk_for_table(ds.first_source_table).to_sym if column.nil?
    column = column.lit if column.kind_of?(String)

    while true
      puts 'fetching rows...'
      rows = ds.select(column).limit(4000).all
      n = rows.size
      break if rows.empty?
      puts "fetched #{n} rows. Shuffling..."
      rows.shuffle!
      puts 'done'

      iters = [n / 10.0].min;
      c = 0
      rows.each do |row|
        ds2 = ds.and(column => row.values[0])
        if ds2.count > 0
          block.call(ds2.first)
        else
          puts 'already taken'
        end
        c += 1
        break if c >= iters
      end
    end
  end

end



