module RackspaceQueues
  class Message

    def initialize(queue, message)
      @client = queue.client
      @queue = queue.name

      @id = message["href"].split('/')[-1]
      @body = message["body"]
      @age = message["age"]
      @ttl = message["ttl"]
    end

    def delete!
      @client.request(method: :delete, path: path, expects: 204) && true
    end

    def to_hash
      {ttl: @ttl, body: @body}
    end

    def path
      "/queues/#{@queue}/messages/#{@id}"
    end

    def [](key)
      @body[key]
    end

  end
end
