###############################################
#
#!!! Monkey patch for proxy support
#
###############################################
module Faraday
  class Adapter
    class NetHttp
      def net_http_connection(env)
        proxy = Telegram::Bot.configuration.proxy_opts
        if proxy
          env[:ssl] ||= Telegram::Bot.configuration.ssl_opts
          if proxy[:socks]
            sock_proxy(proxy)
          else
            http_proxy(proxy)
          end
        else
          Net::HTTP
        end.new(env[:url].host, env[:url].port)
      end
      private
      def sock_proxy(proxy)
        #warn "SOCKS_PROXY: '#{proxy[:uri]}'"
        proxy_uri = URI.parse(proxy[:uri])
        TCPSocket.socks_username = proxy[:user] if proxy[:user]
        TCPSocket.socks_password = proxy[:password] if proxy[:password]
        Net::HTTP::SOCKSProxy(proxy_uri.host, proxy_uri.port)
      end
      def http_proxy(proxy)
        #warn "HTTP_PROXY: '#{proxy[:uri]}'"
        proxy_uri = URI.parse(proxy[:uri])
        Net::HTTP::Proxy(proxy_uri.host,
                         proxy_uri.port,
                         proxy_uri.user,
                         proxy_uri.password)
      end
    end
  end
end

module Telegram
  module Bot
    class Configuration
      attr_accessor :proxy_opts, :ssl_opts
    end
  end
end
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#
# End monkey patch
#

Telegram::Bot.configure do |config|
  cfg=TeleConfig.data[:conf]
  config.ssl_opts = {verify: false}
  if cfg['proxy'].to_s!=''
    config.proxy_opts = {
      uri: cfg['proxy'],
      socks: cfg['proxy_http'].to_s=='yes' ? false : true,
    }
    if cfg['proxy_user'].to_s!=''
      config.proxy_opts[:user]=cfg['proxy_user']
      config.proxy_opts[:password]=cfg['proxy_pass'].to_s
    end
  end
end




class TelegramSender
  def initialize bot, user=nil
    @bot = bot
    @user = user
  end

  def user= u
    @user = u
  end

  def send_message msg, opts={}
    chat = opts[:chat].nil? ? @user[:'telegram-id'] : opts[:chat]
    message={chat_id: chat, text: msg}
    if opts[:menu]
      message.merge!(reply_markup: mk_keyboard(opts[:menu]))
    end
    #warn ">>> #{message.inspect}"
    #@bot.api.send_message chat_id: chat, text: msg, reply_markup: Telegram::Bot::Types::ReplyKeyboardRemove.new(remove_keyboard: true)
    @bot.api.send_message message
  end

  def send_photo photo, type='image/jpeg', chat=nil
    if chat.nil?
      chat=@user[:id]
    end
    io = Faraday::UploadIO.new(photo,type)
    @bot.api.send_photo photo: io, chat_id: chat
  end

  private
  def mk_keyboard array
    # should be [ [ [action,text],... ], ...] (array levels rows/line/action+text)
    array = [array] unless array[0][0].instance_of?(Array)

    f=array.map{|lines|
      lines.map{|k|
        Telegram::Bot::Types::InlineKeyboardButton.new(callback_data: k[0], text: k[1])
      }
    }
    Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: f)
  end
end

class TelegramLoop < TeleLoop

  RETRY_DELAY = 2

  # def self.log x
  #   TeleLogger.log x
  # end
  def self.adapter
    'telegram'
  end

  def self.go(token, queue)
    loop do
      begin
        Telegram::Bot::Client.run(token) do |bot|
          self.sender = TelegramSender.new(bot)
          start_async(queue)
          bot.listen do |message|
            log "GOT message=#{message}"
            user = if Users.exist?(message.from.id)
              log "Old buddy!"
              Users[message.from.id]
            else
              log "New buddy!"
              name = (message.from.first_name || '')+' '+(message.from.last_name || '')
              name = message.from.username if name==' '
              u = Users.add message.from.id, name
              u[:'telegram-id'] = message.from.id
              Users.save
              u
            end
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
            text = case message
            when Telegram::Bot::Types::CallbackQuery
              message.data
            when Telegram::Bot::Types::Message
              message.text
            else
              "OOOPS: #{message.inspect}"
            end

            on_message processor, type: :text, text: text

            log "user=#{Users[message.from.id].inspect}"
          end
        end
      rescue => e
        log "TelegramLoop exception: #{e.message}\nTraceback:\n#{e.backtrace.join "\n"}\nWorking further!"
      end
      #stop_async
      sleep RETRY_DELAY
    end
  end
end

