require 'spec_helper'
require 'authenticated_context'

describe "claiming messages" do
  include_context "authenticated as rackspace cloud user"

  before(:all) do
    # TODO handle deprecated behavior here somehow (let(:client) inside a before(:all))
    @name = Faker::Lorem.words.join('-')
    @queue = client.create @name
    @message_ids = @queue.put *%w[a b c d e f g h i j]
  end

  it "should have messages with no claims" do
    expect(@queue.free).to eq(10)
    expect(@queue.total).to eq(10)
    expect(@queue.claimed).to eq(0)
  end

  describe CloudQueues::Claim do
    before { @claim = @queue.claim limit: 2 }

    context "existing messages" do
      it "should have some messages" do
        expect(@queue.total).to eq(10)
      end

      it "can claim 2 messages and enumerate the claim" do
        expect(@claim).to be_an_instance_of(described_class)
        expect(@claim.count).to eq(2)
        @claim.ttl.should be > 1
        @claim.age.should be < 10

        @claim.each do |message|
          expect(message).to be_an_instance_of(CloudQueues::Message)
          expect(message.body).to be_an_instance_of(String)
        end
      end

      it "can be deleted and update its stats" do
        expect(@queue.free).to eq(8)
        expect(@queue.total).to eq(10)
        expect(@queue.claimed).to eq(2)

        @claim.delete

        expect(@queue.free).to eq(10)
        expect(@queue.total).to eq(10)
        expect(@queue.claimed).to eq(0)
      end

      it "can refresh the claim" do
        expect(@claim.ttl).to eq(@claim.default_ttl)
        @claim.update(ttl: 200)
        expect(@claim.ttl).to eq(200)
      end

      it "can get specific messages within the claim" do
        unclaimed_id = @queue.messages(echo: true)[-1].id
        claimed_ids = @claim.messages.collect{|message| message.id }

        # I'm not sure what the expected return from the server is, but at least
        # this will test that one last line of code in queue.rb
        expect(@queue.messages(ids: claimed_ids + [unclaimed_id], claim_id: @claim.id).count).to eq(claimed_ids.count + 1)
      end

      it "can have two claims" do
        another_claim = @queue.claim limit: 5
        expect(another_claim.count).to eq(5)
        expect(@queue.free).to eq(3)
        expect(@queue.claimed).to eq(7)
        another_claim.delete
      end

      it "can consume messages" do
        consumed = @claim[1]
        consumed.delete!

        # Claim#messages is called to refresh the list of avaliable messages
        expect(@claim.messages.count).to eq(1)
        expect(@queue.total).to eq(9)
        expect(@queue.free).to eq(8)

        remaining = @queue.claim # default limit should be 10
        expect(remaining.count).to eq(8)
        expect(remaining.collect{|message| message.body } + [@claim.first.body]).to_not include(consumed.body)
      end

      it "doesn't fail when there are no messages" do
        @queue.delete_messages *@message_ids
        empty_claim = @queue.claim

        expect(empty_claim).to be_an_instance_of(Array)
        expect(empty_claim.count).to eq(0)
      end

      after { @claim.delete rescue nil }

    end
  end

  after(:all) { @queue.delete! }

end
