module Dexter
  module Logging
    COLOR_CODES = {
      red: 31,
      green: 32,
      yellow: 33,
      cyan: 36
    }

    def output
      $dexter_output || $stdout
    end

    def log(message = "")
      output.puts(message) unless $log_level == "error"
    end

    def colorize(message, color)
      if output.tty?
        "\e[#{COLOR_CODES[color]}m#{message}\e[0m"
      else
        message
      end
    end
  end
end
