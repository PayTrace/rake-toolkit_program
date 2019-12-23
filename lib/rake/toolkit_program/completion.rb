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
# This file defines the bash completion behavior of the rake-toolkit_program
# library.

module Rake
  module ToolkitProgram
    def self.each_completion_script_line(static_options: nil, static_flags: nil)
      options = static_options || %Q{$("$1" --commands)}
      flags = (static_flags.shellescape if static_flags) || \
        ('' if static_options) || \
        %Q{$("$1" --flag-completion "${COMP_WORDS[@]}")}
      
      <<-END_BASH.dedent.each_line {|l| yield("  " + l)}
        COMPREPLY=()
        MY_WORDNUM=1
        if [ "${COMP_CWORD}" = 2 ] && [ "${COMP_WORDS[1]}" = help ]; then
          MY_WORDNUM=2
        elif [ "${COMP_CWORD}" != "1" ]; then
          HELP_FLAG="--help"
          if [ -n "${COMP_WORDS[$COMP_CWORD]}" ] && [ "${HELP_FLAG\#${COMP_WORDS[$COMP_CWORD]}}" = "$HELP_FLAG" ]; then
            # Word being completed is NOT a prefix of --help: don't offer --help
            :
          elif ! { echo " ${COMP_WORDS[*]}" | egrep -q '\\s(--help|-h|--\\s)'; }; then
            COMPREPLY=("--help")
          fi
          DO_COMPGEN=true
          if ! { echo " ${COMP_WORDS[*]}" | egrep -q '\\s(--help|-h|--\\s)'; }; then
            FLAGS_CANDIDATE=#{flags}
            if [ "$(echo "$FLAGS_CANDIDATE" | head -n1)" == '!NOFSCOMP!' ]; then
              DO_COMPGEN=false
              COMPREPLY+=($(echo "$FLAGS_CANDIDATE" | tail -n+2))
            else
              COMPREPLY+=($FLAGS_CANDIDATE)
            fi
          fi
          if $DO_COMPGEN && [ "${COMP_WORDS[$COMP_CWORD]}" != "--" ] && ! { echo " ${COMP_WORDS[*]}" | egrep -q '\\s(--help|-h)'; }; then
            COMPREPLY+=($(compgen -f -d -- "${COMP_WORDS[$COMP_CWORD]}"))
          fi
          return
        fi
        COMPREPLY=($(compgen -W "#{options}" -- "${COMP_WORDS[$MY_WORDNUM]}"))
      END_BASH
    end
  end
end


Rake::ToolkitProgram.command_tasks do # define task for shell completion
  task '--commands' do
    cmds = Rake::ToolkitProgram.available_commands(include: :listable)
    puts(cmds.map do |t|
      t.name[(Rake::ToolkitProgram::NAMESPACE.length + 1)..-1]
    end.join(' '))
  end
  
  task '--flag-completion' do
    program = Rake::ToolkitProgram
    begin
      script_path, command_name, *args = program.args
      command = program.find(command_name)
      next unless program::ArgParsingTask === command
      incomplete = args.pop
      candidate = command.argument_parser.candidate(incomplete.empty? ? '-' : incomplete)
      begin
        command.argument_parser.parse(args)
      rescue OptionParser::MissingArgument
        # We can't help complete flags because there is a flag that requires an
        # argument, but it's fine to build more
      rescue program::WrongArgumentCount
        # args doesn't have the right number of arguments, and adding flags
        # won't help, but it's fine to build more arguments -- so far, but see below
      rescue OptionParser::ParseError
        puts '!NOFSCOMP!'
      else
        if incomplete.empty? && !command.argument_parser.positional_cardinality_ok?(args.length + 1)
          puts '!NOFSCOMP!'
        end
        candidate.select! {|c| c.start_with?('--')}
        candidate = candidate.collect_concat do |c|
          if c =~ /^--\[(\w+-)\](.*)/
            ["--#{$2}", "--#{$1}#{$2}"]
          else
            [c]
          end
        end
        puts candidate
      end
    rescue StandardError
    end
  end
  
  task '--install-completions' do
    script_path = Pathname(
      Rake::ToolkitProgram.script_name(placeholder_ok: false)
    )
    
    profile_path, completions_dir = case Process.euid
    when 0
      ["/etc/profile", "/usr/local/lib/"]
    else
      ["~/.bash_profile", "~/.bash-complete"]
    end.map {|path_str| Pathname(path_str).expand_path}
    name_parts = [script_path.basename.to_s, 'completions']
    completions_fpath = completions_dir / name_parts.join('-')
    
    completions_fpath.dirname.mkpath
    completions_fpath.open('w', 0644) do |out|
      uniq_name = "_" + Random.new.bytes(20).unpack('H*').first
      out.puts "#{uniq_name}() {"
      Rake::ToolkitProgram.each_completion_script_line do |line|
        out.puts line
      end
      out.puts "}"
      out.puts "complete -F #{uniq_name} -o bashdefault #{script_path.basename}"
    end
    
    load_completions = %Q{source #{completions_fpath}}
    load_completions_split = Shellwords.split(load_completions)
    
    load_present = begin
      profile_path.each_line.any? do |line|
        begin
          Shellwords.split(line, drop_comment: true)
        rescue ArgumentError
          []
        end == load_completions_split
      end
    rescue Errno::ENOENT
      false
    end
    
    if load_present
      puts "Completions already installed in #{profile_path}"
    else
      profile_path.open('a') do |out|
        out.puts load_completions
      end
      puts "Completions installed in #{profile_path}"
      puts "Source #{completions_fpath} for immediate availability."
    end
  end
end
