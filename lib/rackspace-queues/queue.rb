module RackspaceQueues
  class Queue

    attr :default_ttl

    def initialize(client, name)
      @client = client
      @name = name

      @default_ttl = 1209600 # 14 days, server max
    end

    def messages(options = {})
      if options[:ids]
        allowed_query = %w[ids claim_id]
        options[:ids] = options[:ids].join(',') if options[:ids].class == Array
      else
        allowed_query = %w[marker limit echo include_claimed]
      end

      options = options.select { |opt| allowed_query.include?(opt.to_s) }
      msgs = @client.request(method: :get, path: "#{path}/messages", expects: [200, 204], query: options)
      return [] if msgs.code == 204
      process_messages(msgs.body["messages"])
    end

    def get(id, options = {})
      options = options[:claim_id] ? {claim_id: options[:claim_id]} : {}
      msgs = @client.request(method: :get, path: "#{path}/messages/#{id}", query: options)
      process_messages([msgs.body])[0]
    end

    def put(*msgs)
      msgs = msgs.map do |message|
        begin
          if message.class == Message
            message.to_hash
          elsif message[:body] or message["body"]
            {
              ttl: message[:ttl] || message["ttl"] || @default_ttl,
              body: message[:body] || message["body"],
            }
          else
            { ttl: @default_ttl, body: message }
          end
        rescue
          { ttl: @default_ttl, body: message }
        end
      end

      # TODO this should probably do something with a body["partial"] == true response
      resources = @client.request(method: :post, path: "#{path}/messages", body: msgs, expects: 201).body["resources"]
      resources.map { |resource| resource.split('/')[-1] }
    end

    def delete_messages(*ids)
      ids = options[:ids].join(',')
      @client.request(method: :delete, path: "#{path}/messages", expects: 204, query: {ids: ids}) && true
    end

    def delete!
      @client.request(method: :delete, path: "#{path}", expects: 204) && true
    end
  
    def [](key)
      metadata[key]
    end
  
    def []=(key, value)
      new_data = metadata
      new_data[key] = value
      @client.request(method: :put, path: "#{path}/metadata", body: new_data, expects: 204) && true
    end
  
    def metadata
      @client.request(method: :get, path: "#{path}/metadata").body
    end
  
    def metadata=(new_data)
      @client.request(method: :put, path: "#{path}/metadata", body: new_data, expects: 204) && true
    end

    def stats
      @client.request(method: :get, path: "#{path}/stats").body
    end

    def stat(name)
      stats["messages"][name.to_s]
    end

    def claimed; stat(:claimed); end
    def free; stat(:free); end
    def total; stat(:total); end
    def newest; stat(:newest); end
    def oldest; stat(:oldest); end

    def path
      "/queues/#{@name}"
    end

    private

    def process_messages(msgs)
      msgs.map { |message| Message.new(self, message) }
    end

  end
end
