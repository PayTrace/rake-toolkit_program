require 'run_helper'
require 'ostruct'

describe Rake::ToolkitProgram do
  include Rake::DSL
  
  it "returns exit code 2 for unknown command" do
    run_tool('xznynngh', expect_exit_code: 2)
  end
  
  let(:nanu_nanu) {'nanu-nanu'}
  let(:custom_title) {'Gollygoops'}
  
  it "recognizes a defined command" do
    run_tool(nanu_nanu) {
      described_class.command_tasks do
        task nanu_nanu do
          
        end
      end
    }
  end
  
  it "carries out the named command" do
    expected_phrase = "Iggily biggily"
    output = run_tool(nanu_nanu) {
      described_class.command_tasks do
        task nanu_nanu do
          puts expected_phrase
        end
      end
    }
    expect(output).to include(expected_phrase)
  end
  
  context ".args" do
    it "makes additional arguments available to the task" do
      expected_phrase = "Iggily biggily"
      output = run_tool(nanu_nanu, expected_phrase) {
        described_class.command_tasks do
          task nanu_nanu do
            puts described_class.args[0]
          end
        end
      }
      expect(output).to include(expected_phrase)
    end
  end
  
  context "Rake::Task(Rake::ToolkitProgram::TaskExt)#parse_args" do
    it "populates a Hash by default" do
      pending("needs Ruby 2.4+ OptionParser") if gemver(RUBY_VERSION) < gemver('2.4.0')
      expected_phrase = "Passed on command line"
      output = run_tool(nanu_nanu, '-m', expected_phrase) {
        described_class.command_tasks do
          desc "Say hello, Ork style!"
          task nanu_nanu do
            puts described_class.args.fetch(:m, "Default message")
          end.parse_args do |grab_arg|
            grab_arg.on('-m MESSAGE')
          end
        end
      }
      expect(output).to include(expected_phrase)
    end
    
    it "can populate an arbitrary .args object" do
      expected_phrase = "Iggily biggily"
      output = run_tool(nanu_nanu, '-m', expected_phrase) {
        described_class.command_tasks do
          desc "Say hello, Ork style!"
          task nanu_nanu do
            puts (described_class.args.message || "Nanu, nanu")
          end.parse_args(into: OpenStruct.new) do |parser, args|
            parser.on('-m MESSAGE') do |m|
              args.message = m
            end
          end
        end
      }
      expect(output).to include(expected_phrase)
    end
    
    it "captures positionals to a Hash in the nil entry by default" do
      expected_phrase = "Passed on command line"
      output = run_tool(nanu_nanu, '-o', 'garbage.txt', expected_phrase) {
        described_class.command_tasks do
          desc "Say hello, Ork style!"
          task nanu_nanu do
            puts (described_class.args[nil][0] || "Default message")
          end.parse_args do |grab_arg|
            grab_arg.accept(Pathname)
            grab_arg.on('-o OUTFILE', Pathname)
          end
        end
      }
      expect(output).to include(expected_phrase)
    end
    
    it "can capture positionals to an arbitrary key in a Hash" do
      expected_phrase = "Passed on command line"
      output = run_tool(nanu_nanu, '-o', 'garbage.txt', expected_phrase) {
        described_class.command_tasks do
          desc "Say hello, Ork style!"
          task nanu_nanu do
            puts (described_class.args[:pargs][0] || "Default message")
          end.parse_args do |grab_arg|
            grab_arg.accept(Pathname)
            grab_arg.on('-o OUTFILE', Pathname)
            grab_arg.capture_positionals(:pargs)
          end
        end
      }
      expect(output).to include(expected_phrase)
    end
    
    it "can capture positionals and flags with arbitrary code" do
      expected_phrase = "Iggily biggily"
      output = run_tool(nanu_nanu, '-o', 'garbage.txt', expected_phrase) {
        described_class.command_tasks do
          desc "Say hello, Ork style!"
          task nanu_nanu do
            puts (described_class.args.pargs[0] || "Nanu, nanu")
          end.parse_args(into: OpenStruct.new) do |parser, args|
            parser.accept(Pathname)
            parser.on('-o OUTFILE', Pathname) do |path|
              args.outpath = path
            end
            parser.capture_positionals do |array|
              args.pargs = array
            end
          end
        end
      }
      expect(output).to include(expected_phrase)
    end
    
    it "can set expectations for positional argument count into Hash" do
      pending("needs Ruby 2.4+ OptionParser") if gemver(RUBY_VERSION) < gemver('2.4.0')
      run_tool(nanu_nanu, %w[a b c], expect_exit_code: 2) {
        described_class.command_tasks do
          desc "Say hello, Ork style!"
          task nanu_nanu do
            puts "Nanu, nanu"
          end.parse_args do |grab_arg|
            grab_arg.expect_positional_cardinality(1..2)
          end
        end
      }
    end
    
    it "can set expectations for positional argument count into other-than-Hash" do
      run_tool(nanu_nanu, expect_exit_code: 2) {
        described_class.command_tasks do
          desc "Say hello, Ork style!"
          task nanu_nanu do
            puts "Nanu, nanu"
          end.parse_args(into: OpenStruct.new) do |grab_arg|
            grab_arg.expect_positional_cardinality(1..2)
          end
        end
      }
    end
    
    context "complex positional argument count expectation" do
      it "can succeed" do
        run_tool(nanu_nanu, 'foo', 'bar', expect_exit_code: 0) {
          described_class.command_tasks do
            desc "Say hello, Ork style!"
            task nanu_nanu do
              puts "Nanu, nanu"
            end.parse_args(into: OpenStruct.new) do |grab_arg|
              grab_arg.expect_positional_cardinality :even?
            end
          end
        }
      end
      
      it "can fail" do
        run_tool(nanu_nanu, 'foo', expect_exit_code: 2) {
          described_class.command_tasks do
            desc "Say hello, Ork style!"
            task nanu_nanu do
              puts "Nanu, nanu"
            end.parse_args(into: OpenStruct.new) do |grab_arg|
              grab_arg.expect_positional_cardinality :even?
            end
          end
        }
      end
      
      it "can be arbitrary computation, even referencing captured positionals" do
        run_tool(nanu_nanu, 'foo', 'bar', 'baz') {
          described_class.command_tasks do
            desc "Say hello, Ork style!"
            task nanu_nanu do
              puts "Nanu, nanu"
            end.parse_args(into: OpenStruct.new) do |grab_arg, args|
              grab_arg.capture_positionals {|pargs| args.pargs = pargs}
              grab_arg.expect_positional_cardinality ->(n) {n >= 1 && n == args.pargs.length}
            end
          end
        }
      end
    end
    
    it "can idiomatically prohibit positional arguments" do
      run_tool(nanu_nanu, 'foo', expect_exit_code: 2) {
        described_class.command_tasks do
          desc "Say hello, Ork style!"
          task nanu_nanu do
            puts "Nanu, nanu"
          end.parse_args(into: OpenStruct.new) do |parser|
            parser.no_positional_args!
          end
        end
      }
    end
    
    it "allows options even when positional arguments are idiomatically prohibited" do
      run_tool(nanu_nanu, %w[-m howdy], expect_exit_code: 0) {
        described_class.command_tasks do
          desc "Say hello, Ork style!"
          task nanu_nanu do
            puts "Nanu, nanu"
          end.parse_args(into: OpenStruct.new) do |parser, args|
            parser.no_positional_args!
            parser.on('-m MESSAGE') {|val| args.message = val}
          end
        end
      }
    end
    
    it "(without into:) uses the program-wide default argument accumulator" do
      expected_phrase = "Iggily biggily"
      run_tool(nanu_nanu, '-m', expected_phrase) {
        described_class.default_parsed_args {OpenStruct.new}
        
        described_class.command_tasks do
          desc "Say hello, Ork style!"
          task nanu_nanu do
            puts (described_class.args.message || "Nanu, nanu")
          end.parse_args do |parser, args|
            parser.on('-m MESSAGE') do |m|
              args.message = m
            end
          end
        end
      }
      
      run_tool(nanu_nanu, '-m', expected_phrase, expect_exit_code: 1) {
        # NOTE: not calling described_class.default_parsed_args, so Hash.new
        # is the default args accumulator
        
        described_class.command_tasks do
          desc "Say hello, Ork style!"
          task nanu_nanu do
            puts (described_class.args.message || "Nanu, nanu")
          end.parse_args do |parser, args|
            parser.on('-m MESSAGE') do |m|
              args.message = m
            end
          end
        end
      }
    end
  end
  
  context "Rake::Task(Rake::ToolkitProgram::TaskExt)#prohibit_args" do
    it "prohibits positional arguments without a #parse_args block" do
      run_tool(nanu_nanu, 'foo', expect_exit_code: 2) {
        described_class.command_tasks do
          desc "Say hello, Ork style!"
          task nanu_nanu do
            puts "Nanu, nanu"
          end.prohibit_args
        end
      }
    end
  end
  
  context 'help command' do
    it "is intrinsic" do
      run_tool('help')
    end
    
    it "does not list an undescribed, defined command" do
      output = run_tool('help') {
        described_class.command_tasks do
          task nanu_nanu
        end
      }
      expect(output).to_not include(nanu_nanu)
    end
    
    it "lists a defined, described command" do
      output = run_tool('help') {
        described_class.command_tasks do
          desc "Greet those from Ork"
          task nanu_nanu
        end
      }
      expect(output).to include(nanu_nanu)
    end
    
    it "only shows the command summary when invoked toolkit-wide" do
      output = run_tool('help') {
        described_class.command_tasks do
          desc %Q{Greet those from Ork
          
          This is especially applicable to Orson, and may also be used as a
          farewell.
          }
          task nanu_nanu
        end
      }
      expect(output).to include('Greet those from Ork')
      expect(output).to_not include('applicable to Orson')
    end
    
    it "shows the full command summary when invoked for the command" do
      output = run_tool('help', nanu_nanu) {
        described_class.command_tasks do
          desc %Q{Greet those from Ork
          
          This is especially applicable to Orson, and may also be used as a
          farewell.
          }
          task nanu_nanu
        end
      }
      expect(output).to include('Greet those from Ork')
      expect(output).to include('applicable to Orson')
    end
    
    it "shows the full command summary when 'help' invoked after command" do
      output = run_tool(nanu_nanu, 'help') {
        described_class.command_tasks do
          desc %Q{Greet those from Ork
          
          This is especially applicable to Orson, and may also be used as a
          farewell.
          }
          task nanu_nanu
        end
      }
      expect(output).to include('Greet those from Ork')
      expect(output).to include('applicable to Orson')
    end
    
    %w[-h --help].each do |flag|
      it "show command-specific help if '#{flag}' is any argument" do
        output = run_tool(nanu_nanu, *(['bork'] * (Random.rand(4) + 1)), flag) {
          described_class.command_tasks do
            desc %Q{Greet those from Ork
            
            This is especially applicable to Orson, and may also be used as a
            farewell.
            }
            task nanu_nanu
          end
        }
        expect(output).to include('Greet those from Ork')
        expect(output).to include('applicable to Orson')
      end
    end
    
    context 'options' do
      it "shows help on options parsed with Rake::Task#parse_args" do
        output = run_tool(nanu_nanu, 'help') {
          described_class.command_tasks do
            desc %Q{Greet those from Ork
            
            This is especially applicable to Orson, and may also be used as a
            farewell.
            }
            task nanu_nanu do
              
            end.parse_args(into: OpenStruct.new) do |parser, args|
              parser.on('--person PERSON') {|v| args.person = v}
            end
          end
        }
        expect(output).to include('--person')
      end
      
      it "does not show an options section when no options are defined" do
        output = run_tool(nanu_nanu, 'help') {
          described_class.command_tasks do
            desc %Q{Greet those from Ork
            
            This is especially applicable to Orson, and may also be used as a
            farewell.
            }
            task nanu_nanu do
              
            end.parse_args(into: OpenStruct.new) do |parser, args|
              parser.no_positional_args!
            end
          end
        }
        expect(output).to_not match(/option/i)
      end
    end
  end
  
  context "custom title" do
    it "shows in toolkit-wide help" do
      output = run_tool('help') {
        described_class.title = custom_title
      }
      expect(output).to include(custom_title)
    end
    
    it "shows in command-specific help" do
      output = run_tool('help', nanu_nanu) {
        described_class.title = custom_title
        described_class.command_tasks do
          desc "Greet those from Ork"
          task nanu_nanu
        end
      }
      expect(output).to include(custom_title)
    end
  end
  
  context "raising errors" do
    it "uses a subclass of InvalidCommandLine to indicate improper conditional argument count" do
      run_tool(nanu_nanu, 'foo', expect_error: described_class::WrongArgumentCount) {
        described_class.command_tasks do
          desc "Say hello, Ork style!"
          task nanu_nanu do
            puts "Nanu, nanu"
          end.prohibit_args
        end
      }
      expect(described_class::WrongArgumentCount).to be < described_class::InvalidCommandLine
    end
    
    it "`on_error: :exit_program!` produces valid error message when no command is given" do
      run_tool(expect_error: Rake::ToolkitProgram::NoCommand) {|options|
        described_class.command_tasks do
          desc "Say hello, Ork style!"
          task nanu_nanu do
            puts "Nanu, nanu"
          end.prohibit_args
        end
      }
    end
  end
  
  context "flag completion" do
    it "includes flags in the output for a 'fresh' argument" do
      output = run_tool('--flag-completion', '.', nanu_nanu, '') {
        described_class.command_tasks do
          desc "Greet those from Ork"
          task nanu_nanu do
            
          end.parse_args(into: OpenStruct.new) do |parser|
            parser.on('--message MESSAGE')
          end
        end
      }
      expect(output).to include('--message')
    end
    
    context "(when completing argument of option)" do 
      it "does not include flags" do
        output = run_tool('--flag-completion', '.', nanu_nanu, '--message', '') {
          described_class.command_tasks do
            desc "Greet those from Ork"
            task nanu_nanu do
              
            end.parse_args(into: OpenStruct.new) do |parser|
              parser.on('--message MESSAGE')
              parser.on('--to PERSON')
            end
          end
        }.split("\n")
        expect(output).not_to include(a_string_starting_with('--'))
      end
      
      it "allows filesystem completion" do
        output = run_tool('--flag-completion', '.', nanu_nanu, '--message', '') {
          described_class.command_tasks do
            desc "Greet those from Ork"
            task nanu_nanu do
              
            end.parse_args(into: OpenStruct.new) do |parser|
              parser.on('--message MESSAGE')
              parser.on('--to PERSON')
            end
          end
        }.split("\n")
        expect(output).not_to include('!NOFSCOMP!')
      end
    end
    
    it "does not include flags when the positional argument count violates the expectation" do
      output = run_tool('--flag-completion', '.', nanu_nanu, 'foo', 'bar', '') {
        described_class.command_tasks do
          desc "Greet those from Ork"
          task nanu_nanu do
            
          end.parse_args(into: OpenStruct.new) do |parser|
            parser.expect_positional_cardinality 1
            parser.on('--message MESSAGE')
          end
        end
      }.split("\n")
      expect(output).not_to include(a_string_starting_with('--'))
    end
    
    it "suppresses all completion when a bad flag is present" do
      output = run_tool('--flag-completion', '.', nanu_nanu, '--bork', '') {
        described_class.command_tasks do
          desc "Greet those from Ork"
          task nanu_nanu do
            
          end.parse_args(into: OpenStruct.new) do |parser|
            parser.expect_positional_cardinality 1
            parser.on('--message MESSAGE')
          end
        end
      }.split("\n")
      expect(output).to eq(['!NOFSCOMP!'])
    end
    
    it "does not generate short flags" do
      output = run_tool('--flag-completion', '.', nanu_nanu, '') {
        described_class.command_tasks do
          desc "Greet those from Ork"
          task nanu_nanu do
            
          end.parse_args(into: OpenStruct.new) do |parser|
            parser.on('-m', '--message MESSAGE')
          end
        end
      }.split("\n")
      expect(output).to include('--message')
      expect(output).to_not include('-m')
    end
    
    it "generates flags after an on/off option" do
      output = run_tool('--flag-completion', '.', nanu_nanu, '--formatted', '') {
        described_class.command_tasks do
          desc "Greet those from Ork"
          task nanu_nanu do
            
          end.parse_args(into: OpenStruct.new) do |parser|
            parser.on('--message MESSAGE')
            parser.on('--[no-]formatted')
          end
        end
      }.split("\n")
      expect(output).to include('--message')
      expect(output).to include('--formatted')
      expect(output).to include('--no-formatted')
    end
  end
end
