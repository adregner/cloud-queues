require 'singleton'
require 'yaml'

class ClientWarehouse
  include Singleton

  def initialize
    @house = {}
  end

  def get(args)
    @house[args[:username]] ||= RackspaceQueues::Client.new args
  end
end

shared_context "authenticated as rackspace cloud user", region: nil do
  let(:client) do
    args = YAML.load_file(File.realpath("../../.rackspace-spec-creds", __FILE__))
    ClientWarehouse.instance.get(args)
  end
end
