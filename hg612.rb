#!/usr/bin/ruby

require 'date'
require 'net/telnet'
require 'socket'

class HG612
  def initialize(host='192.168.1.254', username='admin', password='admin', timeout=60, timewait=10)
    @host = host
    @username = username
    @password = password
    @timeout = timeout
    @timewait = timewait
    @hostname = Socket.gethostname

    @stats = [
      {:title => 'rate-down',     :type => 'bytes',          :regex => /Path:.+Downstream rate = ([0-9]+) Kbps/},
      {:title => 'rate-upstream', :type => 'bytes',          :regex => /Path:.+Upstream rate = ([0-9]+) Kbps/},
      {:title => 'snr-down',      :type => 'signal_nose',    :regex => /SNR.+:\s+([0-9]+.[0-9])\s+[0-9]+.[0-9]/},
      {:title => 'snr-up',        :type => 'signal_noise',   :regex => /SNR.+:\s+[0-9]+.[0-9]\s+([0-9]+.[0-9])/},
      {:title => 'attn-down',     :type => 'signal_quality', :regex => /Attn.+:\s+([0-9]+.[0-9])\s+[0-9]+.[0-9]/},
      {:title => 'attn-up',       :type => 'signal_quality', :regex => /Attn.+:\s+[0-9]+.[0-9]\s+([0-9]+.[0-9])/},
      {:title => 'pwr-down',      :type => 'signal_power',   :regex => /Pwr.+:\s+([0-9]+.[0-9])\s+[0-9]+.[0-9]/},
      {:title => 'pwr-up',        :type => 'signal_power',   :regex => /Pwr.+:\s+[0-9]+.[0-9]\s+([0-9]+.[0-9])/},
    ]
  end

  def process_results(results, stats)
    results.each { |r|
      stats.each { |s|
        r =~ s[:regex] ? s[:value] = $1 : false
      }
    }
    stats
  end

  def get_stats
      xdsl_stats = {:cmd => "xdslcmd info --stats", :match => /xdslcmd: ADSL driver and PHY status/}
      xdsl_pbparams = {:cmd => "xdslcmd info --pbParams", :match => /xdslcmd: ADSL driver and PHY status/}

      results = connect_and_run([xdsl_stats, xdsl_pbparams])
      processed_results = process_results(results, @stats)

      output = ""
      processed_results.each { |p|
        output << "PUTVAL #{@hostname}/xdsl/#{p[:type]}-#{p[:title]} interval=#{@timewait} N:#{p[:value]}\n"
      }
    output
  end

  def output_stats
     puts get_stats
     $stdout.flush
  end

  def connect_and_run(cmds)
    begin
      results = []
      modem = Net::Telnet::new("Host" => @host, "Timeout" => @timeout,"Prompt" => /^ATP>$/)
      modem.login(@username, @password) { |c|
        #puts c
      }
      modem.cmd("String" => "sh", "Match" => /Enter 'help' for a list of built-in commands./)

      cmds.each { |c|
        modem.cmd("String" => c[:cmd], "Match" => c[:match]) { |r| results << r }
      }
      modem.close
      results

    rescue Exception => e
      puts e
      puts e.backtrace
    ensure
      modem.close if !modem.nil? && !modem.closed?
    end
  end

  def run_forever
    begin
      while true do
        output_stats
        sleep(@timewait)
      end
    rescue Exception => e
      puts e
      puts e.backtrace
    end
  end
end

plugin = HG612.new()
plugin.run_forever()

