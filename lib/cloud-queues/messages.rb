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
        more = @queue.messages options.merge(marker: @marker)
        if more.class == Array and more.count == 0
          @messages = more
          return self
        end
        return more
      else
        # We don't have a next marker because this set of messages was
        # never intended to be part of a larger set.
        return nil
      end
    end

    private

    def find_marker(links)
      uri = URI.parse(links.select{|link| link["rel"] == "next" }[0]["href"])
      return uri.query.match(/marker=([^&]+)/)[1]
    end

  end
end
