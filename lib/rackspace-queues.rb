gem 'excon', '~> 0.25.0'
require 'json'
require 'socket'
require 'uri'

require_relative "rackspace-queues/version"
require_relative "rackspace-queues/client"
require_relative "rackspace-queues/queue"
require_relative "rackspace-queues/message"
require_relative "rackspace-queues/claim"
