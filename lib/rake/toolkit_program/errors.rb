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
# This file defines errors classes used by Rake::ToolkitProgram.

module Rake
  module ToolkitProgram
    class UnknownName < StandardError
      include ProgramExitFromError
      exit_with_code 2
      
      def initialize(name)
        super("The command '#{name}' is not known")
        @name = name.to_s.dup.freeze
      end
      
      attr_reader :name
      
      def print_error_message
        s = ToolkitProgram.help_styling
        $stderr.puts "#{s.error_marker '[ERROR]'} #{s.code name} is not a recognized command name."
        $stderr.puts "Use #{s.code "#{ToolkitProgram.script_name} help"} for a list of available commands."
      end
    end
    
    class NoCommand < StandardError
      include ProgramExitFromError
      exit_with_code 2
      
      def print_error_message
        s = ToolkitProgram.help_styling
        $stderr.puts "#{s.error_marker '[ERROR]'} A command is required."
        $stderr.puts "Use #{s.code "#{ToolkitProgram.script_name} help"} for a list of available commands."
      end
    end
    
    class InvalidCommandLine < StandardError
      include ProgramExitFromError
      exit_with_code 2
      
      def print_error_message
        s = ToolkitProgram.help_styling
        $stderr.puts "#{s.error_marker 'ERROR'} #{self}"
      end
    end
    
    class WrongArgumentCount < InvalidCommandLine
      include ProgramExitFromError
      exit_with_code 2
      
      def initialize(cardinality_test, actual_count)
        super(case cardinality_test
        when Integer
          "expected #{cardinality_test} arguments, got #{actual_count}"
        when Range
          "expected #{cardinality_test.to_inclusive} (inclusive) arguments, got #{actual_count}"
        else
          "#{actual_count} arguments given"
        end)
      end
    end
  end
end
