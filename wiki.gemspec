$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "wiki/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "wiki"
  s.version     = Wiki::VERSION
  s.authors     = ["Chris"]
  s.email       = ["chrisodlaug@gmail.com"]
  s.homepage    = "TODO"
  s.summary     = "TODO: Summary of Wiki."
  s.description = "TODO: Description of Wiki."
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails", "~> 4.2.2"
  s.add_dependency "gollum"

  # s.add_development_dependency "sqlite3"
end
