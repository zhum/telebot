#
# client: nc -U /tmp/tele_text_sock
#
class TextSender
  def initialize conn, user=nil
    @conn = conn
    @user = user
  end

  def user= u
    @user = u
  end

  def send_message msg, opts={}
    chat = opts[:chat].nil? ? @user[:id] : opts[:chat]
    message={chat_id: chat, text: msg}
    if opts[:menu]
      message.merge! mk_keyboard(opts[:menu])
    end
    warn ">>> #{message.inspect}"
    @conn.write message[:text]
    @conn.write "\n"
    if message[:inline_keyboard]
      @conn.write "--- menu ---\n|"
      message[:inline_keyboard].each{|row|
        @conn.write row.map{|l|
          "#{l[:text]}(#{l[:callback_data]})"
        }.join(' | ')
        @conn.write "|\n------------\n"
      }
    end
  end

  def send_photo photo, type='image', chat=nil
    if chat.nil?
      chat=@user[:id]
    end
    message = {photo: photo, chat_id: chat}
    @conn.write message.inspect
  end

  private
  def mk_keyboard array
    # should be [ [ [action,text],... ], ...] (array levels rows/line/action+text)
    array = [array] unless array[0][0].instance_of?(Array)

    f=array.map{|lines|
      lines.map{|k|
        {callback_data: k[0], text: k[1]}
      }
    }
    {inline_keyboard: f}
  end
end


class TextLoop < TeleLoop

  # def self.log x
  #   TeleLogger.log x
  # end
  def self.adapter
    'text'
  end

  def self.go(socket_path, queue)
    #telebot = nil
    loop do
      begin
        begin
          File.delete(socket_path)
        rescue
        end
        sock = UNIXServer.open(socket_path)
        conn = sock.accept
        self.sender = TextSender.new(conn)
        # telebot = TelebotAsync.new(queue).run! {|x|
        #   async_process(sender,x)
        # }
        start_async(queue)

        ################################  On connect
        #
        user = Users[987654321]
        self.sender.user = user
        processor = StateProcessor.new(
            user[:state] || 'main',
            user: user,
            conf: TeleConfig.data,
            sender: self.sender,
          )

        # do a trick - just_enter requires @new_state to be set
        processor.change_state processor.state
        processor.just_enter
        #
        ################################  ~On connect

        buffer = ''
        loop do
          begin
            text = conn.read_nonblock(4096)
            buffer = "#{buffer}#{text}"
          rescue Errno::EAGAIN
            sleep 0.2
            next
          end

          message = nil
          buffer.gsub!(/^([^\n]+\n)/m){|msg| message = msg; ''}
          next if message.to_s==''

          # got a line!
          message.force_encoding('UTF-8').chomp!
          log "***** GOT message=#{message}"
          user = Users[987654321]
          log "USER=#{user.inspect}"
          self.sender.user = user

          processor = StateProcessor.new(
            user[:state] || 'main',
            user: user,
            conf: TeleConfig.data,
            sender: self.sender,
          )
          
          if user[:state].to_s==''
            log "Reset state for user #{user[:id]}"
            Users.set user[:id], :state, 'main'
            user=Users[message.from.id]
          end

          on_message processor, type: :text, text: message

        end #inner loop
      rescue => e
        log "TextLoop exception: #{e.message}\nTraceback:\n#{e.backtrace.join "\n"}\nWorking further!"
      end
      # telebot.kill if telebot
      #stop_async
    end #outer loop
  end
end

