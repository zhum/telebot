#
class GenericProcessor
  class << self

    def can_process_event processor, event
      false
    end

    def can_enter processor, event
      false
    end

    def on_enter processor, old, event
    end

    def on_event processor, event
    end

    def log x
      TeleLogger.log x
    end
  end
end

class TeleAction
  class << self

    def log x
      TeleLogger.log x
    end

    def flush type=:all
      log "flush #{type}"
      if type==:all || type==:text
        @txt=[]
      end
      if type==:all || type==:photo
        @photo=[]
      end
      if type==:all || type==:menu
        @menu=[]
      end
    end

    def send_text txt
      @txt||=[]
      @txt<<txt.to_s unless txt.to_s == ''
      log "send_text: #{@txt.inspect}"
    end
    def send_photo photo
      @photo||=[]
      @photo<<photo
    end
    def send_menu menu
      @menu||=[]
      @menu<<menu if menu.instance_of?(Array) && menu.size>0
      log "send_menu: #{@menu.inspect} (#{menu})"
    end

    def text
      @txt || []
    end

    def photo
      @photo || []
    end

    def menu
      @menu || []
    end
  end
end

class StateProcessor
  #
  # @state - current state
  # @new_state - new state to change
  #

  #  init {bot,}
  #  process_event ev
  #    -> on_event
  #       ....
  #       [change_state st]
  #    -> on_enter st
  #    ^   ....
  #    |   [change_state st]
  #    +------+
  #  ok!   

  MAX_KBD_SIZE = 4
  MAX_COUNT = 5
  DEF_TEXT = 'Даже не знаю, что сказать...'
  DEF_MENU_TEXT = 'Выбирайте!'

  PROTECTED_VARS = ['clear_vars','username','authorized','groups','user_groups',:menu, :events]

  attr_reader :state, :opts, :sender, :conf, :user

  def initialize state, opts={}
    @state = state
    @max_count = (opts.delete(:max_count) || MAX_COUNT).to_i
    @conf = opts.delete :conf
    @user = opts.delete :user
    unless @user
      raise 'No user specified for StateProcessor'
    end
    @sender = opts.delete :sender
    unless @sender
      raise 'No sender specified for StateProcessor'
    end
    #    @bot  = opts.delete :bot
    @opts = opts
    # unless @bot
    #   raise 'No bot specified for SimpleStateProcessor'
    # end
    #    state = @bot.get_state || 'main'

    set_var 'username', @user[:name]
    set_var 'authorized', @user.fetch(:auth,0)
    set_var 'groups', TeleConfig.data[:groups]
    set_var 'user_groups', @user.fetch(:groups,[])
  end

  def reload_user
    @user = Users[@user[:id]]
    set_var 'username', @user[:name]
    set_var 'authorized', @user.fetch(:auth,0)
    set_var 'groups', TeleConfig.data[:groups]
    set_var 'user_groups', @user.fetch(:groups,[])
  end

  def just_enter
    unless TeleConfig[:states][@new_state]
      log "!!!!!!!!!!!!! BAD STATE: #{@new_state}"
      @new_state = 'main'
    end
    @old_state = @new_state.clone
    @state = @new_state.clone
    log "[on_enter]: !==> new_state=#{@new_state}"
    on_enter @old_state, ''
    reload_user
    log "!!! new_state=#{@new_state.inspect}"
    #show_pending(TeleConfig[:states][@new_state], true)
    log "[on_enter]: <!== #{@new_state || '---'}"
  end

  def process_event event
    @new_state=nil
    unless TeleConfig[:states][@state]
      log "!!!!!!!!!!!!! BAD STATE: #{@state}"
      @state = 'main'
    end
    log "~~~~~~~~~~~~~~ >(on_event) start  ev=#{event}, state=#{@state}"
    on_event event
    reload_user
    log "<---------------(on_event) finish ev=#{event}, new_state=#{@new_state} user=#{@user.inspect}"

    # unless @new_state
    #   # show menu again if needed
    #   show_pending TeleConfig[:states][@state]
    # end
    show_pending TeleConfig[:states][@state], false

    @count = 0
    while @new_state && @count < @max_count
      @old_state = @state
      @state = @new_state.dup
      @new_state = nil
      @count += 1
      log "[on_enter]: ===> new_state=#{@new_state} ev=#{event} from #{@old_state}"
      on_enter @old_state, event
      reload_user
      log "!!! new_state=#{@new_state.inspect}"
      #!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      show_pending(TeleConfig[:states][@new_state], false) if @new_state
      log "[on_enter]: <=== ev=#{event} to #{@new_state || '---'} (#{@count})"
    end
  end

  def log x
    TeleLogger.log x
  end

  def log_vars
    str = Users[@user[:id]][:vars].map{|k,v| "    #{k} -> #{v}"}.join("\n")
    log "VARS:\n#{str}"
  end

  def change_state new_state
    unless TeleConfig[:states][new_state]
      log "!!!!!!!!!!!!! BAD STATE: #{new_state} -> CHANGE TO 'main'"
      new_state = 'main'
    end
    Users.set @user[:id], :state, new_state
    log "state: #{state} -> #{new_state}"
    @new_state = new_state
  end

  def set_var name, value
    log "set_var #{name}=#{value};"
    # value.to_s.gsub(/%([^% ]+)%/) { |var|
    #   log "var #{var} -> #{@vars.fetch($1,"%#{var}%")}"
    #   data.fetch($1,"%#{var}%")
    # }
    #@vars[name] = value
    @user[:vars] ||={}
    @user[:vars][name] = value
    Users.set_user_var @user[:id], name, value
  end

  def get_var name, default=nil
    v = Users.get_user_var @user[:id], name
    !v.nil? ? v :
    !state_conf(name).nil? ? state_conf(name) :
    !event_conf(name).nil? ? event_conf(name) : default
  end

  def get_exp_var name, default=nil
    v = get_var name
    v.to_s.gsub(/%[^% ]+%/){|var|
      get_var(var[1..-2]) || var
    }
  end

  def state_conf x
    @state_conf ? @state_conf[x] : nil
  end

  def old_state_conf x
    @old_state_conf ? @old_state_conf[x] : nil
  end

  def event_conf x
    @event_conf ? @event_conf[x] : nil
  end

  def old_event_conf x
    @old_event_conf ? @old_event_conf[x] : nil
  end

  def send_text txt, opts=nil
    TeleAction.send_text txt
  end

  def send_photo photo, type='image/jpeg'
    TeleAction.send_photo [photo,type]
  end

  def send_menu menu, opts=nil
    TeleAction.send_menu menu
  end

  def self.register_processor p
    warn "Register #{p}\n"
    @@registered ||= []
    @@registered << p    
  end

  def show_pending entry, show_defaults=true
    log "  show_pending: :msg=#{entry['msg']}; :menu=#{entry[:menu]}, def=#{show_defaults.inspect}"
    log "  SHOW_PENDING: text=#{TeleAction.text.inspect}; menu=#{TeleAction.menu.inspect}; photo=#{TeleAction.photo}"
    action_done = false

    # send photo if needed
    if TeleAction.photo.size>0
      TeleAction.photo.each{|p|
        sender.send_photo p[0], p[1]
      }
      action_done = true
    end

    # is there any menu to send?
    menu = TeleAction.menu.last
    if menu.nil? && show_defaults && entry[:menu]
      menu = []
      entry[:menu].each_pair{|e,txt|
        menu<<[e,txt]
      }
    end

    if menu
      #log "MENU in action!"
      text = DEF_MENU_TEXT

      # take last message
      if TeleAction.text.size==0
        if show_defaults && entry['msg']
          text = entry['msg']
        end
      else
        text = TeleAction.text.pop
      end

      #log "text -> #{text}"
      TeleAction.text.each{|t|
        sender.send_message t
      }

      log "send_message -> #{text}/#{menu}"
      sender.send_message text, menu: mk_kbd(menu)
      action_done = true
    else
      # no menu, just text
      #log "No menu, just text (#{TeleAction.text.inspect})"
      if TeleAction.text.size==0 && !action_done && show_defaults
        TeleAction.send_text(entry['msg'] || DEF_TEXT)
        action_done = true
      end
      if TeleAction.text.size>0
        TeleAction.text.each{|t|
          #log "SEND! #{t}"
          sender.send_message t
        }
        action_done = true
      end
    end
    TeleAction.flush :all
    action_done
  end

  def on_enter old_state, event
    log "on_enter #{state} from #{old_state} by event #{event}"
    @old_state = old_state
    @new_state = nil
    @state_conf = TeleConfig[:states][state]
    @old_state_conf = TeleConfig[:states][old_state]
    @event_conf = (state_conf(:events)||{})[event]
    @old_event_conf = (old_state_conf(:events)||{})[event]


    if @state_conf['clear_vars'].to_s == '1'
      Users[@user[:id]][:vars].values.select{|v| not PROTECTED_VARS.include?(v)}.each{|v| Users.del_user_vars @user[:id], v}
    else
      @state_conf.each{|k,v|
        #log "SET VAR: #{k} = #{v}"
        set_var(k,v) unless PROTECTED_VARS.include?(k)
      }
    end
    @text=@menu=@photo=nil
    @@registered.each do |r|
      next unless r.can_enter self, event
      r.on_enter self, old_state, event
    end

    if @new_state.nil? && st=state_conf('state')
      # redirect
      change_state st
      # log "CH state 2 -> #{st}"
    end

    show_pending @state_conf

  end

  def on_event event
    @state_conf = TeleConfig[:states][@state]
    events = state_conf(:events)||{}
    @text=@menu=@photo=nil

    ev = if events.has_key? event
      event
    elsif events.has_key? '_other'
      '_other'
    else
      nil
    end
    @event_conf = events

    log "on_event: corrected event=#{ev} event_conf=#{@event_conf.inspect} state_conf=#{@state_conf.inspect}"

    # get state from config
    new_state = @new_state = nil
    set_var 'last_event', ev
    
    # call all processors
    @@registered.each do |r|
      next unless r.can_process_event self, event
      r.on_event self, event
    end

    unless @new_state
      if ev
        log "No processor available. Check events list (#{event_conf(ev)})"
        new_state = event_conf(ev)['state'] || 'main'


        if @event_conf[ev]['clear_vars'].to_s == '1'
          Users[@user[:id]][:vars].values.select{|v| not PROTECTED_VARS.include?(v)}.each{|v| Users.del_user_vars @user[:id], v}
        else
          @event_conf[ev].each{|k,v|
            log "SET VAR: #{k} = #{v}"
            set_var(k,v) unless PROTECTED_VARS.include?(k)
          }
        end
        change_state new_state
      else
        send_text 'Простите, отвлёкся, не понял, что Вы сказали...'
        log "Stop..."
        on_enter(@state,ev)
        #return
      end
    end

    show_pending @state_conf, false
    log "on_event: new_state=#{@new_state}"
  end

  def set_auth val=1
    Users.set @user[:id], :auth, val
  end

  def subscribe grp
    Users.add_user_group @user[:id], grp
    Users.save
  end

  def unsubscribe grp
    Users.del_user_group @user[:id], grp
    Users.save
  end
  
  #  helper
  def mk_kbd keys
    #formatted_keys=
    if keys.size > MAX_KBD_SIZE
      count=-1
      a=[]
      keys.chunk{|n| count+=1; count / MAX_KBD_SIZE}.each{|_,v| a<< v}
      a
    else
      [keys]
    end
  end
end

Dir[File.expand_path(
  File.join("lib", "state_processors", "*-processor.rb")
  )].each{|f| require f}

