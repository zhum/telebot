require "yaml/store"

class TeleConfig
  class << self
    @data = nil

    def init(b)
      @base=b
      reload
    end

    def logger= l
      @logger=l
    end

    def reload
      data=File.read(@base)
      @data=YAML.load(data)
      #@@logger.info "TeleConfig: #{@@data.to_json}" if @@logger
    end

    def data
      reload if @data.nil?
      @data
    end

    def [](x)
      reload if @data.nil?
      @data[x]
    end
  end

  def initialize(user)
    
    reload if @data.nil?

    #@logger.info "State: #{@machine.state}, Events: #{@machine.triggerable_events}"
  end

end
