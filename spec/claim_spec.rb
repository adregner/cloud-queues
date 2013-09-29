require 'spec_helper'
require 'authenticated_context'

describe "claiming messages" do
  include_context "authenticated as rackspace cloud user"

  before(:all) do
    # TODO handle deprecated behavior here somehow (let(:client) inside a before(:all))
    @name = Faker::Lorem.words.join('-')
    @queue = client.create @name
    @queue.put *%w[a b c d e f g h i j k l]
  end

  it "should have messages with no claims" do
    expect(@queue.free).to eq(12)
    expect(@queue.total).to eq(12)
    expect(@queue.claimed).to eq(0)
  end

  describe RackspaceQueues::Claim do
    before { @claim = @queue.claim limit: 2 }

    context "existing messages" do
      it "should have some messages" do
        expect(@queue.total).to eq(12)
      end

      it "can claim 2 messages" do
        expect(@claim).to be_an_instance_of(described_class)
        expect(@claim.count).to eq(2)
        @claim.ttl.should be > 1
        @claim.age.should be < 10

        @claim.each do |message|
          expect(message).to be_an_instance_of(RackspaceQueues::Message)
          expect(message.body).to be_an_instance_of(String)
        end
      end

      it "should update its stats" do
        expect(@queue.free).to eq(10)
        expect(@queue.total).to eq(12)
        expect(@queue.claimed).to eq(2)

        @claim.delete

        expect(@queue.free).to eq(12)
        expect(@queue.total).to eq(12)
        expect(@queue.claimed).to eq(0)
      end

      it "can have two claims" do
        another_claim = @queue.claim limit: 5
        expect(another_claim.count).to eq(5)
        expect(@queue.free).to eq(5)
        expect(@queue.claimed).to eq(7)
        another_claim.delete
      end

      it "can consume messages" do
        consumed = @claim[1]
        consumed.delete!

        # Claim#messages is called to refresh the list of avaliable messages
        expect(@claim.messages.count).to eq(1)
        expect(@queue.total).to eq(11)
        expect(@queue.free).to eq(10)

        remaining = @queue.claim # default limit should be 10
        expect(remaining.count).to eq(10)
        expect(remaining.collect{|message| message.body } + [@claim.first.body]).to_not include(consumed.body)
      end

      after { @claim.delete rescue nil }

    end
  end

  after(:all) { @queue.delete! }

end
