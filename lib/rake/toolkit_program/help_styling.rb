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
# This file defines the HelpStyling class, used to style the help output
# of a Rake::ToolkitProgram.

module Rake
  module ToolkitProgram
    ##
    # An object that captures styling rules for a CLI program
    #
    # This class defines several methods that either configure a styling
    # transformation or apply the configured transformation, depending on the
    # argument type.  These methods are defined with .define_style for
    # consistency.
    #
    # Each "style" method (e.g. #title) "learns" how to apply its style if
    # passed anything responding to #to_proc and applies its current style
    # transformation if passed a string.
    #
    class HelpStyling
      IDENTITY = -> (s) {s}
      
      def initialize
        super
        begin
          require 'colorize'
        rescue LoadError
          title ->(s) {"*** #{s} ***"}
        else
          title ->(s) {"*** #{s} ***".light_white.bold.on_blue}
          code  ->(s) {s.bold}
          param ->(s) {s.italic}
          error_marker ->(s) {s.bold.red.on_black}
        end
      end
      
      def self.define_style(*names)
        names.each do |name|
          vname = "@#{name}".to_sym
          define_method(name) do |s|
            case 
            when String === s then (instance_variable_get(vname) || IDENTITY)[s]
            when s.respond_to?(:to_proc) then instance_variable_set(vname, s.to_proc)
            else raise ArgumentError, "\##{name} accepts a String or Proc"
            end
          end
        end
      end
      
      define_style :title, :code, :param, :error_marker
    end
  end
end
