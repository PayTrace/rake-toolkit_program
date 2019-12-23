# Rake::ToolkitProgram

Create toolkit programs easily with `Rake` and `OptionParser` syntax.  Bash completions and usage help are baked in.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'rake-toolkit_program'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install rake-toolkit_program

## Quickstart

* Shebang it up (in a file named `awesome_tool.rb`)
  ```ruby
  #!/usr/bin/env ruby
  ```
* Require the library
  ```ruby
  require 'rake/toolkit_program'
  ```
* Make your life easier
  ```ruby
  Program = Rake::ToolkitProgram
  ```
* Define your command tasks
  ```ruby
  Program.command_tasks do
    desc "Build it"
    task 'build' do
      # Ruby code here
    end
    
    desc "Test it"
    task 'test' => ['build'] do
      # Rake syntax ↑↑↑↑↑↑↑ for dependencies
      # Ruby code here
    end
  end
  ```
  You can use `Program.args` in your tasks to access the other arguments on the command line.  For argument parsing integrated into the help provided by the program, see the use of `Rake::Task(Rake::ToolkitProgram::TaskExt)#parse_args` below.
* Wire the mainline
  ```ruby
  Program.run(on_error: :exit_program!) if $0 == __FILE__
  ```
* In the shell, prepare to run the program (UNIX/Linux systems only)
  ```console
  $ chmod +x awesome_tool.rb
  $ ./awesome_tool.rb --install-completions
  Completions installed in /home/rtweeks/.bashrc
  Source /home/rtweeks/.bash-complete/awesome_tool.rb-completions for immediate availability.
  $ source /home/rtweeks/.bash-complete/awesome_tool.rb-completions
  ```
* Ask for help
  ```console
  $ ./awesome_tool.rb help
  
  *** ./awesome_tool.rb Toolkit Program ***
  
      .
      .
      .
  ```

## Usage

Let's look at a short sample toolkit program -- put this in `awesome.rb`:

```ruby
#!/usr/bin/env ruby
require 'rake/toolkit_program'
require 'ostruct'

ToolkitProgram = Rake::ToolkitProgram
ToolkitProgram.title = "My Awesome Toolkit of Awesome"

ToolkitProgram.command_tasks do
  desc <<-END_DESC.dedent
    Fooing myself
  
    I'm not sure what I'm doing, but I'm definitely fooing!
  END_DESC
  task :foo do
    a = ToolkitProgram.args
    puts "I'm fooed#{' on a ' if a.implement}#{a.implement}"
  end.parse_args(into: OpenStruct.new) do |parser, args|
    parser.no_positional_args!
    parser.on('-i', '--implement IMPLEMENT', 'An implement on which to be fooed') do |val|
      args.implement = val
    end
  end
end

if __FILE__ == $0
  ToolkitProgram.run(on_error: :exit_program!)
end
```

Make sure to `chmod +x awesome.rb`!

What does this support?

    $ ./awesome.rb foo
    I'm fooed
    $ ./awesome.rb --help
    
    *** My Awesome Toolkit of Awesome ***

    Usage: ./awesome.rb COMMAND [OPTION ...]

    Avaliable options vary depending on the command given. For details
    of a particular command, use:

        ./awesome.rb help COMMAND

    Commands:
         foo   Fooing myself
        help   Show a list of commands or details of one command

    Use help COMMAND to get more help on a specific command.
    
    $ ./awesome.rb help foo
    
    *** My Awesome Toolkit of Awesome ***

    Usage: ./awesome.rb foo [OPTION ...]

    Fooing myself

    I'm not sure what I'm doing, but I'm definitely fooing!

    Options:
        -i, --implement IMPLEMENT        An implement on which to be fooed
    
    $ ./awesome.rb --install-completions
    Completions installed in /home/rtweeks/.bashrc
    Source /home/rtweeks/.bash-complete/awesome.rb-completions for immediate availability.
    $ source /home/rtweeks/.bash-complete/awesome.rb-completions
    $ ./awesome.rb <tab><tab>
    foo   help
    $ ./awesome.rb f<tab>
    ↳ ./awesome.rb foo
    $ ./awesome.rb foo <tab>
    ↳ ./awesome.rb foo --
    $ ./awesome.rb foo --<tab><tab>
    --help       --implement
    $ ./awesome.rb foo --i<tab>
    ↳ ./awesome.rb foo --implement
    $ ./awesome.rb foo --implement <tab><tab>
    --help      awesome.rb
    $ ./awesome.rb foo --implement spoon
    I'm fooed on a spoon

### Defining Toolkit Commands

Just define tasks in the block of `Rake::ToolkitProgram.command_tasks` with `task` (i.e. `Rake::DSL#task`).  If `desc` is used to provide a description, the task will become visible in help and completions.

When a command task is initially defined, positional arguments to the command are available as an `Array` through `Rake::ToolkitProgram.args`.

### Option Parsing

This gem extends `Rake::Task` with a `#parse_args` method that creates a `Rake::ToolkitProgram::CommandOptionParser` (derived from the standard library's `OptionParser`) and an argument accumulator and `yield`s them to its block.
* The arguments accumulated through the `Rake::ToolkitProgram::CommandOptionParser` are available to the task in `Rake::ToolkitProgram.args`, replacing the normal `Array` of positional arguments.
* Use the `into:` keyword of `#parse_args` to provide a custom argument accumulator object for the associated command.  The default argument accumulator constructor can be defined with `Rake::ToolkitProgram.default_parsed_args`.  Without either of these, the default accumulator is a `Hash`.
* Options defined using `OptionParser#on` (or any of the variants) will print in the help for the associated command.

### Positional Arguments

Accessing positional arguments given after the command name depends on whether or not `Rake::Task(Rake::ToolkitProgram::TaskExt)#parse_args` has been called on the command task.  If this method is not called, positional arguments will be an `Array` accessible through `Rake::ToolkitProgram.args`.

When `Rake::Task(Rake::ToolkitProgram::TaskExt)#parse_args` is used:
* `Rake::ToolkitProgram::CommandOptionParser#capture_positionals` can be used to define how positional arguments are accumulated.
  * If the argument accumulator is a `Hash`, the default (without calling this method) is to assign the `Array` of positional arguments to the `nil` key of the `Hash`.
  * For other types of accumulators, the positional arguments are only accessible if `Rake::ToolkitProgram::CommandOptionParser#capture_positionals` is used to define how they are captured.
  * If a block is given to this method, the block of the method will receive the `Array` of positional arguments.  If it is passed an argument value, that value is used as the key under which to store the positional arguments if the argument accumulator is a `Hash`.
* `Rake::ToolkitProgram::CommandOptionParser#expect_positional_cardinality` can be used to set a rule for the count of positional arguments.  This will affect the _usage_ presented in the help for the associated command.
* `Rake::ToolkitProgram::CommandOptionParser#map_positional_args` may be used to transform (or otherwise process) positional arguments one at a time and in the context of options and/or arguments appearing earlier on the command line.

### Convenience Methods

* `Rake::Task(Rake::ToolkitProgram::TaskExt)#prohibit_args` is a quick way, for commands that accept no options or positional arguments, to declare this so the help and bash completions reflect this.  It is equivalent to using `#parse_args` and telling the parser `parser.expect_positional_cardinality(0)`.

* `Rake::ToolkitProgram::CommandOptionParser#no_positional_args!` is a shortcut for calling `#expect_positional_cardinality(0)` on the same object.

* `Rake::Task(Rake::ToolkitProgram::TaskExt)#invalid_args!` and `Rake::ToolkitProgram::CommandOptionParser#invalid_args!` are convenient ways to raise `Rake::ToolkitProgram::InvalidCommandLine` with a message.

## OptionParser in Rubies Before and After v2.4

The `OptionParser` class was extended in Ruby 2.4 to simplify capturing options into a `Hash` or other container implementing `#[]=` in a similar way.  This gem supports that, but it means that behavior varies somewhat between the pre-2.4 era and the 2.4+ era.  To have consistent behavior across that version change, the recommendation is to use a `Struct`, `OpenStruct`, or custom class to hold program options rather than `Hash`.

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

To run the tests, use `rake`, `rake test`, or `rspec spec`.  Tests can only be run on systems that support `Kernel#fork`, as this is used to present a pristine and isolated environment for setting up the tool.  If run using Ruby 2.3 or earlier, some tests will be pending because functionality expects Ruby 2.4's `OptionParser`.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/PayTrace/rake-toolkit_program.  For further details on contributing, see [CONTRIBUTING.md](./CONTRIBUTING.md).

