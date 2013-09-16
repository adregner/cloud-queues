require 'spec_helper'
require 'authenticated_context'

describe RackspaceQueues do
  it "should have a version number" do
    RackspaceQueues::VERSION.class.should eq(String)
  end
end

describe RackspaceQueues::Client do
  it "should error without credentials" do
    expect { described_class.new }.to raise_error(ArgumentError)
  end

  it "should error without username" do
    expect { described_class.new api_key: '1234567890abcdef' }.to raise_error(ArgumentError)
  end

  it "should error without api_key" do
    expect { described_class.new username: 'bob' }.to raise_error(ArgumentError)
  end

  context "instance" do
    include_context "authenticated as rackspace cloud user"

    it "should be signed in" do
      expect(client).to be_an_instance_of(RackspaceQueues::Client)
    end

    it "should have a client id" do
      expect(client.client_id).to_not be_nil
    end

    describe "managing queues" do
      queue_name = Faker::Lorem.words.join

      it "can create a queue" do
        expect(client.create(queue_name)).to be_an_instance_of(RackspaceQueues::Queue)
      end

      it "can get a queue" do
        expect(client.get(queue_name)).to be_an_instance_of(RackspaceQueues::Queue)
      end

      it "can delete a queue" do
        q = client.get(queue_name)
        expect(q.delete!).to be_true
      end
    end

  end
end
