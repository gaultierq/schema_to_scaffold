require "schema_to_scaffold"
module SchemaToScaffold
  class CLI

    TABLE_OPTIONS = "\nOptions are:\n4 for table 4; (4..6) for table 4 to 6; [4,6] for tables 4 and 6; * for all Tables"

    def self.start(*args)
      ## Argument conditions
      opts = parse_arguments(args)

      if opts[:help]
        puts Help.message
        exit 0
      end

      ## looking for /schema\S*.rb$/ in user directory
      paths = Path.new(opts[:path])
      path = paths.choose unless opts[:path].to_s.match(/\.rb$/)

      ## Opening file
      path ||= opts[:path]
      begin
        data = File.open(path, 'r') { |f| f.read }
      rescue
        puts "\nUnable to open file '#{path}'"
        exit 1
      rescue Interrupt => e
        exit 1
      end

      ## Generate scripts from schema
      schema = Schema.new(data)

      table_ids = table_ids_from_opts(schema, opts) || tables_from_input(schema)
      script = []
      target = opts[:factory_girl] ? "factory_girl:model" : "scaffold"
      migration_flag = opts[:migration] ? true : false
      force_flag = opts[:force] ? true : false
      table_ids.each do |table_id|
        script << generate_script(schema, table_id, target, migration_flag, force_flag)
      end
      output = script.join("")
      puts "\nScript for #{target}:\n\n"
      puts output

      if opts[:clipboard]
        puts("\n(copied to your clipboard)")
        Clipboard.new(output).command
      end

      if opts[:exec]
        script.each do |s|
          j = s.join("")
          puts "executing script: #{j}"
          exec j
        end
      end
    end

    def self.table_ids_from_opts(schema, opts)
      t = opts[:table]
      return unless t
      table = schema.table(t)

      return [t] if table
      puts "Could not find table #{t}"
      exit 1 
    end

    def self.tables_from_input(schema)
      begin
        raise if schema.table_names.empty?
        puts "\nLoaded tables:"
        schema.print_table_names
        puts TABLE_OPTIONS
        print "\nSelect a table: "
      rescue
        puts "Could not find tables in '#{path}'"
        exit 1
      end

      input = STDIN.gets.strip
      puts "input is #{input}"
      begin
        tables = schema.select_tables(input)
        raise if tables.empty?
        tables
      rescue e
        puts "Not a valid input. #{TABLE_OPTIONS}"
        exit 1
      rescue Interrupt
        exit 1
      end
    end

    ##
    # Parses ARGV and returns a hash of options.
    def self.parse_arguments(argv)
      if argv_index = argv.index("-p")
        path = argv.delete_at(argv_index + 1)
        argv.delete('-p')
      end 
      if argv_index = argv.index("-t")
        table = argv.delete_at(argv_index + 1)
        argv.delete('-t')
      end

      args = {
        clipboard: argv.delete('-c'),    # check for clipboard flag
        factory_girl: argv.delete('-f'), # factory_girl instead of scaffold
        migration: argv.delete('-m'),   # generate migrations
        help: argv.delete('-h'),        # check for help flag
        path: path,                     # get path to file(s)
        table: table,
        exec: argv.delete('-x'),
        force: argv.delete('--force')
      }

      if argv.empty?
        args
      else
        puts "\n------\nWrong set of arguments.\n------\n" 
        puts Help.message
        exit
      end
    end

    ##
    # Generates the rails scaffold script
    def self.generate_script(schema, table=nil, target, migration_flag, force_flag)
      schema = Schema.new(schema) unless schema.is_a?(Schema)
      return schema.to_script if table.nil?
      schema.table(table).to_script(target, migration_flag, force_flag)
    end

  end
end
