require "./" + Dir["lib/*/version.rb"][0]

Gem::Specification.new do |s|
  s.name = "rackspace-queues"
  s.version = RackspaceQueues::VERSION
  s.authors = ["Andrew Regner"]
  s.email = ["andrew.regner@rackspace.com"]
  s.homepage = "https://github.com/adregner/rackspace-queues"
  s.summary = "Basic ruby interface into Rackspace Cloud Queues"
  s.description = File.read(Dir["README*"].first)
  s.license = "MIT"

  s.files = Dir["lib/**/*.rb", "LICENSE*", "README*"]

  s.add_dependency "excon", "~> 0.25.0"
end
