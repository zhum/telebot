This is chat bot.

### Main features:
- many messengers can be supported by 'adapters',
- included telegram and facebook messenger support,
- all messengers adapters can work simultaneously,
- ability to notify subscribed users on external events,
- no programming needed to start!
- new features can be added by implementing new processor modules,
- opensource and free!

### How it works
Every time, user is connected, bot assigns a 'state' to him. First state is always 'main'. Old state is remembered. On state enter or new event (incoming message) bot can send a message to user, show a menu to him, and change current state. All states are described in configuration file, which can be reloaded on the fly.

User can be authenticated or not. This allows to route him by different ways. State can do action and immediately pass control to next state (be careful for infinite loops!).

### How do processors work
Processor class should implement `can_enter`
and `can_process_event` class methods. They check state description
and event, and decide, can this processor do some action on state
enter and event accordingly. Processor should be inherited from GenericProcessor class. See 'Processors' section below.

### How do adapters work
To implement new adapter, two classes should be implemented: Sender and Adapter. Sender class can only send messages to user, Adapter encapsulates messenger logic. See 'Adapters' section below.

### How do notifications work
Bot is listening on special port (see `service_port` below) and if somebody send POST request on url `http:host/event/GROUP`, then all users, subscribed to `GROUP` will get notification with text, passed in request body. Post request should use secret token (see `service_token` below. If parameter `reenter=1` is passed, the after notification message bot will try to reenter current user state (e.g. show menu again).
See set_send_sample.sh for reference.

By default configuration is stored in `teleconfig.yaml` file, but you can pass another name as first argument to bot.

Now three adapters are included:
- console,
- telegram (includes proxy support),
- facebook messenger. 

Included processors:
- authentication,
- external program execution (which can return text, path to image or menu description),
- groups subscriptions.

### Users
User information is stored in yaml-database. User is just a hash with 'ADAPTER-id' field for each adapter. Each user has unique id. We recommend to store one 'user' for each adapter for each real user, do not merge them into one database 'user'. You can change this by re-implementing Users class in file users.rb.
See 'Users class' below.

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


      my_var: 1234             # set variable, associated with user
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

          clear_vars: 1        # delete all variables!


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

All processors should be inherited from GenericProcessor class. All methods are class methods.

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

All 'processor' arguments are exemplars of StateProcessor class. This class can interact with real adapter.

### reload_user

  update user data

### log_vars

  dump user variables to lo file

### change_state new_state

  after processor method finish tell bot to change user state

### set_var name, value

  set user variable

### get_var name, default=nil

  get user variable (`default` - if variable not found). Special variables are autogenerated: every field in state description (except 'clear_vars', :menu, :events), username, authorized, groups, user_groups, last_event.

### get_exp_var name, default=nil

  Get variable value with substituted other variables. E.g. having variables name="Bot" and greeting="Hello, I am %name%", `get_exp_var greeting` will return "Hell, I am Bot".

### state_conf key

  Data from state description (like 'ok_state' etc)

### old_state_conf key

  Data from previous state description

### event_conf key

  Data from state ':event' section

### old_event_conf key

  Data from previous state ':event' section

### send_text txt, opts=nil

  Obviously send text to user

### send_photo photo, type='image/jpeg'

  Send image to user. `photo` - path to image file.

### send_menu menu, opts=nil

  Send menu. Format:
  ```
  [
    [["id1","item 1 menu text"],["id2","..."],...],
    [["line2_id1","..."],...]
  ]
  ```
  or
  ```
  [["id1","item 1 menu text"],["id2","..."],...]
  ```
  Note: telegram supports menus with several lines of buttons, facebook messenger supports only up to 11 buttons and all of them will be placed in one line (you can use first format too).

### set_auth val=1

  (Un)authorize user

### subscribe grp

  Subscribe user to group

### unsubscribe grp

  Unsubscribe user from group

### self.register_processor MyProcessor

  use MyProcessor in bot

### Automatic variables

    username = user name
    authorized = 1 if authorized, 0 if not
    groups = all groups
    user_groups = all groups, user is subscribed to


# Adapters

To implement new adapter you should implement Sender and Loop classes.

## Sender class

### initialize seed, user

  Constructor. `seed` can be anything specific for your adapter, `user` - default user.

### send_message msg, opts={}

  Send text and/or menu. `opts[:chat]` - user address. `opts[:menu]` - menu description (see format in Processors section).

### send_photo photo, type=nil

  Send image. `photo` - path to file, `type` - mime type.

## Loop class

This class should be inherited from TeleLoop class and tho methods:

### self.adapter

  Returns a string, identifying this messenger, e.g. 'nullteleport'. This string will be used in User class as attribute name for messenger id storing, by adding '-id'. E.g.: 'nullteleport-id'

### self.go(stuff, queue)

  This method is called from main code in separated thread. `stuff` is usually token or something like this, but you can better get it from configuration. May be eliminated in the future. `queue` - Queue exemplar, via this queue external event will be delivered to you.

  **Important**! Your code should include something like this:

```
  self.sender=MySender.new(....) # create sender exemplar and store it by `self.sender=...`
  start_async(queue) # start queue processing
```

  You can reassign sender at any time, but it should be actual at every moment and be able to send messages to all users.

# Users class

#### init(path)
Open new yaml-database

#### all
Just get all users in one array

#### all_groups
All possible user groups

#### each
Iterate through users

#### each_with_group(g)
Iterate users, who has given groups

#### save
Sync data to disk

#### add id, data, groups=[]
Create new user. If `id` is nil, generate new unique id (recommended). `data` = hash with initial user data.

#### check_group group
Check if this group exists

#### get_user_groups user
Get list of groups, which given user is subscribed to

#### set_user_groups user, gr
Update user groups

#### add_user_group user, gr
Add new group to user groups

#### del_user_group user, gr
Delete group from user groups

#### grp g
Get group description

#### exist? id
Check if user with given id exists

#### \[\](id)
Get user by id (e.g. Users[123])

#### find_by name, val
Get user by attribute value. E.g. Users.find_by 'Car_model', 'Tesla 42'

#### set id, name, value
Set user attribute, e.g. Users.set 1111, 'Car_model', 'Tesla 42'

#### get id, name
Get user attribute by name

#### set_user_var id, var, value
Set variable, associated with user. It can be not persistent, but works in session

#### del_user_var id, name
Delete variable, associated with user.

#### get_user_var id, var
Get variable value, associated with user.

