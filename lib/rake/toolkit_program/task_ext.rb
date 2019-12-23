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
# This file defines the extensions to Rake::Task to support the
# rake-toolkit_program library.

module Rake
  module ToolkitProgram
    module TaskExt
      ##
      # Define argument parsing for a Rake::Task used as a command
      #
      # The block receives two arguments:
      #
      # 1.  a Rake::ToolkitProgram::CommandOptionParser (a subclass of
      #     OptionParser)
      # 2.  the argument accumulator object passed in as +into+
      #
      # When the subject task is invoked through Rake::ToolkitProgram.run,
      # the parser configured in this block is run against the _remaining_
      # arguments (after the command name).  The argument accumulator +into+
      # will be available as Rake::ToolkitProgram.args instead of the default
      # argument Array.
      #
      # Rake::ToolkitProgram::CommandOptionParser offers some useful extensions
      # around positional parameters, since the Array containing the remaining
      # arguments after parsing would be otherwise unavailable.
      #
      def parse_args(into: ToolkitProgram.new_default_parsed_args {Hash.new})
        parser, new_args = CommandOptionParser.new(into), into
        yield parser, new_args
        @arg_parser = parser
        extend ArgParsingTask
        return self
      end
      
      ##
      # Convenience method for raising Rake::ToolkitProgram::InvalidCommandLine
      #
      # The error raised is the standard error for an invalid command line
      # when using Rake::ToolkitProgram.
      #
      def invalid_args!(message)
        raise InvalidCommandLine, message
      end
      
      ##
      # Prohibit any arguments when this command is invoked
      #
      # Help arguments are still allowed, as the special 'help' command is the
      # one invoked when they are present.
      #
      def prohibit_args
        parse_args(into: []) {|parser| parser.no_positional_args!}
      end
    end
    Rake::Task.include TaskExt
    
    module ArgParsingTask
      def argument_parser
        @arg_parser
      end
      
      def parsed_arguments
        @arg_parser.argument_destination
      end
    end
  end
end
