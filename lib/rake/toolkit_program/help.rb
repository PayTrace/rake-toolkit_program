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
# This file implements the 'help' command of rake-toolkit_program.

module Rake
  module ToolkitProgram
    command_tasks do # define 'help' command
      task '-h' => :help
      task '--help' => :help

      help_styling {|s| desc <<-END_HELP.dedent
        Show a list of commands or details of one command
        
        To get help on a specific command, put the command's name as the first
        argument after #{s.code('help')} or use #{s.code('-h')} or #{s.code('--help')} after the command's name.
        END_HELP
      }
      task :help do
        style = help_styling
        
        puts
        puts style.title(title)
        puts
        
        options_usage = "[#{style.param('OPTION ...')}]"
        unless (task = find(args[0]))
          puts "Usage: #{style.code(script_name)} #{style.param('COMMAND')} #{options_usage}"
          puts
          puts "Avaliable options vary depending on the command given. For details"
          puts "of a particular command, use:"
          puts
          puts "    #{style.code(script_name)} #{style.code('help')} #{style.param('COMMAND')}"
          puts
          puts "Commands:"
          cmds = available_commands(include: :listable)
          nsp_len = NAMESPACE.length + 1
          name_field_length = cmds.map {|t| t.name.length - nsp_len}.max
          cmds.each do |t|
            puts "    #{style.code(t.name[nsp_len..-1].rjust(name_field_length))}   #{t.comment}"
          end
          puts
          puts "Use #{style.code('help')} #{style.param('COMMAND')} to get more help on a specific command."
        else
          cmd_name = args[0]
          arg_parser = (ArgParsingTask === task) ? task.argument_parser : nil
          usage_parts = [
            style.code(script_name),
            style.code(cmd_name),
          ]
          option_count = arg_parser ? arg_parser.enum_for(:summarize).count : 0
          usage_parts << options_usage if !arg_parser || option_count > 0
          generic_arg_usage = "[#{style.param('ARG')} ...]"
          if arg_parser
            usage_parts.concat case arg_parser.positional_cardinality
            when 0
              []
            when Integer
              [style.param('ARG')] * arg_parser.positional_cardinality
            when ->(card) {Range === card && card.to_inclusive == (0..1)}
              ["[#{style.param('ARG')}]"]
            when ->(card) {Range === card && card.begin > 0}
              [generic_arg_usage[1..-2]]
            else
              [generic_arg_usage]
            end
          else
            usage_parts << generic_arg_usage
          end
          puts "Usage: #{usage_parts.join(' ')}"
          puts
          puts task.full_comment
          if arg_parser
            if (pos_exp = arg_parser.positional_cardinality_explanation)
              puts
              puts pos_exp
            end
          end
          if option_count > 0
            puts
            puts "Options:"
            arg_parser.summarize do |optline|
              puts optline
            end
          end
        end
        puts
      end
    end
  end
end
