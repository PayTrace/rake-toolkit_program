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
# This file defines a way to handle errors when running a CLI.

##
# Idiomatic support for dealing with errors during CLI use
#
# Rather than allowing an error to propagate to the top level of the
# interpreter, this module provides the #exit_program! method, which
# prints a message to STDERR and exits with an exit code of 1 (unless
# otherwise specified with .exit_with_code).
#
# For debugging support, this module also exposes the #exit_code it
# would use to exit the program were #exit_program! called.
#
module ProgramExitFromError
  def self.included(klass)
    klass.extend(ClassMethods)
  end
  
  module ClassMethods
    def exit_with_code(n)
      @exit_code = n
    end
    
    attr_reader :exit_code
  end
  
  def exit_code
    self.class.instance_variable_get(:@exit_code) || 1
  end
  
  def exit_program!
    print_error_message
    Kernel.exit(exit_code)
  end
  
  def print_error_message
    $stderr.puts("! ERROR: #{self}".bold.red)
  end
end
