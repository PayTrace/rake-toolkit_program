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
# This file creates the Rake::ToolkitProgram::CommandOptionParser subclass
# of the standard library's OptionParser with supporting operations for a
# toolkit program, particularly around dealing with positional arguments.

require 'optparse'

module Rake
  module ToolkitProgram
    class CommandOptionParser < OptionParser
      IDENTITY = ->(v) {v}
      RUBY_GTE_2_4 = Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('2.4')
      
      def initialize(arg_dest)
        super()
        @argument_destination = arg_dest
        @positional_mapper = IDENTITY
      end
      
      attr_reader :argument_destination
      
      # Method override, see OptionParser#order!
      if RUBY_GTE_2_4
        def order!(argv = default_argv, into: nil, &nonopt)
          super(argv, into: into) do |arg|
            nonopt.call(@positional_mapper.call(arg))
          end
        end
      else
        def order!(argv = default_args, into: nil, &nonopt)
          raise ArgumentError, "Ruby #{RUBY_VERSION} cannot accept 'into' for OptionParser#order!" unless into.nil?
          super(argv) do |arg|
            nonopt.call(@positional_mapper.call(arg))
          end
        end
      end
      
      # Method override, see OptionParser#parse! -- though we don't do POSIXLY_COMPLIANT
      def parse!(argv = default_argv, into: nil)
        positionals = []
        do_positional_capture(positionals) if @precapture_positionals_array
        order!(argv, into: into, &positionals.method(:<<)).tap do
          argv[0, 0] = positionals
          do_positional_capture(argv) if !@precapture_positionals_array
          
          unless positional_cardinality_ok?(positionals.length)
            raise WrongArgumentCount.new(
              @positional_cardinality_test,
              positionals.length
            )
          end
        end
        return argv
      end
      
      ##
      # Query whether a given number of positional arguments is acceptable
      #
      # The result is based on the test established by
      # #expect_positional_cardinality, and returns true if no such test
      # has been established.
      #
      def positional_cardinality_ok?(n)
        pc_test = @positional_cardinality_test
        !pc_test || pc_test === n
      end
      
      ##
      # True unless positional arguments have been prohibited
      #
      # Technically, this test can only check that the established cardinality
      # test is for 0, given as an Integer.  If the test established by
      # #expect_positional_cardinality is a Proc that only returns true for
      # 0 or the Range <tt>0..0</tt>, this method will report incorrect
      # results.
      #
      def positional_arguments_allowed?
        @positional_cardinality_test != 0
      end
      
      ##
      # Return the established test for positional cardinality (or nil)
      #
      # If a test has been established by #expect_positional_cardinality,
      # this method returns that test.  Otherwise, it returns nil.
      #
      def positional_cardinality
        @positional_cardinality_test
      end
      
      ##
      # String explanation of the positional cardinality, for help
      #
      def positional_cardinality_explanation
        @positional_cardinality_explanation.tap do |explicit|
          return explicit if explicit
        end
        obscure_answer = "A rule exists about the number of positional arguments."
        
        case (pc_test = @positional_cardinality_test)
        when nil, 0 then nil
        when 1 then "Requires 1 positional argument."
        when Integer then "Requires #{pc_test} positional arguments."
        when Range then "Requires #{pc_test.to_inclusive} (inclusive) positional arguments."
        when Proc then begin
          [pc_test.call(:explain)].map do |exp|
            case exp
            when String then exp
            else obscure_answer
            end
          end[0]
        rescue StandardError
          obscure_answer
        end
        else obscure_answer
        end
      end
      
      ##
      # Explicitly define capture of positional (non-option) arguments
      #
      # When parsing into a Hash, the default is to store the Array of
      # remaining positional arguments in the +nil+ key.  This method
      # overrides that behavior by either specifying a specific key to
      # use or by specifying a block to call with the positional arguments,
      # which is much more useful when accumulating arguments to a non-Hash
      # object.  Passing +key+ or a block are mutually exclusive.
      #
      # +precapture_dest_array+ can be set to +true+ to cause the capture
      # to take place before the positional arguments are accumulated.  In this
      # case, the Array object yielded to the block (if this method is called
      # with a block) _must_ be stored, as it will be the recipient of all
      # positional arguments.  In any case, when this option is passed to this
      # method, capture behavior for the (empty) Array into which the
      # positional arguments will be stored is carried out _before_ option
      # parsing, and values are (after any transformation dictated by
      # #map_positional_args) stored in the positional arguments Array; there
      # is no option to store positionals for consumption by the command task
      # code in anything other than an Array.  Note that the Array into which
      # arguments are captured <i>is not</i> the same array either passed to
      # or returned from the #parse! (or #parse, for that matter) method.
      #
      # If multiple calls to this method are made, the last one is the one
      # that defines the behavior.
      #
      # +key+:: Key under which positionals shall be accumulated in a Hash
      # +precapture_dest_array+:: Capture before argument accumulation
      #
      def capture_positionals(key=nil, precapture_dest_array: false, &blk)
        if blk && !key.nil?
          raise ArgumentError, "either specify key or block"
        end
        @positionals_key = key
        @positionals_capture = blk
        @precapture_positionals_array = precapture_dest_array
      end
      
      ##
      # Constrain the number of positional arguments
      #
      # This is a declarative way of expressing how many positional (i.e.
      # non-option) arguments should be accepted by the command.  The
      # #=== (i.e. "case match") method of +cardinality_test+ is used to test
      # the length of the positional argument Array, raising
      # Rake::ToolkitProgram::WrongArgumentCount if #=== returns false.
      #
      # A special case exists when +cardinality_test+ is a Symbol: because
      # a Symbol could never match an Integer, Symbol#to_proc is called to
      # create a useful test.
      #
      # *NOTE* It is worth attention that Proc#=== is an alias for Proc#call,
      # so the operator argument is passed to the Proc.  This enables arbitrary
      # computation for the validity of the positional argument count,
      # syntactically aided by the "stabby-lambda" notation.
      #
      # While this gem will do its best to explain the argument cardinality,
      # +explanation+ provides an opportunity to explicitly provide a 
      # sentence to be included in the help about the allowed cardinality
      # (i.e. count) of positional arguments.
      #
      def expect_positional_cardinality(cardinality_test, explanation=nil)
        @positional_cardinality_explanation = explanation
        if cardinality_test.kind_of?(Symbol)
          cardinality_test.to_s.tap do |test_name|
            if explanation.nil? && test_name.end_with?('?')
              @positional_cardinality_explanation = (
                "Positional argument count must be #{test_name[0..-2].gsub('_', ' ')}."
              )
            end
          end
          cardinality_test = cardinality_test.to_proc
        end
        @positional_cardinality_test = cardinality_test
      end
      
      ##
      # Disallow positional arguments
      #
      # The command will raise Rake::ToolkitProgram::WrongArgumentCount if
      # any positional arguments are given.
      #
      def no_positional_args!
        expect_positional_cardinality(0)
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
      # Define a mapping function for positional arguments during accumulation
      #
      # The block given to this method will be called with each positional
      # argument in turn; the return value of the block will be acculumated
      # as the positional argument.  The block's computation may be purely
      # functional or it may refer to outside factors in its binding such as
      # accumulated values for options or preceding positional arguments.
      #
      def map_positional_args(&blk)
        raise ArgumentError, "block required" if blk.nil?
        @positional_mapper = blk
      end
      
      private
      def do_positional_capture(positionals)
        if @positionals_capture
          @positionals_capture.call(positionals)
        elsif argument_destination.kind_of?(Hash)
          argument_destination[@positionals_key] = positionals
        end
      end
    end
  end
end
