This is bot framework, now it supports telegram, facebook messenger
and test console interface. New messengers can be added by 'adapters'. New functions can be added by 'processors'.

How it works: every time, user is connected, bot assigns a 'state' to him. First state is always 'main'. Every state can do something on
enter and something on event. Event = user input. In base implementation state can show menu, each menu item is associated with
event.

User can be authenticated or not, this allows to pass him by different ways. State can do action and immediately pass control to next state (be careful for infinite loops!).

How do processors work. Processor class should implement `can_enter`
and `can_process_event` class methods. They check state description
and event, and decide, can this processor do some action on state
enter and event accordingly. Processor should be inherited from GenericProcessor class.

By default configuration is stored in `teleconfig.yaml` file, but you can pass another name as first argument to bot.


# configuration YAML-file description:

## :conf section

### Proxy

- `proxy: http://....`  proxy address
- `proxy_user: ....`  proxy user
- `proxy_pass: ....`  proxy password
- `proxy_http: yes/no`  'yes' = http proxy, 'no' = socks5 proxy

### Service

- `service_port: 8003`  port for notifications
- `service_token: 'secret'` secret token for notifications


- `telegram_token: 'XXXXXX:yyyyyyy'`  telegram bot token

- `text_socket: /tmp/tele_text_sock`   socket for console bot

- `fb_token: qweqweq`     facebook token
- `fb_verify_token: 123456`  facebook verify token
- `fb_app_secret: qweasdzxc`  facebook app secret
- `fb_port: 5550`  listen port for facebook bot
- `server_base: 'https://qqq.ngrok.io'`  base url for images uploads


- `users: ./bot_users.yaml`   path to users yaml database

### :states (states table)

**IMPORTANT**: `:unauthorized`, `:state`, `:menu` and `:events` keys started with ':', others (usually) not.

    state_name:
      msg: Hello!              # message on state enter

      :unauthorized: state     # immediately go to state, if user
                               # is not authorized
      :state:  state           # go to state after all. Can be 
                               # cancelled by :menu:

      :menu:                   # show menu on state enter
        e1: "Hi !"             # format: event_name: menu text
        ...

      :events:                 # events list
        state_name:            # event name or "_other"
                               # (event name is stored in "last_event" variable)
                               #
          state: e2            # go to state e2

          something: value     # set variable 'something' to 'value'
  
          exec: cmd arg        # execute command
          ok_state: e2         # go to e2 if command exit code = 0
          fail_state: e3       # go to e3 if command exit code != 0


### Special options in states (not menu)

#### Authentication

    auth_check: prompt      # Secret question
    auth_answer: "..."      # Answer on secret question
    auth_cmd: "..."         # Answer check command (get answer and 
                            # username). Check is passed if command
                            # prints 'ok'
    auth_fail: "..."        # Message on authentication fail
    fail_state: state       # New state on authentication fail
    auth_msg: "..."         # Message on authentication ok
    ok_state: state         # New state on authentication ok
    timeout: N              # Command execution timeout

**TODO**: implement auth_check_cmd, which generates secret question
**TODO**: pass variables to all commands

#### Groups subscriptions

subscriptions: type  # Subscriptions actions:
                     # all  = list all available
                     # my   = list subscribed on
                     # new  = subscribe to new
                     # del  = unsubscribe one
next_state: st       # after 'all' or 'my' go to state st
cancel: "..."        # (un)subscribe cancellation text
ok_state: st         # go to state st after (un)subscribe
ok_msg: "..."        # show message after (un)subscribe
cancel_state: st     # go to state st if (un)subscribe cancelled
cancel_msg: "..."    # show message if (un)subscribe cancelled


#### Commands execution

exec: cmd           # execute cmd
ok_state: st        # go to state if command exit code = 0
fail_state: st      # go to state if command exit code != 0
next_state: st      # go to state anyway
is_jpeg: anything   # command prints path to image in jpeg format
is_png: anything    # command prints path to image in png format
is_gif: anything    # command prints path to image in gif format
is_menu: anything   # command prints menu (menu options are printed
                    # via ';', option format - 'str=state')
lines:  @N,@M       # @ = '+'/'' or '-', N,M - integers. Cut program
                    # output lines. Use only M lines from N. If M<0
                    # then N lines from M-th from last.
                    # Count starts with 0 !!!
timeout: N          # Command execution timeout


# Processors


````
class BlaBlaBlaProcessor < GenericProcessor
  class << self

    # Called on state enter by event, checks if this processor is
    # appliable. If returns true, then `on_enter` is called.
    #
    def can_enter processor, event
      false
    end

    # Called on event
    # If returns true, then `on_event` is called
    def can_process_event processor, event
      false
    end

    # Called on transition from `old` state by event
    def on_enter processor, old, event
      processor.sender.send_message processor.get_var('hello', 'Hi, '+processor.username)
    end

    # Called on event
    def on_event processor, event
      processor.sender.send_message "Hi, I am "+processor.get_var('my_name', 'bot Vasya')
      processor.change_state processor.get_var('new_state','main')
    end
  end #self
end

# register this processor
StateProcessor.register_processor BlaBlaBlaProcessor
````


## Processor class

### log str

Log string str

### change_state new_state

Go to new state

### set_var name, value

Set variable

### get_var name, default=nil

Get variable

### set_auth [1/0]

Set/unset user authenticated state

### state

Get current state

### opts

Get options, passed to constructor

### sender

Sender class object

### conf


### Authomatic variables

username = user name
authorized = 1 if authorized, 0 if not
groups = all groups
user_groups = all groups, user is subscribed to


## Sender class

### initialize bot, user

constructor

### send_message msg, opts=nil, chat=nil

send message

### send_photo chat, photo

send photo
