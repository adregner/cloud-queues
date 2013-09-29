module RackspaceQueues
  class Message

    attr_reader :id, :body

    def initialize(queue, message)
      @client = queue.client
      @queue = queue.name

      href = URI.parse(message["href"])
      @id = href.path.split('/')[-1]
      @claim = href.query.match(/(^|&)claim_id=([^&]+)/)[2] rescue nil
      @body = message["body"]
      @age = message["age"]
      @ttl = message["ttl"]
    end

    def delete!
      @client.request(method: :delete, path: path, expects: 204) && true
    end

    # TODO def queue
    # TODO def claim
    # TODO def age
    # TODO def ttl

    def to_hash
      {ttl: @ttl, body: @body}
    end

    # beware using this path method.  it could return a path with a query argument
    # at the end.  this is to ensure the claim_id is provided whenever operations
    # against this message are performed, however it could end up causing string
    # formatting problems depending on how it's used.
    def path
      query = @claim ? "?claim_id=#{@claim}" : ""
      "/queues/#{@queue}/messages/#{@id}#{query}"
    end

    def [](key)
      @body[key]
    end

  end
end
