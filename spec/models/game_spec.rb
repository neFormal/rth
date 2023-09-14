# -*- coding: utf-8 -*-
# game_spec.rb

require 'app/models/game'

describe Game, 'on creation' do
  it 'should dump and restore' do
    game = Game.from({users: {
                         'Andy' => {name:'Andy', money:100, hand:[], bet:0},
                         'Billy' => {name:'Billy', money:100, hand:[], bet:0},
                         'Charly' => {name:'Charly', money:100, hand:[], bet:0},
                         'Dexter' => {name:'Dexter', money:100, hand:[], bet:0}
                       },
                       options: {blinds: {small: 1, big: 2}, players: 5},
                       name: 'testgame',
                       owner: 'Andy',
                       stats: {dealer: nil, round: nil, state: nil}
    })
    dump = game.dump
    dump.should_not be_nil

    restored_game = Game.from dump
    restored_game.should_not be_nil

    restored_game.dump.should == dump
  end

  it 'should start game from params' do
    game = Game.from({users: {
                         'Andy' => {name:'Andy', money:100, hand:[], bet:0},
                         'Billy' => {name:'Billy', money:100, hand:[], bet:0},
                         'Charly' => {name:'Charly', money:100, hand:[], bet:0},
                         'Dexter' => {name:'Dexter', money:100, hand:[], bet:0}
                       },
                       options: {blinds: {small: 1, big: 2}, players: 5},
                       name: 'testgame',
                       owner: 'Andy',
                       stats: {dealer: nil, round: nil, state: nil}
    })
    lambda{game.start}.should_not raise_error

    game.dealer.should_not be_nil
    game.users.should_not be_nil
    game.players.should_not be_nil
    game.players.size.should == 4
    game.state.should == :preflop
    game.current_user.should_not be_nil
    game.board.should_not be_nil
    game.board.size.should == 5
    game.players.any?{|u| u.hand.size != 2}.should == false
    game.pots[0][0].should == game.options[:blinds][:small] + game.options[:blinds][:big]
    game.bet.should == game.options[:blinds][:big]
    game.round.should == 1
  end
end

describe Game, 'on turn' do
  before :each do
    @game = Game.from({users: {
                         'Andy' => {name:'Andy', money:100, hand:[], bet:0},
                         'Billy' => {name:'Billy', money:100, hand:[], bet:0},
                         'Charly' => {name:'Charly', money:100, hand:[], bet:0},
                         'Dexter' => {name:'Dexter', money:100, hand:[], bet:0}
                       },
                       options: {blinds: {small: 1, big: 2}, players: 5},
                       name: 'testgame',
                       owner: 'Andy',
                       stats: {dealer: nil, round: nil, state: nil}
    })
  end

  context 'while processing struggle bet' do
    it 'should process struggle bet'
  end

  context 'while making of ante' do
    it 'should make ante on :preflop state' do
      @game.options[:ante] = 1
      lambda{@game.start}.should_not raise_error
      @game.dealer.should_not be_nil
      @game.users.should_not be_nil
      @game.players.should_not be_nil
      @game.players.size.should == 4
      @game.state.should == :preflop
      @game.current_user.should_not be_nil
      @game.board.should_not be_nil
      @game.board.size.should == 5
      @game.players.any?{|u| u.hand.size != 2}.should == false
      @game.pots[0][0].should == @game.options[:blinds][:small] + @game.options[:blinds][:big] + (@game.options[:ante] * @game.players.size)
      @game.bet.should == @game.options[:blinds][:big] + @game.options[:ante]
      @game.round.should == 1
    end

    it 'should not make ante on not :preflop state' do
      @game.players = @game.users.clone
      @game.dealer = @game.players.first
      @game.round = 1
      @game.state = :flop
      pack = Game::CARDS.product(Game::SUITS).shuffle
      @game.players.each{|u| u.hand = pack.shift(2).map{|v,s| Card.new(v, s)}}
      @game.board = pack.pop(5).map{|v,s| Card.new(v, s)}
      @game.pots = [[@game.options[:blinds][:small] + @game.options[:blinds][:big], @game.options[:blinds][:big] ]]

      @game.turn
      @game.pots[0][0].should == @game.options[:blinds][:small] + @game.options[:blinds][:big]
    end
  end

  context 'while processing call' do
    before :each do
      @game.players = @game.users.clone
      @game.dealer = @game.players.first
      @game.round = 0
      @game.state = :preflop
      @game.turn
    end

    it 'should process call' do
      bet = @game.options[:blinds][:big]
      user = @game.current_user
      params = {user: user.name, action: :call, bet: bet}
      pot_before = @game.pots[0][0]
      user_bet_before = user.bet
      user_money_before = user.money
      @game.do_action(params)
      @game.pots[0][0].should == pot_before + bet
      user.bet.should == user_bet_before + bet
      user.money.should == user_money_before - bet
    end

    it 'should raise error on bad bet' do
      bet = 0
      user = @game.current_user
      params = {user: user.name, action: :call, bet: bet}
      lambda {@game.do_action(params)}.should raise_error
    end
  end

  context 'while processing check' do
    before :each do
      @game.players = @game.users.clone
      @game.dealer = @game.players.first
      @game.round = 1
      @game.state = :flop
      @game.current_user = @game.dealer
      @game.bet = 0
      pack = Game::CARDS.product(Game::SUITS).shuffle
      @game.players.each{|u| u.hand = pack.shift(2).map{|v,s| Card.new(v, s)}}
      @game.board = pack.pop(5).map{|v,s| Card.new(v, s)}
    end

    it 'should process check' do
      user = @game.current_user
      params = {user: user.name, action: :check}
      @game.do_action params
      user = @game.current_user
      params = {user: user.name, action: :check}
      lambda {@game.do_action params}.should_not raise_error
    end

    it 'should raise error on bad game bet' do
      user = @game.current_user
      @game.bet = 10
      params = {user: user.name, action: :check}
      lambda {@game.do_action params}.should raise_error
    end
  end

  context 'while processing raise' do
    before :each do
      @game.players = @game.users.clone
      @game.dealer = @game.players[0]
      @game.round = 1
      @game.state = :flop
      @game.current_user = @game.dealer
      @game.bet = 10
      @game.current_user.bet = 0
      @game.pots = [[20, 0]]
    end

    it 'should process raise' do
      bet = 5
      user = @game.current_user
      params = {user: user.name, action: :raise, bet: bet}
      bet_before = @game.bet
      pot_before = @game.pots[0][0]
      user_bet_before = @game.current_user.bet
      user_money_before = @game.current_user.money
      
      lambda {@game.do_action params}.should_not raise_error
      user.bet.should == user_bet_before + (bet_before - user_bet_before) + bet
      user.money.should == user_money_before - (bet_before - user_bet_before) - bet
      @game.pots[0][0].should == pot_before + (bet_before - user_bet_before) + bet
      @game.bet.should == bet_before + bet
    end

    it 'should raise error on bad bet' do
      params = {user: @game.current_user.name, action: :raise, bet: -1}
      lambda {@game.do_action params}.should raise_error
    end
  end

  context 'while processing bet' do
    before :each do
      @game.players = @game.users.clone
      @game.dealer = @game.players[0]
      @game.round = 1
      @game.state = :flop
      @game.current_user = @game.dealer
      @game.bet = 10
      @game.current_user.bet = 10
      @game.pots = [[20, 0]]
    end

    it 'should process bet' do
      bet = 5
      user = @game.current_user
      params = {user: user.name, action: :bet, bet: bet}
      bet_before = @game.bet
      pot_before = @game.pots[0][0]
      user_bet_before = @game.current_user.bet
      user_money_before = @game.current_user.money
      
      lambda {@game.do_action params}.should_not raise_error
      user.bet.should == user_bet_before + (bet_before - user_bet_before) + bet
      user.money.should == user_money_before - (bet_before - user_bet_before) - bet
      @game.pots[0][0].should == pot_before + (bet_before - user_bet_before) + bet
      @game.bet.should == bet_before + bet
    end

    it 'should raise error on invalid bet' do
      params = {user: @game.current_user.name, action: :bet, bet: -1}
      lambda {@game.do_action params}.should raise_error
    end

    it 'should raise error on bet less than big blind' do
      params = {user: @game.current_user.name, action: :bet, bet: 1}
      lambda {@game.do_action params}.should raise_error
    end
  end
  
  context 'while processing fold' do
    before :each do
      @game.players = @game.users.clone
      @game.dealer = @game.players[0]
      @game.round = 1
      @game.state = :flop
      @game.current_user = @game.dealer
      @game.bet = 0
      pack = Game::CARDS.product(Game::SUITS).shuffle
      @game.players.each{|u| u.hand = pack.shift(2).map{|v,s| Card.new(v, s)}}
      @game.players.each{|u| u.bet = 2}
      @game.board = pack.pop(5).map{|v,s| Card.new(v, s)}
    end

    it 'should process fold' do
      user = @game.current_user
      params = {user: user.name, action: :fold}
      @game.do_action params
      @game.players.include?(user).should == false
      user.bet.should == 0
    end
  end

  ################################################################
  context 'while changing state' do
    before :each do
      dict = {users: [1,2,3]}
      game = Game.from({users: {
                           'Andy' => {name:'Andy', money:100, hand:[], bet:0},
                           'Billy' => {name:'Billy', money:100, hand:[], bet:0},
                           'Charly' => {name:'Charly', money:100, hand:[], bet:0},
                           'Dexter' => {name:'Dexter', money:100, hand:[], bet:0}
                         },
                         options: {blinds: {small: 1, big: 2}, players: 5},
                         name: 'testgame',
                         owner: 'Andy',
                         stats: {dealer: nil, round: nil, state: nil}
                       })
      @game.players = @game.users.clone
      pack = Game::CARDS.product(Game::SUITS).shuffle
      @game.players.each{|u| u.hand = pack.shift(2).map{|v,s| Card.new(v, s)}}
      @game.players.each{|u| u.bet = 0}
      @game.board = pack.pop(5).map{|v,s| Card.new(v, s)}

      @game.bet = 0
      @game.round = 0
    end

#    it 'should change nil -> :flop' do
#      @game.dealer = @game.players[(rand*@game.players.size).to_i]
#      state_before = @game.state
#      @game.turn
#      @game.players.find{|p| p.money == 98}.should_not be_nil
#      @game.players.find{|p| p.money == 99}.should_not be_nil
#      @game.state.should == :preflop
#    end
    
    it 'should change :preflop -> :flop' do
      @game.dealer = @game.players[(rand*@game.players.size).to_i]
      @game.state = :preflop
      @game.current_user = @game.players.last
      state_before = @game.state
      params = {user: @game.current_user.name, action: :check}
      @game.do_action params
      @game.state.should == :flop
    end

    it 'should change :flop -> :turn' do
      @game.dealer = @game.players[(rand*@game.players.size).to_i]
      @game.state = :flop
      @game.current_user = @game.players.last
      state_before = @game.state
      params = {user: @game.current_user.name, action: :check}
      @game.do_action params
      @game.state.should == :turn
    end

    it 'should change :turn -> :river' do
      @game.dealer = @game.players[(rand*@game.players.size).to_i]
      @game.state = :turn
      @game.current_user = @game.players.last
      state_before = @game.state
      params = {user: @game.current_user.name, action: :check}
      @game.do_action params
      @game.state.should == :river
    end

    it 'should change :river -> :preflop' do
      @game.players[0].hand = [Card.new(Game::TWO,:spades),Card.new(Game::FOUR,:spades)]
      @game.players[1].hand = [Card.new(Game::TWO,:hearts),Card.new(Game::FOUR,:hearts)]
      @game.players[2].hand = [Card.new(Game::TWO,:diamonds),Card.new(Game::FOUR,:diamonds)]
      @game.players[3].hand = [Card.new(Game::TWO,:clubs),Card.new(Game::FOUR,:clubs)]

      @game.bet = 5
      @game.pots = [[@game.players.size * 5, 0]]
      @game.players.each{|u| u.bet = 5}

      @game.dealer = @game.players[0]
      next_dealer = @game.players[@game.players.index(@game.dealer) + 1]
      @game.state = :river
      @game.current_user = @game.players.last

      state_before = @game.state
      params = {user: @game.current_user.name, action: :check}
      @game.do_action params

      @game.state.should == :preflop
      @game.dealer.should == next_dealer
      @game.dealer.bet.should == 0
      @game.current_user.bet.should == 0
    end

    it 'should change :river -> :preflop and kick player' do
      @game.board = [
                     Card.new(Game::THREE, :spades),
                     Card.new(Game::QUEEN, :hearts),
                     Card.new(Game::SIX, :spades),
                     Card.new(Game::JACK, :diamonds),
                     Card.new(Game::THREE, :clubs)
                    ]
      @game.players[0].hand = [Card.new(Game::TWO,:spades),Card.new(Game::FOUR,:spades)]
      @game.players[1].hand = [Card.new(Game::ACE,:hearts),Card.new(Game::ACE,:hearts)]
      @game.players[2].hand = [Card.new(Game::TWO,:diamonds),Card.new(Game::FOUR,:diamonds)]
      @game.players[3].hand = [Card.new(Game::TWO,:clubs),Card.new(Game::FOUR,:clubs)]

      @game.pots = [[@game.players.size * 5, 0]]

      @game.dealer = @game.players[(rand*@game.players.size).to_i]
      @game.state = :river
      @game.current_user = @game.players.last
      state_before = @game.state
      players_before = @game.players.size
      # make all-in
      @game.current_user.money = 0
      params = {user: @game.current_user.name, action: :check}
      @game.do_action params

      @game.dealer.should_not be_nil
      @game.state.should == :preflop
      @game.players.size.should == players_before-1
    end

    it 'should change :river -> :gameover' do
      @game.board = [
                     Card.new(Game::THREE, :spades),
                     Card.new(Game::QUEEN, :hearts),
                     Card.new(Game::SIX, :spades),
                     Card.new(Game::JACK, :diamonds),
                     Card.new(Game::THREE, :clubs)
                    ]
      @game.players[0].hand = [Card.new(Game::ACE,:spades),Card.new(Game::ACE,:hearts)]
      @game.players[1].hand = [Card.new(Game::TWO,:hearts),Card.new(Game::FOUR,:hearts)]
      @game.players[2].hand = [Card.new(Game::TWO,:diamonds),Card.new(Game::FOUR,:diamonds)]
      @game.players[3].hand = [Card.new(Game::TWO,:clubs),Card.new(Game::FOUR,:clubs)]

      @game.pots = [[@game.players.size * 5, 0]]
      pot_before = @game.pots[0][0]

      @game.dealer = @game.players[(rand*@game.players.size).to_i]
      @game.state = :river
      @game.current_user = @game.players.last
      state_before = @game.state
      players_before = @game.players.size
      # make all-in
      money_before = @game.users[0].money = 0
      @game.users[1].money = 0
      @game.users[2].money = 0
      @game.users[3].money = 0
      params = {user: @game.current_user.name, action: :check}
      @game.do_action(params).should == :game_over

      @game.dealer.should_not be_nil
      @game.users.size.should == 1
      @game.users[0].money.should == money_before + pot_before
    end
  end


  context 'while giving the pot' do
    before :each do
      @game.players = @game.users.clone
      @game.dealer = @game.players.first
      @game.round = 0
      @game.state = :preflop
      @game.current_user = @game.dealer
      @game.bet = 10
      @game.current_user.bet = 0
      @game.pots = [[0, 0]]
      @game.options[:ante] = 1
      @game.options[:blinds] = {small: 1, big: 2}
    end

    it 'should give main pot and all side pots' do

      @game.board = [
                     Card.new(Game::THREE, :spades),
                     Card.new(Game::QUEEN, :hearts),
                     Card.new(Game::SIX, :spades),
                     Card.new(Game::JACK, :diamonds),
                     Card.new(Game::THREE, :clubs)
                    ]
      @game.players[0].hand = [Card.new(Game::ACE,:spades),Card.new(Game::ACE,:hearts)]
      @game.players[1].hand = [Card.new(Game::TWO,:hearts),Card.new(Game::FOUR,:hearts)]
      @game.players[2].hand = [Card.new(Game::TWO,:diamonds),Card.new(Game::FOUR,:diamonds)]
      @game.players[3].hand = [Card.new(Game::TWO,:clubs),Card.new(Game::FOUR,:clubs)]

      @game.pots = [[@game.players.size * 1, 1], [42, 0]]
      pot_before = @game.pots.map(&:first).reduce(&:+)

      @game.dealer = @game.players[(rand*@game.players.size).to_i]
      @game.state = :river
      @game.current_user = @game.players.last
      state_before = @game.state
      players_before = @game.players.size
      # make all-in
      money_before = 0
      @game.users[0].money, @game.users[0].bet = 0, 10
      @game.users[1].money, @game.users[1].bet = 0, 0
      @game.users[2].money, @game.users[2].bet = 0, 0
      @game.users[3].money, @game.users[3].bet = 0, 10
      params = {user: @game.current_user.name, action: :check}
      res = @game.do_action(params)
      res.should == :game_over

      @game.dealer.should_not be_nil
      @game.users.size.should == 1
      @game.users[0].money.should == money_before + pot_before
    end

    context 'while creating a new side-pot before deal' do

      it 'should create on ante' do
        #If a player is all in for part of the ante, or the exact amount of the ante, an equal amount of every other player's ante is placed in the main pot, with any remaining fraction of the ante and all blinds and further bets in the side pot
        player = @game.current_user
        player.money = 1
        @game.turn

        player.money.should == 0
        @game.pots.size.should == 2
        # antes
        @game.pots[0][0].should == @game.players.size * @game.options[:ante]
        @game.pots[0][1].should == 1
        # blinds
        @game.pots[1][0].should == @game.options[:blinds][:small] + @game.options[:blinds][:big]
        @game.pots[1][1].should == 0 # no all-in
        
        @game.bet.should == @game.options[:blinds][:big] + @game.options[:ante]
        # до окончания круга все ставят в main, а излишки в side
        # банки - есть суть стек банков.. для получения профита с верхнего банка надо иметь ставку до его ставки. т.е. у каждого банка должна быть своя верхняя ставка
        # нужная ставка определяется суммой ставок всех банков
        # в случае full bet rule или half bet rule ставка модифицируется без внесения суммы в банк, т.е. ставка ничем не подкреплена
      end

      it 'should create a new side-pot on blinds' do
        @game.options[:blinds] = {small: 2, big: 4}
        @game.options.delete :ante
        # necessary for current player all-in
        @game.round = 1
        @game.dealer = @game.players[1]
        @game.current_user = @game.players.first
        current_user = @game.current_user
        #

        current_user_money = 1
        current_user.money = current_user_money
        @game.turn

        current_user.money.should == 0
        @game.pots.size.should == 2
        # antes
        @game.pots[0][0].should == current_user_money + (@game.options[:blinds][:big] - current_user.bet) # coz current is sb-player
        @game.pots[0][1].should == current_user.bet
        # blinds
        @game.pots[1][0].should == @game.options[:blinds][:big] - current_user.bet
        @game.pots[1][1].should == 0 # no all-in
      end
    end
  end

end

describe Game, 'on check combo' do
  before(:all) do
  end
  it 'should find none' do
    cards = [
             Card.new(Game::TWO, :hearts),
             Card.new(Game::THREE, :hearts),
             Card.new(Game::FOUR, :spades),
             Card.new(Game::FIVE, :diamonds),
             Card.new(Game::JACK, :spades),
             Card.new(Game::QUEEN, :clubs),
             Card.new(Game::KING, :hearts)
            ]
    
    Game.check_combo(cards, Game::PAIR).should be_nil
    Game.check_combo(cards, Game::TWO_PAIRS).should be_nil
    Game.check_combo(cards, Game::SET).should be_nil
    Game.check_combo(cards, Game::STRAIGHT).should be_nil
    Game.check_combo(cards, Game::FLUSH).should be_nil
    Game.check_combo(cards, Game::FULL_HOUSE).should be_nil
    Game.check_combo(cards, Game::QUADS).should be_nil
    Game.check_combo(cards, Game::STRAIGHT_FLUSH).should be_nil
    Game.find_best_combo(cards)[0].should == Game::HIGHCARD
  end
  it 'should find highcard' do
    cards = [
             Card.new(Game::TWO, :hearts),
             Card.new(Game::THREE, :hearts),
             Card.new(Game::FOUR, :spades),
             Card.new(Game::FIVE, :diamonds),
             Card.new(Game::JACK, :spades),
             Card.new(Game::QUEEN, :clubs),
             Card.new(Game::KING, :hearts),
            ]
    Game.check_combo(cards, Game::HIGHCARD).should == [Card.new(Game::KING, :hearts)]
  end
  it 'should find pair' do
    cards = [
             Card.new(Game::TWO, :hearts),
             Card.new(Game::THREE, :hearts),
             Card.new(Game::FOUR, :spades),
             Card.new(Game::FIVE, :diamonds),
             Card.new(Game::JACK, :spades),
             Card.new(Game::KING, :clubs),
             Card.new(Game::KING, :hearts),
            ]
    Game.check_combo(cards, Game::PAIR).should == [Card.new(Game::KING, :clubs), Card.new(Game::KING, :hearts)]
  end
  it 'should find two pairs' do
    cards = [
             Card.new(Game::TWO, :hearts),
             Card.new(Game::THREE, :hearts),
             Card.new(Game::FOUR, :spades),
             Card.new(Game::FOUR, :diamonds),
             Card.new(Game::JACK, :spades),
             Card.new(Game::KING, :clubs),
             Card.new(Game::KING, :hearts),
            ]
    Game.check_combo(cards, Game::TWO_PAIRS).should == [Card.new(Game::FOUR, :spades), Card.new(Game::FOUR, :diamonds)] + [Card.new(Game::KING, :clubs), Card.new(Game::KING, :hearts)]
  end
  it 'should find set' do
    cards = [
             Card.new(Game::TWO, :hearts),
             Card.new(Game::FOUR, :hearts),
             Card.new(Game::FOUR, :spades),
             Card.new(Game::FOUR, :diamonds),
             Card.new(Game::JACK, :spades),
             Card.new(Game::KING, :clubs),
             Card.new(Game::KING, :hearts),
            ]
    Game.check_combo(cards, Game::SET).should == [Card.new(Game::FOUR, :hearts), Card.new(Game::FOUR, :spades), Card.new(Game::FOUR, :diamonds)]
  end
  it 'should find straight' do
    cards = [
             Card.new(Game::TWO, :hearts),
             Card.new(Game::THREE, :hearts),
             Card.new(Game::FOUR, :spades),
             Card.new(Game::FIVE, :diamonds),
             Card.new(Game::SIX, :spades),
             Card.new(Game::QUEEN, :clubs),
             Card.new(Game::KING, :hearts),
            ]
    Game.check_combo(cards, Game::STRAIGHT).should == [
             Card.new(Game::TWO, :hearts),
             Card.new(Game::THREE, :hearts),
             Card.new(Game::FOUR, :spades),
             Card.new(Game::FIVE, :diamonds),
             Card.new(Game::SIX, :spades)
            ]
  end
  it 'should find flush' do
    cards = [
             Card.new(Game::TWO, :hearts),
             Card.new(Game::THREE, :spades),
             Card.new(Game::FOUR, :spades),
             Card.new(Game::FIVE, :diamonds),
             Card.new(Game::JACK, :spades),
             Card.new(Game::QUEEN, :spades),
             Card.new(Game::KING, :spades),
            ]
    Game.check_combo(cards, Game::FLUSH).should == [Card.new(Game::THREE, :spades),
             Card.new(Game::FOUR, :spades),
             Card.new(Game::JACK, :spades),
             Card.new(Game::QUEEN, :spades),
             Card.new(Game::KING, :spades)]
  end
  it 'should find full house' do
    cards = [
             Card.new(Game::TWO, :hearts),
             Card.new(Game::THREE, :spades),
             Card.new(Game::THREE, :hearts),
             Card.new(Game::THREE, :diamonds),
             Card.new(Game::JACK, :spades),
             Card.new(Game::QUEEN, :spades),
             Card.new(Game::JACK, :hearts),
            ]
    Game.check_combo(cards, Game::FULL_HOUSE).should == [
             Card.new(Game::THREE, :spades),
             Card.new(Game::THREE, :hearts),
             Card.new(Game::THREE, :diamonds),
             Card.new(Game::JACK, :spades),
             Card.new(Game::JACK, :hearts)
            ]
  end
  it 'should find quads' do
    cards = [
             Card.new(Game::TWO, :hearts),
             Card.new(Game::THREE, :spades),
             Card.new(Game::THREE, :hearts),
             Card.new(Game::THREE, :diamonds),
             Card.new(Game::THREE, :clubs),
             Card.new(Game::QUEEN, :spades),
             Card.new(Game::JACK, :hearts)
            ]
    Game.check_combo(cards, Game::QUADS).should == [
             Card.new(Game::THREE, :spades),
             Card.new(Game::THREE, :hearts),
             Card.new(Game::THREE, :diamonds),
             Card.new(Game::THREE, :clubs)
            ]
  end
  it 'should find straight flush' do
    cards = [
             Card.new(Game::TWO, :clubs),
             Card.new(Game::THREE, :clubs),
             Card.new(Game::FOUR, :clubs),
             Card.new(Game::FIVE, :clubs),
             Card.new(Game::SIX, :clubs),
             Card.new(Game::QUEEN, :spades),
             Card.new(Game::JACK, :hearts)
            ]
    Game.check_combo(cards, Game::STRAIGHT_FLUSH).should == [
             Card.new(Game::TWO, :clubs),
             Card.new(Game::THREE, :clubs),
             Card.new(Game::FOUR, :clubs),
             Card.new(Game::FIVE, :clubs),
             Card.new(Game::SIX, :clubs)
            ]
  end

  it 'should check combos with ACE == 1' do
    cards = [
             Card.new(Game::TWO, :hearts),
             Card.new(Game::THREE, :hearts),
             Card.new(Game::FOUR, :spades),
             Card.new(Game::FIVE, :diamonds),
             Card.new(Game::SEVEN, :spades),
             Card.new(Game::QUEEN, :clubs),
             Card.new(Game::ACE, :spades),
            ]
    Game.check_combo(cards, Game::STRAIGHT).should == [
             Card.new(Game::LOW_ACE, :spades),
             Card.new(Game::TWO, :hearts),
             Card.new(Game::THREE, :hearts),
             Card.new(Game::FOUR, :spades),
             Card.new(Game::FIVE, :diamonds)
            ]
  end

  context 'while choose best combo from players hands'
end
