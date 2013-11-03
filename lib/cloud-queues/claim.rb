module CloudQueues
  class Claim
    include Enumerable

    attr_accessor :default_ttl

    attr_reader :id

    def initialize(queue, id, msgs)
      @client = queue.client
      @queue = queue.name
      @id = id

      # request the messages if we don't already have them
      @messages = msgs || messages

      @default_ttl = 43200 # 12 hours, server max
    end

    def queue
      Queue.new(@client, @queue)
    end

    def each(&block)
      @messages.each(&block)
    end

    def [](index)
      @messages[index] rescue messages[index]
    end

    def messages
      @messages = process_messages(refresh)
    end

    def update(options = {})
      options = options.select { |opt| %w[ttl grace].include?(opt.to_s) }
      options[:ttl] ||= @default_ttl unless options["ttl"]
      @client.request(method: :patch, path: path, body: options, expects: 204) && true
    end

    def delete
      @client.request(method: :delete, path: path, expects: 204) && true
    end
    alias_method :release, :delete

    def path
      "/queues/#{@queue}/claims/#{@id}"
    end

    def age; refresh["age"]; end
    def ttl; refresh["ttl"]; end

    private

    def process_messages(body)
      Messages.new(queue, body["messages"].map{|msg| Message.new(queue, msg) }, body["links"] )
    end

    def refresh
      @client.request(method: :get, path: path).body
    end

  end
end
