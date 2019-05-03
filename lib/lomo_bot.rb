require "sinatra/base"

class LomoBot < Sinatra::Base

  DEF_AUTH_TOKEN = ::TeleConfig[:conf]['service_token']
  @@auth_token = DEF_AUTH_TOKEN

  def users
    @@users
  end

  def auth_token= a
    @@auth_token = a
  end

  def auth_token
    @@auth_token || DEF_AUTH_TOKEN
  end

  def check_token
    token = env['HTTP_X_AUTH_TOKEN'] || params[:token]
    token==auth_token
  end

  before do
    if request.post?
      halt(401, "Don't you post here...") unless check_token
    else
      halt(401, 'Nothing here...')
    end
  end

  post '/event/:from' do
    from=params[:from]
    TeleLogger.log "Got external #{from} (reenter=#{params[:reenter]}): #{params[:body]}"
    if Users.check_group from
      TeleLogger.log "Group: #{from}"
      @@queues.each{|q|
        q << {
          type: :grp_message,
          group: from,
          text: params[:body],
          reenter: params[:reenter].to_i,
        }
      }
      200
    elsif Users[from]
      TeleLogger.log "User: #{from}"
      @@queues.each{|q|
        q << {
          type: :user_message,
          id: from,
          text: params[:body],
          reenter: params[:reenter].to_i,
        }
      }
      200
    else
      [404,'','No such user or group']
    end
  end
end
