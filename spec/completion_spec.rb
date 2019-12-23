require 'run_helper'

describe 'Rake::ToolkitProgram completion' do
  def generate_for(*args)
    @completions = get_completions(*args)
  end
  
  it "generates command options for the first argument" do
    generate_for(%w[foo bar], [""])
    expect(@completions.sort).to eq(%w[bar foo help])
  end
  
  it "generates help option for a second argument" do
    generate_for(%w[foo bar], ["foo", ""])
    expect(@completions).to include('--help')
  end
  
  it "generates help option for a third argument" do
    generate_for(%w[foo bar], ["foo", "qux", ""])
    expect(@completions).to include('--help')
  end
  
  %w[-h --help].each do |help_flag|
    it "does not generate completions after #{help_flag.inspect}" do
      generate_for(%w[foo bar], ["foo", help_flag])
      expect(@completions).to be_empty
    end
  end
  
  it "does not generate help option completion after '--'" do
    generate_for(%w[foo bar], ["foo", '--', ''])
    expect(@completions).to_not include('--help')
  end
  
  it "generates help flag to complete '--'" do
    generate_for(%w[foo bar], ["foo", '--'])
    expect(@completions).to eq(['--help'])
  end
  
  it "does not generate the incomplete word" do
    generate_for(%w[foo bar], ["foo", "Rak"])
    expect(@completions.select {|s| s.include?(' ')}).to be_empty
  end
  
  it "only offers the '--help' flag if the incomplete word is a prefix of the flag" do
    generate_for(%w[foo bar], ["foo", "Rak"])
    expect(@completions).to_not include('--help')
  end
  
  it "generates commands for the second argument if the first is 'help'" do
    generate_for(%w[foo bar], ["help", ""])
    expect(@completions).to include("foo")
  end
  
  # TODO: Generating flags in completion
  it "does not generate flags for the command-name argument" do
    generate_for(%w[foo bar], [""], flags: %w[--message])
    expect(@completions).to_not include(a_string_including('--'))
  end
  
  it "generates flags for argument 2" do
    generate_for(%w[foo bar], ["foo", ""], flags: %w[--message])
    expect(@completions).to include('--help')
    expect(@completions).to include('--message')
  end
  
  it "generates flags for argument 3" do
    generate_for(%w[foo bar], ["foo", "zapf", ""], flags: %w[--message])
    expect(@completions).to include('--help')
    expect(@completions).to include('--message')
  end
  
  it "does not generate flags for argument 2 when argument 1 is 'help'" do
    generate_for(%w[foo bar], ["help", ""], flags: %w[--message])
    expect(@completions).not_to include('--help')
    expect(@completions).not_to include('--message')
  end
  
  it "does not add file or directory completion if the program's flags return an error" do
    generate_for(%w[foo bar], ["foo", ""], flags: %w[!NOFSCOMP! --message])
    expect(@completions).not_to include('Rakefile')
  end
  
  it "does generate flags, even when suppressing file and directory completion" do
    generate_for(%w[foo bar], ["foo", ""], flags: %w[!NOFSCOMP! --message])
    expect(@completions).to include('--help')
    expect(@completions).to include('--message')
  end
end
