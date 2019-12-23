require 'rake/toolkit_program'
require 'ostruct'

describe Rake::ToolkitProgram::CommandOptionParser do
  let(:parser) {described_class.new(OpenStruct.new)}
  
  context '#positional_cardinality_ok?' do
    it "responds according to the expected cardinality" do
      # NOTE: If the cardinality test depends on outside data (such as the
      # options present on the parsed command line), the results of
      # #positional_cardinality_ok? are unreliable.
      
      [
        [0, 0, true],
        [0, 1, false],
        [0..1, 0, true],
        [0..1, 1, true],
        [0..1, 2, false],
        [:even?, 0, true],
        [:even?, 1, false],
        [:even?, 2, true],
      ].each do |expected_cardinality, count_given, expected_result|
        parser.expect_positional_cardinality(expected_cardinality)
        expect(parser.positional_cardinality_ok?(count_given)).to be == expected_result
      end
    end
  end
  
  context '#positional_arguments_allowed?' do
    it "responds false when expected cardinality is 0" do
      parser.expect_positional_cardinality(0)
      expect(parser.positional_arguments_allowed?).to be_falsey
    end
    
    it "responds true by default" do
      expect(parser.positional_arguments_allowed?).to be_truthy
    end
    
    it "responds true if the test raises an error" do
      parser.expect_positional_cardinality ->(n) {
        args = parser.argument_destination
        args.pargs.empty? ? n > 0 : n == args.pargs[0].length
      }
      expect(parser.positional_arguments_allowed?).to be_truthy
    end
  end
  
  context '#positional_cardinality' do
    it "returns nil by default" do
      expect(parser.positional_cardinality).to be_nil
    end
    
    it "returns a Proc when the expectation is a Symbol" do
      parser.expect_positional_cardinality(:even?)
      expect(parser.positional_cardinality).to be_kind_of(Proc)
    end
    
    it "otherwise returns the object set as the expectation" do
      test_val = Object.new
      parser.expect_positional_cardinality(test_val)
      expect(parser.positional_cardinality).to equal(test_val)
    end
  end
  
  context '#positional_cardinality_explanation' do
    [
      [nil, nil],
      [0, nil],
      [1, /\brequire(|s|d)\b/i, /\b1\b/, /\bargument\b/i],
      [2, /\brequire(|s|d)\b/i, /\b2\b/, /\barguments\b/i],
      [2..3, /\brequire(|s|d)\b/i, /\b2\.\.3\b/, /inclusive/i, /\barguments\b/i],
      [:even?, /\bargument\s+(count|cardinality)|(count|number|cardinality)\s+of\s+(positional\s+)?arguments\b/i, /\beven\b/],
    ].each do |cardinality_test, *expectations|
      it "returns a response matching expectations when expected positional cardinality is #{cardinality_test.inspect}" do
        parser.expect_positional_cardinality(cardinality_test)
        explanation = parser.positional_cardinality_explanation
        expectations.each {|expectation| expect(expectation).to be === explanation}
      end
    end
    
    it "returns a very generalized response for a Proc" do
      parser.expect_positional_cardinality ->(n) {n % 3 == 1}
      expectations = [/\brule\b/i, /\b(count|number|cardinality)\s+of\s+(positional\s+)?arguments\b/i]
      explanation = parser.positional_cardinality_explanation
      expectations.each {|expectation| expect(expectation).to be === explanation}
    end
    
    it "returns the explanation given explicitly" do
      explict_explanation = "Gollygoops"
      parser.expect_positional_cardinality 1, explict_explanation
      expect(parser.positional_cardinality_explanation).to be == explict_explanation
    end
  end
  
  context '#no_positional_args!' do
    it "parses successfully if no positional args are specified" do
      parser.no_positional_args!
      parser.on('-m MESSAGE')
      expect {parser.parse(%w[-m foo])}.not_to raise_error
    end
    
    it "raises Rake::ToolkitProgram::WrongArgumentCount if any positional args are specified" do
      parser.no_positional_args!
      parser.on('-m MESSAGE')
      expect {parser.parse(%w[-m foo bar])}.to raise_error(Rake::ToolkitProgram::WrongArgumentCount)
    end
  end
  
  context '#map_positional_args' do
    it "transforms positional arguments within context of preceding options" do
      reverse_arg = false
      parser.on('--[no-]reverse') {|val| reverse_arg = val}
      parser.map_positional_args {|arg| 
        reverse_arg ? arg.reverse : arg
      }
      posarg_result = parser.parse(%w[He --reverse saw live --no-reverse bats])
      expect(posarg_result).to eq(%w[He was evil bats])
    end
    
    it "does not (by default) have accsess to the positional arguments via the nil key when accumulating a Hash" do
      parser = described_class.new(args = Hash.new)
      map_positional_args_calls = 0
      parser.map_positional_args do |arg|
        expect(args).to_not have_key(nil)
        map_positional_args_calls += 1
        arg
      end
      parser.parse(%w[foo bar baz])
      expect(map_positional_args_calls).to eq(3)
      expect(args[nil]).to eq(%w[foo bar baz])
    end
    
    it "does not (by default) have access to the positional arguments when accumulating a non-Hash" do
      map_positional_args_calls = 0
      args = parser.argument_destination
      parser.capture_positionals {|targets| args.targets = targets}
      parser.map_positional_args do |arg|
        expect(args.targets).to be_nil
        map_positional_args_calls += 1
        arg
      end
      parser.parse(%w[foo bar baz])
      expect(map_positional_args_calls).to eq(3)
      expect(args.targets).to eq(%w[foo bar baz])
    end
    
    it "has access to the positional argument when 'precapture_dest_array' is specified to #capture_positionals" do
      map_positional_args_calls = 0
      args = parser.argument_destination
      parser.capture_positionals(precapture_dest_array: true) {|targets| args.targets = targets}
      posargs_seen = []
      parser.map_positional_args do |arg|
        expect(args.targets).to eq(posargs_seen)
        posargs_seen << arg
        map_positional_args_calls += 1
        arg
      end
      parser.parse(%w[foo bar baz])
      expect(map_positional_args_calls).to eq(3)
      expect(args.targets).to eq(%w[foo bar baz])
    end
  end
  
  context '#parse!' do
    it "manipulates the 'argv' Array passed to it" do
      input_array = %w[foo bar baz]
      output_array = parser.parse!(input_array)
      
      # This IS intended as an object identity test
      expect(output_array).to be(input_array)
    end
    
    it "captures (in #capture_positionals) its 'argv' parameter by default" do
      input_array = %w[foo bar baz]
      positional_args = nil
      parser.capture_positionals do |args|
        positional_args = args
      end
      output_array = parser.parse!(input_array)
      
      # This IS intended as an object identity test
      expect(output_array).to be(positional_args)
      expect(output_array).to eq(positional_args)
    end
    
    it "does not capture its 'argv' parameter when 'precapture_dest_array' given to #capture_positionals" do
      input_array = %w[foo bar baz]
      positional_args = nil
      parser.capture_positionals(precapture_dest_array: true) do |args|
        expect(args).to be_empty
        positional_args = args
      end
      output_array = parser.parse!(input_array)
      
      # This IS intended as an object identity test
      expect(output_array).to_not be(positional_args)
      expect(output_array).to eq(positional_args)
    end
  end
end
