# home_action_spec.rb

require 'application'
require 'rspec/cramp'
require 'em-spec/rspec'
require 'app/actions/home_action'

module ConnectionHelper
  def connect(url = nil, &blk)
    em do
      redis = EventMachine::Hiredis.connect(url)
      redis.flushall
      blk.call(redis)
    end
  end
end

describe HomeAction, :cramp => true do

  before :all do
    @redis = Redis.new
  end

  after :all do
    @redis = nil
  end

  before :each do
    @redis.del 'games'
  end

  def app
    HomeAction
  end

  it 'should generate proper game_id and store it' do
    lambda {
      get('/?action=create&user=johnny&game=passed').should respond_with :status => :ok
      data = @redis.hget :games, 'passed'
      data.should_not be_nil
      game = JSON.parse data, :symbolize_names => true
      game.should_not be_nil
    }.should_not raise_error
  end

  it 'should return index page' do
    lambda {
      get('/').should respond_with :status => :ok
    }.should_not raise_error
  end

  it 'should create a game with default params' do
    lambda {
      get('/?action=create&user=johnny&game=game_newgame').should respond_with :status => :ok

      game = JSON.parse @redis.hget(:games, 'game_newgame'), :symbolize_names => true
      game.should_not be_nil

      game[:users].should_not be_nil
      game[:users].keys.should include 'johnny'.to_sym

      game[:owner].should == 'johnny'

      game[:options].should_not be_nil
      game[:options][:blinds].should == {big: 2, small: 1}

      game[:stats].should_not be_nil
      game[:stats][:state].should be_nil
      game[:stats][:dealer].should be_nil
      game[:stats][:round].should be_nil
    }.should_not raise_error
  end

  it 'should create a game with stated params' do
    lambda {
      get('/?action=create&user=johnny&bblind=5&game=game_newgame').should respond_with :status => :ok

      game = JSON.parse @redis.hget(:games, 'game_newgame'), :symbolize_names => true
      game.should_not be_nil

      game[:users].should_not be_nil
      game[:users].keys.should include 'johnny'.to_sym

      game[:owner].should == 'johnny'

      game[:options].should_not be_nil
      game[:options][:blinds].should == {big: 5, small: 2}

      game[:stats].should_not be_nil
      game[:stats][:state].should be_nil
      game[:stats][:dealer].should be_nil
      game[:stats][:round].should be_nil
    }.should_not raise_error
  end

  it 'should join an already created game' do
    lambda {
      get('/?action=create&user=johnny&game=game_newgame').should respond_with :status => :ok
      get('/?action=join&user=billy&game=game_newgame').should respond_with :status => :ok

      game = JSON.parse @redis.hget(:games, 'game_newgame'), :symbolize_names => true
      game.should_not be_nil

      game[:users].should_not be_nil
      game[:users].keys.should include 'johnny'.to_sym
      game[:users].keys.should include 'billy'.to_sym
    }.should_not raise_error
  end
  
  it 'should send error on join with same username' do
    get('/?action=create&user=johnny&game=game_newgame').should respond_with :status => :ok
    get('/?action=join&user=johnny&game=game_newgame').should respond_with :status => :error
  end

  it 'should start game when all has been joined' do
    get('/?action=create&user=johnny&players=2&game=game_newgame').should respond_with :status => :ok
    get('/?action=join&user=billy&game=game_newgame').should respond_with :status => :ok
    
    game = JSON.parse @redis.hget(:games, 'game_newgame'), :symbolize_names => true
    game.should_not be_nil
    
    game[:users].should_not be_nil
    game[:users].keys.should include 'johnny'.to_sym
    game[:users].keys.should include 'billy'.to_sym
    
    game[:stats][:dealer].should_not be_nil
    game[:stats][:state].should == :preflop.to_s
    game[:stats][:round].should == 1
  end

  it 'should raise error on create another game with exist id' do
    get('/?action=create&user=johnny&players=2&game=game_newgame').should respond_with :status => :ok
    res = get('/?action=create&user=johnny&players=2&game=game_newgame')
    res.should respond_with :status => :error
  end

  it 'should returns game status' do
    pending 'I dont know is it really necessary'
  end

  it 'should make :call command' do
    create_request = get('/?action=create&user=johnny&players=2&game=game_newgame')
    create_request.should respond_with :status => :ok
    join_request = get('/?action=join&user=billy&game=game_newgame')
    join_request.should respond_with :status => :ok

    game = JSON.parse @redis.hget(:games, 'game_newgame'), :symbolize_names => true
    user = game[:stats][:current]
    cookie = game[:users][user.to_sym][:cookie]
    get("/?action=call&user=#{user}&game=game_newgame", :headers => {'Cookie' => cookie}).should respond_with :status => :ok
  end

  it 'should set cookie and validate it on next request' do
    create_request = get('/?action=create&user=johnny&players=2&game=game_newgame')
    create_request.should respond_with :status => :ok
    create_request.should respond_with :headers => {'Cookie' => /.*/}

    next_request = get('/?action=ping&user=johnny&players=2&game=game_newgame', :headers => {'Cookie' => create_request.headers['Cookie']})
    next_request.should respond_with :status => :ok
    next_request.should_not respond_with :headers => {'Cookie' => nil}
  end

  it 'should set cookie and raise error on bad cookie on next request' do
    create_request = get('/?action=create&user=johnny&players=2&game=game_newgame')
    create_request.should respond_with :status => :ok
    create_request.should respond_with :headers => {'Cookie' => /.*/}

    join_request = get('/?action=join&user=billy&game=game_newgame')
    join_request.should respond_with :status => :ok

    get('/?action=check&user=billy&game=game_newgame', :headers => {'Cookie' => ''}).should respond_with :status => 403
  end

  context 'while creating games' do
    it 'should create several games for different players' do
      create_request = get('/?action=create&user=johnny&players=2&game=game_newgame')
      create_request.should respond_with :status => :ok
      create_request.should respond_with :headers => {'Cookie' => /.*/}
      
      create_request = get('/?action=create&user=billy&players=2&game=game_newgame2')
      create_request.should respond_with :status => :ok
      create_request.should respond_with :headers => {'Cookie' => /.*/}
    end

    it 'should send error for same game name' do
      get('/?action=create&user=johnny&players=2&game=game_newgame').should respond_with :status => :ok
      get('/?action=create&user=billy&players=2&game=game_newgame').should respond_with :status => :error
    end

    it 'should get error with same username' do
      pending 'I dont know is it really necessary'
#      create_request = get('/?action=create&user=johnny&players=2&game=game_newgame')
#      create_request.should respond_with :status => :ok
#      create_request.should respond_with :headers => {'Cookie' => /.*/}
#      get('/?action=create&user=johnny&players=2&game=game_newgame2').should respond_with :status => :error
    end
  end
end
