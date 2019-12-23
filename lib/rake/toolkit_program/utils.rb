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
# This file defines utility extensions to standard library modules.

module Rake
  module ToolkitProgram
    module RangeConversion
      ##
      # Return a Range the includes the end
      #
      # This method will error if the subject Range excludes the end but
      # the bounds are not Integers.
      #
      def to_inclusive
        return self unless exclude_end?
        raise "only Integer Ranges can be converted" if [self.begin, self.end].any? {|v| !(Integer === v)}
        return (self.begin..(self.end - 1))
      end
    end
    Range.include RangeConversion
  end

  module ToolkitProgram::ShellwordsExt
    def split(s, drop_comment: false)
      super(s).tap do |r|
        break r[0..((r.index {|i| i.start_with?('#')} || 0) - 1)] if drop_comment
      end
    end
    class <<Shellwords
      prepend ToolkitProgram::ShellwordsExt
    end
  end
end
