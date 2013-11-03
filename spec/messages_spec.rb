require 'spec_helper'
require 'authenticated_context'

describe "a set of messages" do
  include_context "authenticated as rackspace cloud user"

  before do
    @name = Faker::Lorem.words.join('-')
    @queue = client.create @name
    @queue.put 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
    @queue.put 11, 12, 13, 14, 15, 16, 17, 18, 19, 20

    client.client_id = SecureRandom.uuid
    @messages = @queue.messages limit: 5
  end

  describe CloudQueues::Messages do
    it "is our own instance" do
      expect(@messages).to be_an_instance_of(CloudQueues::Messages)
    end

    it "it enumerable" do
      count = 0
      @messages.each { count += 1 }
      expect(count).to eq(5)
    end

    it "contains Message instances" do
      expect(@messages.first).to be_an_instance_of(CloudQueues::Message)
    end

    it "can get the next set of messages" do
      more_messages = @messages.next
      expect(more_messages.count).to eq(15)
    end
  end

  after { @queue.delete! }

end
