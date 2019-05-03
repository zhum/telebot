require "sinatra"
require 'facebook/messenger'

class FacebookSender
  def initialize conn, user=nil
    @conn = conn
    @user = user
  end

  def user= u
    @user = u
  end

  def send_message msg, opts={}
    chat = opts[:chat].nil? ? @user[:'facebook-id'] : opts[:chat]
    message_options = {
      recipient: { id: chat },
      message: { text: msg },
    }
    if opts[:menu]
      message_options[:message].merge! :quick_replies => mk_keyboard(opts[:menu])
    end
    FBRunner.deliver(message_options) #, access_token: TeleConfig[:conf]['fb_token'])
  end

  def send_photo photo, type=nil, chat=nil
    basename = photo.gsub(/.*\//,'')
    FileUtils.cp(photo,"file/#{basename}")
    chat = chat.nil? ? @user[:'facebook-id'] : chat
    message_options = {
      recipient: { id: chat },
      message: {
        attachment: {
          type: "image", 
          payload: {
            url: "#{http_base}/file/#{basename}",
            is_reusable: true
          }
        }
      }
    }
    warn "image-> #{message_options.inspect}"
    FBRunner.deliver(message_options) #, access_token: TeleConfig[:conf]['fb_token'])
  end

  private

  def http_base
    TeleConfig[:conf]['server_base']
  end

  def mk_keyboard array
    # should be [ [ [action,text],... ], ...] (array levels rows/line/action+text)
    array = [array] unless array[0][0].instance_of?(Array)

    array.map{|lines|
      lines.map{|k|
        {content_type: 'text', payload: k[0], title: k[1]}
      }
    }.flatten
  end
end

class FBConfigProvider < Facebook::Messenger::Configuration::Providers::Base
  # Verify that the given verify token is valid.
  #
  # verify_token - A String describing the application's verify token.
  #
  # Returns a Boolean representing whether the verify token is valid.
  def valid_verify_token?(verify_token)
    TeleConfig[:conf]['fb_verify_token'] == verify_token
  end

  # Find the right application secret.
  #
  # page_id - An Integer describing a Facebook Page ID.
  #
  # Returns a String describing the application secret.
  def app_secret_for(page_id)
    TeleConfig[:conf]['fb_app_secret']
  end

  # Find the right access token.
  #
  # recipient - A Hash describing the `recipient` attribute of the message coming
  #             from Facebook.
  #
  # Note: The naming of "recipient" can throw you off, but think of it from the
  # perspective of the message: The "recipient" is the page that receives the
  # message.
  #
  # Returns a String describing an access token.
  # def access_token_for(recipient)
  #   #bot.find_by(page_id: recipient['id']).access_token
  #   nil
  # end

end

class FileServer < Sinatra::Base
  set :public_folder, 'file'
  set :static, true
end

class FBRunner < Sinatra::Base
  include Facebook::Messenger

  def self.log x
    FacebookLoop.log x  
  end

  Facebook::Messenger.configure do |config|
    config.provider = FBConfigProvider.new
  end

  def self.deliver payload
    Bot.deliver(payload, access_token: TeleConfig[:conf]['fb_token'])
  end

  def self.process_message type, message
    sender_id = message.sender.nil? ? 'console' : message.sender['id']

    user = Users.find_by :'facebook-id', sender_id
    unless user
      log "New buddy!"
      user = Users.add nil, :'facebook-id' => sender_id, :name => "Facebook User #{sender_id}", :state => 'main'
      Users.save
      user = Users.find_by :'facebook-id', sender_id
    end
    snd = FacebookSender.new(self,user)
    processor = StateProcessor.new(
        user[:state] || 'main',
        user: user,
        conf: TeleConfig.data,
        sender: snd,
      )
    if user[:state].to_s==''
      log "Reset state for user #{user[:id]}"
      Users.set user[:id], :state, 'main'
      user=Users.find_by :'facebook-id', sender_id
    end

    txt = nil
    case type
    when :text
      q = message.quick_reply
      if q
        txt = q
      else
        txt = message.text
      end
    when :postback
      txt = message.payload
    else
      warn "Bad message type #{type}"
      txt = '...'
    end
    log "TEXT=#{txt}"
    FacebookLoop.on_message processor, type: :text, text: txt    
    log "user=#{Users.find_by(:'facebook-id', sender_id).inspect}"
  end

  Bot.on :postback do |postback|
    process_message :postback, message
  end

  Bot.on :message do |message|
    process_message :text, message
  end
end

class FacebookLoop < TeleLoop

  def self.adapter
    'facebook'
  end

  def self.go(token, queue)
    self.sender=FacebookSender.new(FBRunner)
    start_async(queue)
    
    dispatch = Rack::Builder.app do
      map '/webhook' do
        run FBRunner.new
        run Facebook::Messenger::Server.new
      end
      map '/file' do
        run FileServer.new
      end
    end

    Rack::Server.start(
      app: dispatch,
      Port: (TeleConfig[:conf]['fb_port'] || 5550),
      Host: '0.0.0.0'
      )
  end
end

