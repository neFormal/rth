#require 'json'
#require 'active_support/json'

require './application'
Rth::Application.initialize!

# Development middlewares
if Rth::Application.env == 'development'
  use AsyncRack::CommonLogger

  # Enable code reloading on every request
  use Rack::Reloader, 0

  # Serve assets from /public
  #use Rack::Static, :urls => ["/javascripts"], :root => Rth::Application.root(:public)
  use Rack::Static, :urls => ["/javascripts", "/stylesheets"], :root => Rth::Application.root(:public)
end

# Running thin :
#
#   bundle exec thin --max-persistent-conns 1024 --timeout 0 -R config.ru start
#
# Vebose mode :
#
#   Very useful when you want to view all the data being sent/received by thin
#
#   bundle exec thin --max-persistent-conns 1024 --timeout 0 -V -R config.ru start
#
run Rth::Application.routes
