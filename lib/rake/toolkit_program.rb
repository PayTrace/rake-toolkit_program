# coding: utf-8
# frozen_string_literal: true

# Copyright 2019 PayTrace, Inc.
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# This is the main file of the rake-toolkit_program library.

require "rake/toolkit_program/version"
require 'dedent'
require 'optparse'
require 'pathname'
require 'rake'
require 'shellwords'
require 'program_exit_from_error'

%w[
  command_option_parser
  errors
  help_styling
  task_ext
  utils
].each do |support_file|
  require "rake/toolkit_program/#{support_file}"
end

# From https://stackoverflow.com/a/8781522/160072
Rake::TaskManager.record_task_metadata = true

module Rake
  ##
  # Tools to easily build CLI programs for UNIX-like systems
  #
  # In addition to any commands defined, this module provides:
  #
  # * a <tt>--install-completions</tt> command
  # * a <tt>help</tt> command
  # * <tt>-h</tt> and <tt>--help</tt> flags (until <tt>--</tt> is encountered)
  #
  # Use .command_tasks to define commands and .run to execute the CLI.
  #
  module ToolkitProgram
    extend Rake::DSL
    NAMESPACE="cli_cmd"
    
    def self.title=(s)
      @title = s
    end
    
    def self.title
      @title || "#{script_name.capitalize} Toolkit Program"
    end
    
    @help_styling = HelpStyling.new
    ##
    # Access the HelpStyling object used for styling generated help
    #
    def self.help_styling
      if block_given?
        yield @help_styling
      end
      @help_styling
    end
    
    def self.task_name(name)
      "#{NAMESPACE}:#{name}"
    end
    
    def self.is_task_name?(name)
      name.to_s.start_with?(NAMESPACE + ':')
    end
    
    def self.known_command?(name)
      !name.nil? && Rake::Task.task_defined?(task_name(name))
    end
    
    def self.available_commands(include: :all)
      Rake::Task.tasks.select {|t| is_task_name?(t.name)}.reject do |t|
        case include
        when :all then false
        when :listable then t.comment.to_s.empty?
        else raise ArgumentError, "#{include.inspect} not valid as include:"
        end
      end
    end
    
    def self.find(name, raise_if_missing: false)
      case 
      when known_command?(name)
        Rake::Task[task_name(name)]
      when raise_if_missing
        raise UnknownName.new(name)
      end
    end
    
    ##
    # Run a CLI
    #
    # Idiomatically, this is usually invoked as:
    #
    #   if __FILE__ == $0
    #     Rake::ToolkitProgram.run(on_error: :exit_program!)
    #   end
    #
    # The first element of +args+ (which defaults to ARGV) names the command to
    # execute.  Additional arguments are available via .args.
    #
    # +on_error+ may be anything supporting #to_proc (including a Proc or
    # lambda) and accepts one parameter, which is an error object that is
    # guaranteed to have an #exit_program! method.  Since Symbol#to_proc
    # creates a Proc that sends the target Symbol to the single argument of the
    # created Proc, passing <tt>:exit_program!</tt> (as in the idiomatic
    # invocation) results in program exit according to the error being handled.
    #
    # If the error to be handled by +on_error+ does not #respond_to?
    # <tt>:exit_program!</tt>, it will be extended with ProgramExitFromError,
    # giving it default #exit_program! behavior of printing the error message
    # on STDERR and exiting with code 1.
    #
    # When +on_error+ is nil, any errors are allowed to propagate out of #run.
    #
    def self.run(argv=ARGV, on_error: nil)
      name, *@args = argv
      raise NoCommand if name.nil?
      if_help_request {name, args[0] = 'help', name}
      specified_task = find(name, raise_if_missing: true)
      if specified_task.kind_of?(ArgParsingTask)
        new_args = specified_task.parsed_arguments
        specified_task.argument_parser.parse(
          *case new_args
          when Hash then [args, {into: new_args}]
          else [args]
          end
        )
        @args = new_args
      end
      specified_task.invoke
    rescue StandardError => error
      error.extend(ProgramExitFromError) unless error.respond_to?(:exit_program!)
      
      case
      when on_error then on_error.to_proc
      else method(:raise)
      end.call(error)
    end
    
    def self.if_help_request
      if args[0] == 'help'
        yield
      else
        args.each do |a|
          case a
          when '--'
            break
          when '-h', '--help'
            yield
            break
          end
        end
      end
    end
    
    def self.args
      @args
    end
    
    ##
    # Specify a standard type for parsed argument accumulation
    #
    # If this is called, the block is used to construct the argument
    # accumulator if no accumulator object is explicitly specified when calling
    # Rake::Task(Rake::ToolkitProgram::TaskExt)#parse_args.  This helps
    # Rake::ToolkitProgram.args be more consistent throughout the client
    # program.
    #
    def self.default_parsed_args(&blk)
      @default_parsed_args_creator = blk
    end
    
    ##
    # Construct a parsed argument accumulator
    #
    # The constructor can be defined via the block of .default_parsed_args
    #
    def self.new_default_parsed_args(&blk)
      (@default_parsed_args_creator || blk).call
    end
    
    def self.script_name(placeholder_ok: true)
      case 
      when $0 != '-' then $0
      when ENV['THIS_SCRIPT'] then ENV['THIS_SCRIPT']
      when placeholder_ok then '<script-name>'
      else raise "Script name unknown"
      end
    end
    
    ##
    # Access the Rake namespace for CLI tasks/commands
    #
    # Defining Rake tasks inside the block of this method (with #task) defines
    # the tasks such that they are recognized as invocable from the command
    # line (via the first command line argument, or the first element of +args+
    # passed to .run).
    #
    # To make commands/tasks defined in this block visible in the help and
    # shell completion, use #desc to describe the task.
    #
    def self.command_tasks
      namespace(NAMESPACE) {yield}
    end
  end
end

# Require this at the end because it defines tasks, using some methods defined
# above
%w[
  completion
  help
].each {|task_file| require "rake/toolkit_program/#{task_file}"}
