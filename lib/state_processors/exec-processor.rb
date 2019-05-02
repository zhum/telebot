class ExecStateProcessor<GenericProcessor
  class << self

    DEF_TIMEOUT = 5

    def can_process_event processor, event
      processor.log_vars
      x=processor.event_conf('exec').to_s
      log "exec can_process_event #{event} exec='#{x}' is_menu=#{processor.get_var('_is_menu_in_progress')}"
      x != '' || processor.get_var('_is_menu_in_progress')
    end

    def can_enter processor, event
      x=processor.state_conf('exec').to_s
      log "exec can_enter #{processor.state} by event #{event} exec='#{x}' is_menu=#{processor.get_var('_is_menu_in_progress')}"
      x != '' || processor.get_var('_is_menu_in_progress')
    end

    def on_event processor, event
      on_any processor, event, true
    end

    def on_enter processor, old, event
      on_any processor, event, false
    end

    def on_any processor, event, is_event
      if text = processor.get_var('_is_menu_in_progress')
        log "MENU in progress!"
        processor.set_var '_is_menu_in_progress', false
        process_menu processor, event, Hash[text.split(';').map { |e| a=e.split('='); [a[1]||'main',a[0]||'main'] }]
        return
      end
      text,status = do_exec processor
      new_state = if status==0
        processor.get_var('ok_state') || processor.get_var('next_state')
      else
        processor.get_var('fail_state') || processor.get_var('next_state')
      end
      new_state ||= 'main'
      answer = text.chomp

      if ['is_jpeg', 'is_png', 'is_gif'].any? {|x| processor.state_conf(x)}
        begin
          type = processor.state_conf('is_jpeg') ? 'image/jpeg' :
                 processor.state_conf('is_png') ? 'image/png' : 'image/gif'
          processor.send_photo text.chomp, type
        rescue => e
          log "ExecResponder.process: #{e.message}"
          processor.send_text 'Упс! Что-то пошло не так...'
        end
      elsif processor.state_conf('is_menu')
        menu = answer.chomp.split(';').map { |x| [x.split('=')[1],x.split('=')[0]] }
        processor.send_menu menu
        processor.set_var '_is_menu_in_progress', answer
        new_state = nil
      else
        processor.send_text text
      end
      processor.change_state new_state if new_state
      log "ANSWER='#{answer.inspect}' code=#{status}; new_state=#{new_state}"
    end

    private
    def do_exec processor
      answer=''
      ok=0
      command=processor.get_exp_var('exec')
      log "do_exec: '#{command}'"
      begin
        timeout=processor.state_conf('timeout' || DEF_TIMEOUT).to_i
        Timeout.timeout(timeout) do
          log "Try to exec #{command}"
          # processor.log_vars
          # command.gsub!(/%[^%]+%/){|var|
          #   log "replace: #{var} (#{var[1..-2]}) -> #{processor.get_var(var[1..-2])}"
          #   processor.get_var(var[1..-2]) || var
          # }
          answer=`#{command}`
          log "Exec done. code=#{$?.to_i}, answer=#{answer}"
        end
        lines=processor.state_conf('lines' || '')
        if /([+-]?\d+)([+-]\d+)/.match lines
          n,m=$1.to_i,$2.to_i
          text=answer.split "\n"
          m=text.length-m if m<0
          answer=text[n,m].join("\n")
        end
        ok=$?.to_i
      rescue => e
        ok=404
        log "Cannot exec: '#{command}' (#{e.message})"
        answer="Что-то не получается, извините..."
      end
      processor.set_var 'exec', nil
      log "Exec exit code: #{ok}"
      return answer, ok
    end

    # menu = {event=>state, event=>state,...}
    def process_menu processor, event, menu
      log "menu=#{menu}; event=#{event}"
      processor.change_state menu[event] ? event : 'main'
    end
  end#self
end

StateProcessor.register_processor ExecStateProcessor
