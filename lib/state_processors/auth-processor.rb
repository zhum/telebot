class AuthorizeProcessor<GenericProcessor
  class << self

    DEF_TIMEOUT = 5

    def can_process_event processor, event
      log "auth: can_process_event #{processor.state}/#{event}/authorized=#{processor.get_var('authorized').inspect}/auth_check=#{processor.event_conf('auth_check')}"
      processor.state_conf('auth_check') && processor.get_var('authorized').to_i==0
    end

    def can_enter processor, event
      log "auth: can_enter state=#{processor.state}/ev=#{event}/authorized=#{processor.get_var('authorized')}"
      # redirect if unauthorized options is present or do check if auth_check is present
      processor.get_var('authorized').to_i==0 && (processor.state_conf('auth_check') || processor.state_conf('unauthorized'))
    end

    def on_enter processor, old, event
      log "--- authorized=#{processor.state_conf('unauthorized')} auth_check=#{processor.state_conf('auth_check')}"
      if processor.state_conf('unauthorized')
        processor.change_state processor.state_conf('unauthorized')
      elsif processor.state_conf('auth_check')
        TeleAction.send_text(processor.state_conf('auth_check') || 'Привет, гость!')
      end      
    end

    def on_event processor, event
      log "AUTH on_event! (state=#{processor.state}, event='#{event}')"
      if answer = processor.get_var('auth_answer')
        log "auth_answer = '#{answer}==#{event}'"
        if event == answer
          processor.set_auth 1
          TeleAction.send_text(processor.state_conf('auth_msg') || 'Добро пожаловать в наш клуб!')
          processor.change_state(processor.state_conf('ok_state') || 'main')
          return
        end
      elsif command = processor.state_conf('auth_cmd')
        ok = ''
        begin
          timeout = processor.state_conf('timeout' || DEF_TIMEOUT).to_i
          Timeout.timeout(timeout) do
            log "Try to exec #{command}"
            ok = `#{command} "#{event}" "#{processor.username}"`.chomp
          end
        rescue
        end
        if ok=='ok'
          processor.set_auth 1
          TeleAction.send_text processor.state_conf('auth_msg' || 'Добро пожаловать в наш клуб!')
          processor.change_state processor.state_conf('ok_state' || 'main')
          return
        end
      end
      TeleAction.send_text processor.state_conf('auth_fail' || 'Да Вы, кажется шпиён... Идите-ка отсюда по-добру по-здорову.')
      processor.change_state processor.state_conf('fail_state' || 'main')        
    end
  end#self
end
StateProcessor.register_processor AuthorizeProcessor

