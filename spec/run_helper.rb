require 'rake/toolkit_program'
require 'tempfile'

def run_tool(*args, expect_exit_code: 0, expect_error: nil, &blk)
  expected_exit_code = expect_exit_code
  rd, wr = IO.pipe
  
  err_file = Tempfile.new(%w[rtkp-error .txt])
  err_file.unlink
  if (child = fork)
    wr.close
    output = rd.read(nil)
    rd.close
    status = Process.wait2(child)[1]
  else
    rd.close
    old_stdout, $stdout = $stdout, wr
    child_exit_code = 0
    begin
      yield if block_given?
      Rake::ToolkitProgram.run(args.flatten)
    rescue StandardError => e
      if expect_error === e
        expect_error = nil
      else
        if e.respond_to?(:exit_code)
          child_exit_code = e.exit_code
        end
        child_exit_code = [1, child_exit_code].max
        $stdout = old_stdout
        err_file.puts "#{e.class}: #{e}"
        e.backtrace.each do |frame|
          err_file.puts frame
        end
      end
    ensure
      if expect_error
        err_file.puts "Expected error #{expect_error} not detected"
        child_exit_code = 1
      end
      err_file.close
      wr.close
      exit!(child_exit_code)
    end
  end
  
  unless expect_exit_code == 1
    expect(status.exitstatus).to_not eq(1), lambda {err_file.seek(0); err_file.read}
  end
  expect(status.exitstatus).to eq(expected_exit_code)
  
  return output
end

##
# For code inside the block of #run_tool, only invoke a REPL (like pry) inside
# the block of this function -- otherwise the REPL output will be captured
# by the test harness, you won't see it, and the output of the test will get
# messed up.
#
def allow_prying
  old_stdout, $stdout = $stdout, STDOUT
  begin
    yield
  ensure
    $stdout = old_stdout
  end
end

##
# The last item in +comp_words+ is the item being completed; in some cases,
# this will be an empty string.
#
def get_completions(added_commands, comp_words, flags: [])
  comp_words = comp_words.collect(&:shellescape)
  Tempfile.create(%w[comptest- .sh]) do |shfile|
    shfile.puts %Q{COMP_CWORD=#{comp_words.length}}
    shfile.puts %Q{COMP_WORDS=(test-prog #{comp_words.join(' ')})}
    
    shfile.puts %Q[test-gen-completion() {]
    Rake::ToolkitProgram.each_completion_script_line(
      static_options: (['help'] + added_commands).join(' '),
      static_flags: flags.join("\n"),
    ) do |line|
      shfile.puts line
    end
    shfile.puts %Q[}]
    shfile.puts %Q[test-gen-completion]
    
    shfile.puts %Q{for w in "${COMPREPLY[@]}"; do echo $w; done}
    shfile.flush
    `bash -e #{shfile.path}`.split("\n")
  end
end

def gemver(s)
  Gem::Version.new(s)
end
