# Check out https://github.com/joshbuddy/http_router for more information on HttpRouter
HttpRouter.new do
  add('/').to(HomeAction)
  add('/stream').to(StreamAction)
#  add('/game.php').to(GameAction)
end
