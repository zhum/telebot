class Users
  class << self

    MAX_ID = 1_000_000_000

    def init(path)
      @@base=YAML::Store.new path

      @@base.transaction do
        @@users=@@base['users'] || {}
        @@groups=@@base['groups'] || {}
      end
    end

    def all
      @@users.dup
    end

    def all_groups
      @@groups.dup
    end

    def each
      @@users.each_pair do |id,u|
        yield(id,u)
      end
    end

    def each_with_group(g)
      TeleLogger.log "each_with_group #{g}"
      @@users.each_pair do |id,u|
        TeleLogger.log "#{id}: #{u[:groups]}"
        yield(id,u) if u[:groups].include? g
      end
    end

    def save
      @@base.transaction do
        @@base['users']=@@users
        @@base['groups']=@@groups
      end    
    end

    # FIXME! Possible race condition
    def add id, data, groups=[]
      id ||= uniq_id
      id = id.to_i
      @@users[id] = data.is_a?(Hash) ? data : {name: data}
      @@users[id][:id] = id
      @@users[id][:vars] = {}
      @@users[id][:groups]=groups.map { |e| e.to_s }
      update_groups @@users[id][:groups]
    end

    # FIXME! Possible race condition
    def update_groups list #hash or array
      updated=false
      if list.is_a? Array
        list.each do |grp|
          next if check_group grp
          @@groups[grp]=grp.to_s
          updated=true
        end
      else
        list.each_pair do |grp,name|
          next if check_group grp
          @@groups[grp]=name
          updated=true
        end
      end
      save if updated
    end

    def check_group group
      @@groups.has_key? group.to_s
    end

    def get_user_groups user
      @@users[user.to_i][:groups]
    end

    def set_user_groups user, gr
      @@users[user.to_i][:groups]=gr
      @@base.transaction do
        @@base['users'][user]=@@users[user]
      end    
      update_groups gr
    end

    def add_user_group user, gr
      gr=gr.to_s
      return if @@users[user.to_i][:groups].include? gr
      @@users[user.to_i][:groups] << gr
      update_groups [gr]
    end

    def del_user_group user, gr
      gr=gr.to_s
      return unless @@users[user.to_i][:groups].include? gr
      @@users[user.to_i][:groups] -= [gr]
      update_groups @@users[user.to_i][:groups]
    end

    def grp g
      @@groups.fetch(g,nil)
    end

    def exist? id
      @@users.has_key? id.to_i
    end

    def [](id)
      if exist? id
        @@users[id.to_i].clone.tap{|x| x[:id]=id.to_i}
      else
        nil
      end
    end

    def find_by name, val
      sval=val.to_s
      @@users.select{|k,v| v[name].to_s==sval}.values[0].clone
    end

    #FIXME! Possible race condition
    def set id, name, value
      if exist? id
        @@users[id.to_i][name]=value
        save
      end
    end

    def get id, name
      if exist? id
        @@users[id.to_i][name]
      else
        nil
      end
    end

    def set_user_var id, var, value
      u = @@users[id]
      if u
        u[:vars] ||= {}
        u[:vars][var] = value
        @@base.transaction do
          @@base['users'][id] = u
        end
      end
    end
    
    def del_user_var id, name
      u = @@users[id]
      if u && u[:vars]
        u[:vars].delete name
        @@base.transaction do
          @@base['users'][id] = u
        end
      end
    end

    def get_user_var id, var
      u = @@users[id]
      if u
        if u[:vars]
          return u[:vars][var]
        end
      end
      nil
    end
    private

    def uniq_id
      loop do
        id = rand MAX_ID
        if @@users[id].nil?
          return id
        end
      end
    end
  end
end
