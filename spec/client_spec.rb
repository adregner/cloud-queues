require 'spec_helper'
require 'authenticated_context'

describe CloudQueues do
  it "should have a version number" do
    CloudQueues::VERSION.class.should eq(String)
  end
end

describe CloudQueues::Client do
  include_context "authenticated as rackspace cloud user"

  it "should error without credentials" do
    expect { described_class.new }.to raise_error(ArgumentError)
  end

  it "should error without username" do
    expect { described_class.new api_key: '1234567890abcdef' }.to raise_error(ArgumentError, "username is a required argument.")
  end

  it "should error without api_key" do
    expect { described_class.new username: 'bob' }.to raise_error(ArgumentError, "api_key is a required argument.")
  end

  it "should error when given an invalid region" do
    # wouldn't it be funny if SAT[12] re-opened and we put a cloud in there??
    expect { ClientWarehouse.instance.get(region: :sat) }.to raise_error(ArgumentError, "Region SAT does not exist!")
  end

  context "instance" do
    it "should be signed in" do
      expect(client).to be_an_instance_of(CloudQueues::Client)
    end

    it "should have a client id" do
      expect(client.client_id).to_not be_nil
    end

    it "can change the client id" do
      new_client_id = "#{Faker::Lorem.words.join}.rspec.local"
      client.client_id = new_client_id
      expect(client.client_id).to eq(new_client_id)
    end

    it "will re-authenticate if the token is poisioned" do
      original_token = client.token
      client.token = "foobar"
      expect(client.token).to eq("foobar")

      expect(client.queues).to be_an_instance_of(Array)
      client.token.should_not eq("foobar")
      # the auth API will sometimes re-issue the same token, so we can't compare to original_token
    end

    it "can be constructed with a valid token and tenant" do
      token = client.token
      tenant = client.tenant

      new_client = CloudQueues::Client.new token: token, tenant: tenant

      expect(new_client).to be_an_instance_of(CloudQueues::Client)
      client.client_id.should_not eq(new_client.client_id)
    end

    describe "managing queues" do
      queue_name = Faker::Lorem.words.join

      it "can create a queue" do
        expect(client.create(queue_name)).to be_an_instance_of(CloudQueues::Queue)
      end

      it "can get a queue" do
        expect(client.get(queue_name)).to be_an_instance_of(CloudQueues::Queue)
      end

      it "can list all queues" do
        queues = client.queues
        queues.length.should be > 0
        queues.each do |queue|
          expect(queue).to be_an_instance_of(CloudQueues::Queue)
        end
      end

      it "can delete a queue" do
        q = client.get(queue_name)
        expect(q.delete!).to be_true
      end
    end

  end

  it "should return a requested region" do
    # TODO when Cloud Queues goes GA, change this to something strange like "SYD"
    expect(ClientWarehouse.instance.get(region: :ord)).to be_an_instance_of(CloudQueues::Client)
  end
end
