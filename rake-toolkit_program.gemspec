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
# This is the gemspec file for the rake-toolkit_program gem.

require 'pathname'
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rake/toolkit_program/version'

Gem::Specification.new do |spec|
  spec.name          = "rake-toolkit_program"
  spec.version       = Rake::ToolkitProgram::VERSION
  spec.authors       = ["Richard Weeks"]
  spec.email         = ["rtweeks21@gmail.com"]
  spec.license       = 'Apache-2.0'

  spec.summary       = %q{Build powerful CLI toolkits with simple code}
  spec.description   = (Pathname(__FILE__).dirname / "README.md").read()
  spec.homepage      = "https://github.com/PayTrace/rake-toolkit_program"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  
  spec.add_dependency "rake", ">= 10.0"
  spec.add_dependency "colorize", "~> 0.8"
  spec.add_dependency "dedent", "~> 1.0"

  spec.add_development_dependency "bundler", ['>= 1.13', '< 3']
  spec.add_development_dependency "rspec", "~> 3.9"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "pry-coolline"
end
