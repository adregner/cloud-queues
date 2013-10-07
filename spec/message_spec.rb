require 'spec_helper'
require 'authenticated_context'

describe "working with messages" do
  include_context "authenticated as rackspace cloud user"

  describe CloudQueues::Message do
    before do
      @name = Faker::Lorem.words.join('-')
      @queue = client.create @name
      message_id = @queue.put({number: 12345, string: "pretty dog"})
      @message = @queue.get message_id[0]
    end

    context "existing messages" do
      it "should have some messages" do
        expect(@queue.total).to eq(1)
        expect(@message).to be_an_instance_of(CloudQueues::Message)
      end

      it "should access the body as if the message were a Hash" do
        expect(@message['number']).to eq(12345)
        expect(@message['string']).to eq('pretty dog')
      end

    end

    after do
      @queue.delete!
    end
  end
end
