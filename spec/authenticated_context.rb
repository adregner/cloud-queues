require 'singleton'
require 'yaml'

class ClientWarehouse
  include Singleton

  def initialize
    @house = {}
  end

  def get(args = {})
    key = args[:region] || :default
    return @house[key] if @house.include?(key)
    @house[key] = build(key)
  end

  def build(key)
    if ENV['RACKSPACE_SPEC_CREDS_USERNAME'] and ENV['RACKSPACE_SPEC_CREDS_KEY']
      args = {username: ENV['RACKSPACE_SPEC_CREDS_USERNAME'], api_key: ENV['RACKSPACE_SPEC_CREDS_KEY']}
    else
      args = YAML.load_file(File.realpath("../../.rackspace-spec-creds", __FILE__))
    end
    args.merge! region: key unless key == :default
    CloudQueues::Client.new(args)
  end
end

shared_context "authenticated as rackspace cloud user" do
  let(:client) do
    ClientWarehouse.instance.get
  end
end

#shared_context "new queue" do
#  client = ClientWarehouse.instance.get
#  queue = client.create(Faker::Lorem.words.join('-'))
#  let(:queue) { queue }
#end
