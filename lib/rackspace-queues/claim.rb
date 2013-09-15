module RackspaceQueues
  class Claim
    include Enumerable

    attr_accessor :default_ttl

    def initialize(queue, id, messages)
      @client = queue.client
      @queue = queue.name
      @id = id

      @messages = messages

      @default_ttl = 43200 # 12 hours, server max
    end

    def age
      refresh["age"]
    end

    def ttl
      refresh["ttl"]
    end

    def each(&block)
      @messages.each(&block)
    end

    def [](index)
      @messages[index]
    end

    def messages
      msgs = refresh["messages"]
      @messages = msgs.map { |message| Message.new(@client, @queue, message) }
    end

    def update(options = {})
      options = options.select { |opt| %w[ttl grace].include?(opt.to_s) }
      options[:ttl] ||= @default_ttl unless options["ttl"]
      @client.request(method: :patch, path: path, body: options, expects: 204) && true
    end

    def delete
      @client.request(method: :delete, path: path, expects: 204) && true
    end
    alias_method :delete, :release

    def path
      "/queues/#{@queue}/claims/#{@id}"
    end

    private

    def refresh
      @client.request(method: :get, path: path).body
    end

  end
end
