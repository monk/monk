require "open3"
require "socket"

module Commands
  def sh(cmd)
    out, err = nil

    Open3.popen3(cmd) do |_in, _out, _err|
      yield _in if block_given?
      out = _out.read
      err = _err.read
    end

    [out, err]
  end

  # Runs a command in the background, silencing all output.
  # For debugging purposes, set the environment variable VERBOSE.
  def sh_bg(cmd)
    if ENV["VERBOSE"]
      streams_to_silence = []
    else
      streams_to_silence = [$stdout, $stderr]
      cmd = "#{cmd} 2>&1>/dev/null"
    end

    silence_stream(*streams_to_silence) do
      (pid = fork) ? Process.detach(pid) : exec(cmd)
    end
  end

  def silence_stream(*streams) #:yeild:
    on_hold = streams.collect{ |stream| stream.dup }
    streams.each do |stream|
      stream.reopen(RUBY_PLATFORM =~ /mswin/ ? 'NUL:' : '/dev/null')
      stream.sync = true
    end
    yield
  ensure
    streams.each_with_index do |stream, i|
      stream.reopen(on_hold[i])
    end
  end
end
