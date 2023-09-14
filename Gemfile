source :rubygems

gem 'cramp'

# Async webserver for running a cramp application
gem 'thin'

# Rack based routing
gem 'http_router'

# Collection of async-proof rack middlewares - https://github.com/rkh/async-rack.git
gem 'async-rack'

gem 'json'
#gem 'activesupport/json'
#gem 'activesupport'

# Redis support
#gem 'redis'
#gem "hiredis"
gem 'em-hiredis', :git => "git://github.com/mloughran/em-hiredis.git"
gem "redis", :require => ["redis/connection/hiredis", "redis"]

# For async Active Record models
# gem 'mysql2', '~> 0.2.11'
# gem 'activerecord', :require => 'active_record'

# Using Fibers + async callbacks to emulate synchronous programming
# gem 'em-synchrony'

# Generic interface to multiple Ruby template engines - https://github.com/rtomayko/tilt
# gem 'tilt'

group :development do
  # Development gems
  # gem 'ruby-debug19'
end

gem 'rspec-core'
gem 'rspec-cramp', :git => "https://github.com/bilus/rspec-cramp.git"
gem 'em-spec'
