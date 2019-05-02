class SubsriptionsProcessor<GenericProcessor
  class << self

    def can_process_event processor, event
      s = processor.state_conf('subscriptions')
      #e = processor.event_conf('subscriptions')
      log "sub can_process_event '#{s}'!=''"
      s.to_s != ''
    end

    def can_enter processor, event
      s = processor.state_conf('subscriptions')
      #e = processor.event_conf('subscriptions')
      log "sub can_enter '#{s}'!=''"
      s.to_s != ''
    end

    def on_enter processor, old, event
      s = processor.state_conf('subscriptions')
      log "SUB on_enter (#{s})"
      groups = processor.get_var('groups')
      case s
      when 'all' # list all available
        processor.send_text groups.values.join('; ')
        processor.change_state(processor.get_var('next_state')||'main')
      when 'my' # list only what I am subscribed
        processor.send_text processor.get_var('user_groups').map{|x| groups[x]}.join('; ')
        processor.change_state(processor.get_var('next_state')||'main')
      when 'new' # subscribe to new
        menu = (groups.keys - processor.get_var('user_groups')
               ).map{|x| [x,groups[x]]}+[['cancel',processor.get_var('cancel')||'Отказ']]
        log "subscribe menu=#{menu.inspect}"
        if menu.size==1
          processor.send_text 'Вы уже на всё подписаны!'
          processor.change_state(processor.get_var('cancel_state')||'main')
        else
          processor.send_text processor.get_var('prompt') || 'Выбирайте!'
          processor.send_menu menu
        end
      when 'del' # unsubscribe me
        menu = processor.get_var('user_groups').map{|x| [x,groups[x]]}+[['cancel',processor.get_var('cancel')||'Отказ']]
        log "unsubscribe menu=#{menu.inspect}"
        if menu.size==1
          processor.send_text 'Вы ещё ни на что не подписаны.'
          processor.change_state(processor.get_var('cancel_state')||'main')
        else
          processor.send_menu menu
        end
      else
        processor.send_text 'Ой, у меня тут кто-то пролил чай на конфигурацию, извините...'
        processor.change_state 'main'
      end
    end

    def on_event processor, event
      s = processor.state_conf('subscriptions')
      log "SUB on_event (#{s}), event=#{event}"
      case s
      when 'new' # subscribe to new
        ok = false
        processor.get_var('groups').each_pair{|group,text|
          if group == event
            processor.subscribe group
            ok = true
            break
          end
        }
        if ok
          processor.send_text(processor.get_var('ok_msg') ||'Подписал!')
          processor.change_state(processor.get_var('ok_state')||'main')
        else
          processor.send_text(processor.get_var('cancel_msg') ||'Ок!')
          processor.change_state(processor.get_var('cancel_state')||'main')
        end
      when 'del' # unsubscribe me
        ok = false
        processor.get_var('user_groups').each{|group|
          warn "check: #{group}/#{event}"
          if group == event
            processor.unsubscribe group
            ok = true
            break
          end
        }
        if ok
          processor.send_text(processor.get_var('ok_msg') ||'Отписал!')
          processor.change_state(processor.get_var('ok_state')||'main')
        else
          processor.send_text(processor.get_var('cancel_msg') ||'Ок!')
          processor.change_state(processor.get_var('cancel_state')||'main')
        end
      else
        # No transition state was specified. BAD!!!
        processor.send_text 'Подписки - это же так здорово, правда?.. Ладно, вернёмся к разговору.'
        processor.change_state 'main'
        return
      end
      ok = processor.state_conf('ok')
      processor.send_text ok if ok
    end
  end#self
end
StateProcessor.register_processor SubsriptionsProcessor
