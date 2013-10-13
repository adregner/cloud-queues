require 'spec_helper'
require 'authenticated_context'

describe "working with a queue" do
  include_context "authenticated as rackspace cloud user"

  before do
    @name = Faker::Lorem.words.join('-')
    @queue = client.create @name
  end

  describe CloudQueues::Queue do
    it "has a name" do
      expect(@queue.name).to eq(@name)
    end

    it "has a default ttl of 14 days" do
      expect(@queue.default_ttl).to eq(14 * 24 * 60 * 60)
    end

    it "has no messages at first" do
      expect(@queue.messages).to be_empty
    end

    it "has no stats" do
      expect(@queue.claimed).to eq(0)
      expect(@queue.free).to eq(0)
      expect(@queue.total).to eq(0)
      expect(@queue.newest).to be_nil
      expect(@queue.oldest).to be_nil
    end

    it "has no metadata" do
      expect(@queue.metadata).to be_empty
    end

    it "can have metadata" do
      value = Faker::Lorem.words
      @queue['letters'] = value
      expect(@queue['letters']).to eq(value)

      number = (Random.rand * 9999).to_i
      @queue['numbers'] = number
      expect(@queue['numbers']).to eq(number)

      metadata = @queue.metadata
      expect(metadata['letters']).to eq(value)
      expect(metadata['numbers']).to eq(number)
    end

    it "can set metadata in bulk" do
      new_data = {apples: "with carmel", bananas: "are soft"}
      @queue.metadata = new_data
    end

    context "should accept a string message" do
      subject { @queue.put("Hello world.") }
      include_examples "message id collection", 1
    end

    context "should accept multiple string messages" do
      subject { @queue.put("Apples", "Bananas", "Celery", "Donuts", "Eggplant") }
      include_examples "message id collection", 5
    end

    it "should not accept more then 10 messages at once" do
      expect { @queue.put 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten',
        'too many' }.to raise_error(ArgumentError, "Only 10 or less messages may be given at once")
    end

    context "should accept a structured message" do
      subject { @queue.put(ttl: 7*86400, body: "You have 1 week to change your password.") }
      include_examples "message id collection", 1
    end

    context "should only require a body key of a structured message" do
      subject { @queue.put(body: "on the road again..>") }
      include_examples "message id collection", 1
    end

    context "should accept a mix of structured and string messages" do
      subject { @queue.put({body: "something nice", ttl: 3600}, "something simple", {body: "something <blue/>"}) }
      include_examples "message id collection", 3
    end

    context "should accept an object as a non-structured message" do
      subject { @queue.put({event: "new-domain-name", payload: "foobar.org", owner: 9876}) }
      include_examples "message id collection", 1

      it "should have the same body" do
        message = @queue.get subject[0]
        expect(message.body).to eq({"event" => "new-domain-name", "payload" => "foobar.org", "owner" => 9876})
      end

      it "can repost the same Message object back as a new message" do
        message = @queue.get subject[0]
        result = @queue.put message
        expect(result.count).to eq(1)
        expect(message.body).to eq(@queue.get(result[0]).body)
      end
    end

    it "can get and delete messages in bulk" do
      message_ids = @queue.put 'a', 'b', 'c'

      messages = @queue.messages ids: message_ids
      expect(messages.count).to eq(3)
      expect(@queue.delete_messages(*message_ids[0..1])).to be(true)
      messages = @queue.messages ids: message_ids
      expect(messages.count).to eq(1)

      message = @queue.get(message_ids[2])
      expect(message.body).to eq('c')
    end

    it "cannot get more then 20 messages at a time" do
      expect { @queue.messages ids: 21.times.map{|n| n} }.to raise_error(ArgumentError, "Only 20 or less message IDs may be specified")
    end

    # This is really here to test the CloudQueues::Client#request_all functionality
    context "a lot of messages" do
      subject do
        8.times { @queue.put(*(Faker::Lorem.words + Faker::Lorem.words + Faker::Lorem.words)) }
      end

      it "has a large total" do
        subject
        expect(@queue.total).to be == 72
      end

      it "can get all those messages" do
        subject
        expect(@queue.messages(echo: true).count).to be == 72
      end

      it "will still only get a smaller number of messages" do
        subject
        expect(@queue.messages(echo: true, limit: 24).count).to eq(30)
        expect(@queue.messages(echo: true, limit: 4).count).to eq(4)
      end

    end

    context "a short and a long lived message" do
      subject(:message_ids) { @queue.put("something long", {body:"something short", ttl:60}) }

      it "should not return the short lived message", slow: true do
        expect(message_ids.count).to eq(2)
        messages = @queue.messages ids: message_ids
        expect(messages.count).to eq(2)

        # wait for the short thing to expire
        # this also tests that the client class can re-connect after the keep-alive expires
        sleep 60

        # From the docs: "To allow for flexibility in storage implementations, the server might
        # not actually delete the message until its age reaches up to (ttl + 60) seconds."
        60.times do
          messages = @queue.messages ids: message_ids
          break if messages.count == 1
          sleep 1
        end

        expect(messages.count).to eq(1)
      end
    end
  end

  after { @queue.delete! }

end
