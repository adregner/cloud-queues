require "./" + Dir["lib/*/version.rb"][0]

Gem::Specification.new do |s|
  s.name = "cloud-queues"
  s.version = CloudQueues::VERSION
  s.authors = ["Andrew Regner"]
  s.email = ["andrew.regner@rackspace.com"]
  s.homepage = "https://github.com/adregner/cloud-queues"
  s.summary = "Basic (unoffical) ruby interface into Rackspace Cloud Queues"
  s.description = File.read(Dir["README*"].first)
  s.license = "MIT"

  s.files = Dir["lib/**/*.rb", "LICENSE*", "README*"]

  s.add_dependency "excon", "~> 0.25.0"
  s.add_development_dependency "rspec"
end
