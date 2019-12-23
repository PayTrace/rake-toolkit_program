require 'rake/toolkit_program/help_styling'

describe Rake::ToolkitProgram::HelpStyling do
  it "is constructable" do
    expect {described_class.new}.to_not raise_error
  end
  
  it "uses ANSI escape codes for styling" do
    expect(subject.code "word").to include("\e[")
  end
end
