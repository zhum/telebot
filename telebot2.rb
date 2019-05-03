require 'telegram/bot'
require "thread"
require "logger"
require 'socksify'
require 'socksify/http'

require "./tele_config"
USE_TELEGRAM = true
USE_TEXT = true
USE_FB = true

LOGFILE = 'tele.log'
LOG_SIZE = 10_000_000
LOG_COUNT = 30

END_FILE='./stop.txt'

class TeleLogger
  class << self
    def set l
      @@logger = l
    end

    def log x
      if @@logger
        @@logger.info x
      else
        warn x
      end
    end
  end
end
###############################################
#
# INIT
# 
###############################################
TeleConfig.init(ARGV[0] || "teleconfig.yaml")

# logfile = File.new("app.log", 'a+')
# logfile.sync = true
logger=Logger.new(LOGFILE, LOG_COUNT, LOG_SIZE)

TeleLogger.set logger

Dir["./lib/*.rb"].each {|file| require file }

Users.init(TeleConfig[:conf]['users'])

Dir["./lib/adapters/*.rb"].each {|file| require file }

def control_loop q
  port = TeleConfig.data[:conf].fetch('service_port',8001)
  warn "Control PORT=#{port}"
  LomoBot.run! port: port do
    LomoBot.class_variable_set(:@@queues,q)
  end
end

def end_check_loop file, threads
  loop do
    sleep 3
    if File.exists? file
      File.delete file
      threads.each{|t| t.exit }
      break
    end
  end
end

queues = []
threads = []
if USE_TELEGRAM
  telegram_queue=Queue.new
  queues << telegram_queue
  telegram_thread=Thread.new { TelegramLoop.go TeleConfig[:conf]['telegram_token'], telegram_queue}
  threads << telegram_thread
end
if USE_TEXT
  text_queue = Queue.new
  queues << text_queue
  text_thread = Thread.new { TextLoop.go TeleConfig[:conf]['text_socket'], text_queue}
  threads << text_thread
end
if USE_FB
  fb_queue = Queue.new
  queues << fb_queue
  fb_thread = Thread.new {FacebookLoop.go TeleConfig[:conf]['fb_token'], fb_queue}
  threads << fb_thread
end

control_thread=Thread.new { control_loop queues}
threads << control_thread
end_check_thread=Thread.new {end_check_loop END_FILE, threads}

threads.each{|t| t.join()}
control_thread.join()
end_check_thread.join()
warn "Finished!"
