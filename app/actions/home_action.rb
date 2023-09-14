#
require 'digest/sha1'

class HomeAction < Cramp::Action
  use_fiber_pool
#  self.transport = :sse

  before_start :redis_on
  before_start :check_auth
#  on_start :start
#  on_start :redis_on
  on_start :start
#  on_start :redis_on, :check_auth#, :check_action
  on_finish :redis_off

#  @@users = Set.new
#  @@redis = Redis.new
  @@callbacks = {} # {'game': {'user1': cb}}

  def self.on_connect game, name, cb
    p 'self.on_connect:', game, name
    @@callbacks[game] ||= {}
    self.on_disconnect game, name if @@callbacks[game].key? name
    @@callbacks[game][name] = cb
    p 'connect @@callbacks', @@callbacks
    cb.call 'on_connect'.to_json
  end

  def self.on_disconnect game, name
    p 'disconnect @@callbacks', @@callbacks
    @@callbacks[game][name].call 'on_disconnect'.to_json
    @@callbacks[game].delete name if @@callbacks.key? game
  end

  def self.send game, name, data
    return unless @@callbacks.key? game
    if name == :all
      @@callbacks[game].each{|_, cb| cb.call data.to_json}
    elsif @@callbacks[game].key? name
      @@callbacks[game][name].call data.to_json
    end
    p 'data.to_json:', game, name, data.to_json
  end


  DEFAULT_MONEY = 100
  DEFAULT_BIG_BLIND = 2
  DEFAULT_PLAYERS_LIMIT = 2

  def redis_on
    @redis = Redis.new
#    p 'redis on'
    yield
  end

  def redis_off
#    p 'redis_off'
  end

  def check_auth
    if (params.include?(:action) and not ['create', 'ping', 'join'].include? params[:action])
      return halt 404, {}, 'Game not found' unless  @redis.hexists(:games, params[:game])

      game = JSON.parse @redis.hget(:games, params[:game]), :symbolize_names => true
      return halt 404, {}, 'User not found' if game[:users][params[:user].to_sym].nil?
      return halt 403, {}, 'Authorization failed' if game[:users][params[:user].to_sym][:cookie].nil?
      return halt 403, {}, 'Authorization failed' if game[:users][params[:user].to_sym][:cookie] != request.cookies.keys[0]
    end
    yield
  end

  def respond_with
    if ['create', 'join'].include? params[:action]
      [200, {'Content-Type' => 'text/html', 'Cookie' => gen_cookie(params[:game],params[:user])}]
    else
      [200, {'Content-Type' => 'text/html'}]
    end
  end

  def start
#    redis_on
    do_action if params.include? :action

    page = ERB.new(File.read(Rth::Application.root('app/views/index.erb')))
    render page.result(binding)
    finish
  end

  def with_check_action params
    return halt(500, {'Content-Type' => 'text/plain'}, 'Bad command') unless (params[:action] && Game.available_actions(@game, @user).include?(params[:action]))
    yield
  end

  def gen_cookie game, username
    Digest::SHA1.hexdigest "#{game}#{username}#{Time.new.to_i}"
  end
#  private :gen_cookie

  def do_action
    return halt 400, {}, 'No action' unless params[:action]

    game = nil

    game_name = params[:game]
    username = params[:user]
    case params[:action]
    when 'create'
      
      game_name ||= Game.new_game_id
      halt 500, {}, 'Error: game_id duplicate' unless @redis.hget(:games, game_name).nil?
      
      @@callbacks[game_name] = {}
      
      big_blind = params[:bblind].to_i unless params[:bblind].nil?
      big_blind ||= DEFAULT_BIG_BLIND
      blinds = {big: big_blind, small: big_blind/2}
      
      players = params[:players].to_i unless params[:players].nil?
      players ||= DEFAULT_PLAYERS_LIMIT
      
      game_data = {
        name: game_name,
        users: {username => {
            name: username,
            money: DEFAULT_MONEY,
            hand: [],
            bet: 0,
            cookie: gen_cookie(game_name, username)
          }},
        owner: username,
        options: {blinds: blinds, players: players},
        stats: {dealer: nil, round: nil, state: nil}
      }
      @redis.hset :games, game_name, game_data.to_json

    when 'join'
      return unless @redis.hget :games, game_name
      
      game_data = JSON.parse @redis.hget(:games, game_name), :symbolize_names => true
      return halt(409, {}, 'Name conflict') if game_data[:users].include? username.to_sym
      game_data[:users][username] = {
        name: username,
        money: DEFAULT_MONEY,
        hand: [],
        bet: 0,
        cookie: self.gen_cookie(game_name, username)
      }
      @redis.hset :games, game_name, game_data.to_json

      p 'join @@callbacks', @@callbacks
      p ({'event'=>'join', 'user'=>username}.to_json)
      @@callbacks[game_name].each{|_,v| v.call({'event'=>'join','user'=>username}.to_json)}
      
      if game_data[:users].size == game_data[:options][:players]
        game = Game.from(game_data)
        game.start
        @redis.hset :games, game_name, game.dump.to_json
        @@callbacks[game_name].each{|_,v| v.call("game started".to_json)}
      end

    when 'ping'
      'pong'
    else #game actions
      return unless @redis.hget :games, game_name
      game_data = JSON.parse @redis.hget(:games, game_name), :symbolize_names => true
      game = Game.from(game_data)
      begin
        game.do_action params
      rescue Exception => e
        p e, e.message
        halt 500, {}, e.message
      end
    end

    if game
      game.response.each do |username, data|
        data.each{|d| HomeAction.send game_name, username, d}
      end
    end

  end
  private :do_action
  
end

################################
class StreamAction < Cramp::Action
  use_fiber_pool
  self.transport = :sse

  on_start :stream
#  periodic_timer :stream, :every => 8

#  def start
#    stream
#  end

  def stream
#    render ({isbot: true, message: 'ororo', name: 'harry'}.to_json)
    on_connect
#    render 'stream connected'.to_json
  end

  @@users = Set.new
  attr_accessor :game
  attr_accessor :user
  attr_accessor :callback
  def on_connect
    @@users << self
    game = params[:game]
    user = params[:user]
    callback = lambda{|data| p "call #{user}"; self.render data}
    HomeAction.on_connect game, user, callback
# @@users.each{|u|u.render data}}
  end

  def on_disconnect
    @@users.delete self
    HomeAction.on_disconnect game, name
  end

  def self.send data
    @@users.each{|u| u.render data}
  end

end
