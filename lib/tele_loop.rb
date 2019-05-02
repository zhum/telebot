class TeleLoop
  def self.log x
    TeleLogger.log "#{adapter}: #{x}"
  end

  def self.adapter
    'NONE'
  end

  def self.sender
    @sender
  end

  def self.sender= s
    @sender = s  
  end

  def self.on_message processor, message
    case message[:text]
    when '/reload'
      log "****** /reload ******"
      TeleConfig.init(ARGV[0] || "teleconfig.yaml")
      Users.init(TeleConfig[:conf]['users'])
      processor.just_enter
      log "****** ok ******"            
    when '/start'
      #Users.set user[:id], :state, 'main'
      log "****** /start ******"
      processor.change_state 'main'
      processor.reload_user
      processor.just_enter
      log "****** ok ******"            
    else
      log "****** START state=#{processor.user[:state]}; msg=#{message[:text]}"
      processor.process_event message[:text]
      log "****** FINISH new_state=#{Users[processor.user[:id]][:state]}; msg=#{message[:text]}"
    end
    Users.save
  end

  def self.start_async(queue)
    stop_async
    @bot_thread = TelebotAsync.new(queue).run! {|msg|
      async_process(msg)
    }    
  end

  def self.stop_async
    @bot_thread.kill if @bot_thread
    @bot_thread = nil
  end

  def self.go(token, queue)
    log "ERROR! Generic TeleLoop.go called!"
    exit 1
  end

  def self.async_process msg
    log "async_process #{adapter}: #{msg[:type]}/#{msg[:group]}/#{msg[:text]}/#{msg[:reenter]}"
    warn "======= #{self.inspect}"
    send_id = "#{adapter}-id".to_sym
    case msg[:type]
    when :grp_message
      Users.each_with_group(msg[:group]){|id,u|
        if u[send_id]
          log "SEND: #{id},#{msg[:group]},#{u}"
          options={chat: u[send_id]}
          options[:reply_markup]=msg[:markup] if msg[:markup]
          @sender.user = u
          @sender.send_message msg[:text], options

          if msg[:reenter].to_i == 1
            reenter_state u
          end        
        # else
        #   log "skip #{id},#{msg[:group]},#{u}"
        end
      }
    when :user_message
      options={chat: msg[:id]}
      options[:reply_markup]=msg[:markup] if msg[:markup]
      #logger.info "options=#{options}"
      @sender.send_message msg[:text], options
    else
      log "Bad message type: #{msg[:type]}"
    end
  end

  def self.reenter_state user
    processor = StateProcessor.new(
            user[:state] || 'main',
            user: user,
            conf: TeleConfig.data,
            sender: @sender,
          )
    # do a trick - just_enter requires @new_state to be set
    processor.change_state processor.state
    processor.just_enter
  end
end

