module CloudQueues
  class Messages
    include Enumerable

    attr_accessor :queue

    attr_reader :marker

    def initialize(queue, msgs, links)
      @queue = queue
      @messages = msgs

      @marker = find_marker links if links
    end

    def each(&block)
      @messages.each(&block)
    end

    def [](index)
      @messages[index]
    end

    def next(options = {})
      if @marker
        @queue.messages options.merge(marker: @marker)
      else
        # We don't have a next marker because this set of messages was
        # never intended to be part of a larger set.
        nil
      end
    end

    private

    def find_marker(links)
      uri = URI.parse(links.select{|link| link["rel"] == "next" }[0]["href"])
      return uri.query.match(/marker=([^&]+)/)[1]
    end

  end
end
