# -*- coding: utf-8 -*-
#

User = Struct.new(:name, :money, :hand, :bet, :cookie)
Card = Struct.new(:value, :suit)

class Game

  HIGHCARD, PAIR, TWO_PAIRS, SET, STRAIGHT, FLUSH, FULL_HOUSE, QUADS, STRAIGHT_FLUSH = (1..9).to_a
  COMBOS = [STRAIGHT_FLUSH, QUADS, FULL_HOUSE, FLUSH, STRAIGHT, SET, TWO_PAIRS, PAIR, HIGHCARD]
  TWO, THREE, FOUR, FIVE, SIX, SEVEN, EIGHT, NINE, TEN, JACK, QUEEN, KING, ACE = (2..14).to_a
  CARDS = [TWO, THREE, FOUR, FIVE, SIX, SEVEN, EIGHT, NINE, TEN, JACK, QUEEN, KING, ACE]
  LOW_ACE = 1
  CARDS_NAMES = '23456789TJQKA'
  SUITS = [:hearts, :spades, :diamonds, :clubs]
  SB, BB, STRUGGLE = (1..3).to_a

  STATES = [:preflop, :flop, :turn, :river, :showdown]
  ACTIONS = [:check, :bet, :raise, :call, :fold]

  attr_accessor :state
  attr_accessor :options
  attr_accessor :users
  attr_accessor :players
  attr_accessor :board
  attr_accessor :dealer
  attr_accessor :current_user
  attr_accessor :pots
  attr_accessor :round
  attr_accessor :bet
  attr_accessor :response

#  begin
#  pots = [
#          {bet: 1, pot: 1},
#          {bet: 2, pot: 4}
#         ]
#  end

  def self.new_game_id
    name = "game_#{Time.new.to_i}_#{(rand*1000).to_i}"
  end

  def self.from data
    game = Game.new
    game.response = {all: []}
    game.options = data[:options]

#    p 'data', data
#    game.users = data[:users]
    game.users = data[:users].values.map{|u| User.new(u[:name],u[:money],u[:hand],u[:bet],u[:cookie])}
#    p 'game.users', game.users
#    game.dump

    unless data[:stats][:round].nil?
      game.board = data[:stats][:board]
      game.dealer = data[:stats][:dealer]
      game.current_user = game.users.find{|u| u.name == data[:stats][:current]}
      game.pots = data[:stats][:pots]
      game.round = data[:stats][:round]
      game.state = data[:stats][:state]
      game.bet = data[:stats][:bet]

      game.players = game.users.clone
      game.players.rotate! game.players.index(game.current_user)
    end

    game

  end

  def dump
    data = {
      options: @options,
      users: Hash[ @users.map{|u|
        [u.name, Hash[
                      [[:name,u.name],
                       [:money,u.money], [:hand,u.hand], [:bet,u.bet], [:cookie,u.cookie]]
                     ]]
      } ],
      stats: {
        dealer:(@dealer ? @dealer.name : nil),
        round: @round,
        state: @state,
        pots: @pots,
        bet: @bet,
        board: @board,
        current: (@current_user ? @current_user.name : nil),
      }
    }
#    p 'data', data
    data
  end

  def make_response user, data
    p 'make_response:', user, data
    @response[user] ||= []
    @response[user] << data
    p '@response:', @response
  end

  def start

    def valid? players
      true
    end

    raise 'Error: invalid players data' unless valid? @users

    @players = @users.clone # users that are not folded
    @dealer = @players[(rand*@players.size).to_i]
    @players.rotate!(@players.index @dealer)
    @round = 0
    @state = :preflop
    @options[:blinds] = {small: 1, big: 2} if @options[:blinds].nil?
#    @pots = [[0, 0]]
    turn
  end

  def turn
    
    raise 'Error: bad state' if @state.nil?
    case @state
    when :preflop
      return :game_over if update_players == :game_over
      @bet = 0
      @pots = [[0, 0]]

      #making ante
      if @options[:ante]
        @players.each{|p| with_user_bet(p, @options[:ante]){}}
        make_response :all, {event: :ante}
      end
      #end of making ante

      pack = CARDS.product(SUITS).shuffle
      @players.each do |u|
        player_hand = []
        u.hand = pack.shift(2).map{|v,s| Card.new(v, s); player_hand << [v, s]}
        make_response u.name, {event: :hand, value: player_hand}
      end

      @board = pack.pop(5).map{|v,s| Card.new(v, s)}
      
      raise 'Error: bad dealer' if @dealer.nil?
      @dealer = @players[1] if round != 0
      @players.rotate!(@players.index @dealer)
      @round += 1
      #blinds
      @current_user = @players[1]
      @players.rotate! 1
      [@options[:blinds][:small], @options[:blinds][:big]].each do |bet|
        with_user_bet(@current_user, bet) do
          @current_user = @players[1]
          @players.rotate! 1
        end
      end
    when :flop
      flop = @board.take 3
      make_response :all, {event: :flop, card: flop.map{|c|[c.value, c.suit]}}
    when :turn
      flop = @board.take 4
      make_response :all, {event: :turn, card: flop.map{|c|[c.value, c.suit]}}
    when :river
      flop = @board.take 5
      make_response :all, {event: :river, card: flop.map{|c|[c.value, c.suit]}}
    when :showdown

      @pot_users = {} #name=>pot
      
      def give_pot users, pot
        val = pot / users.size
        users.each do |u|
          u[0].money += val
          @pot_users[u[0].name] ||= 0
          @pot_users[u[0].name] += val
        end
      end
      
      @pots.each do |pot, bet_limit|
        us = @users.find_all{|u| u.bet >= bet_limit}.reduce([]) do |r, p|
          if r.empty?
            r << [p, Game.find_best_combo(p.hand + @board)]
          else
            a = r[0][1]
            b = Game.find_best_combo(p.hand + @board)
            
            if b[0] > a[0]
              r = [[p, b]]
            elsif a[0] == b[0]
              #find max card
              avs = a[1].map(&:value).sort
              bvs = b[1].map(&:value).sort
              case (avs <=> bvs)
              when 0..1
                r << [p, b]
              else
                r = [[p, b]]
              end
            end
            r
          end
        end
        
        give_pot us, pot
      end

      @pot_users.each{|username, pot| make_response :all, {event: :pot, user: username, pot: pot}}
      
      next_state
      
    else
      raise 'Bad game state'
    end
  end
  
  def update_players
    #for kicking
    return unless @state == :preflop
    @users.rotate!(@users.index(@dealer)).delete_if{|u|u.money <= 0}
    raise 'No users with money' if @users.empty?
    return :game_over if @users.size < 2

    @users.each do |u|
      u.bet = 0
      u.hand = []
    end
    @dealer = (@users[0] == @dealer) ? @users[1] : @users[0]
    @players = @users.rotate(@users.index(@dealer))
    @state
  end

  def with_user_bet user, bet, add_bet=true

    @pots.each_with_index do |x, i|

      pot, bet_limit = x
      # следующий банк, если игрок всего поставил >= лимита текущего банка
      # потому, что в текущий банк(если он с лимитом) мы уже вложили достаточно денег
      next if bet_limit != 0 and user.bet >= bet_limit
      # если денег меньше, чем надо, то all-in и новый банк
      if user.money <= bet
        if user.money > 0
          #user.bet += user.money if add_bet
          user.bet += bet if add_bet
          @pots[i] = [pot + user.money, bet]
          @pots << [0, 0] if i+1 >= @pots.size
          user.money = 0
        end
        break
      else
        # если банк без лимита, то просто добавить ставку и выйти
        if bet_limit <= 0
          pot += bet
          user.bet += bet
          user.money -= bet
          @pots[i] = [pot, bet_limit]
          bet = 0
          break
          # если банк с лимитом, то ставка должна быть больше лимита, т.к. был all-in
          # если ставка покрывает лимит, то остаток ставки передаётся в следующий банк
        elsif bet > bet_limit
          # добавляем в банк и юзерскую ставку лимит и уменьшаем общую сумму ставки
          pot += bet_limit
          user.bet += bet_limit
          bet -= bet_limit
          user.money -= bet_limit
          @pots[i] = [pot, bet_limit]
        else
          raise "Invalid case"
        end
      end
    end
    # меняет общую ставку
    @bet += (user.bet + bet) - @bet if add_bet
    
    yield
  end

  def do_action params
# already checked:    raise 'Bad action' unless available_actions.include? params[:action]
    user = @players.find{|u| u.name == params[:user]}
    next_user = @players.rotate(@players.index(@current_user))[1]

    raise 'Error: user != current_user' if @current_user != user
    raise 'Error: bad bet' if !params[:bet].nil? and (params[:bet].to_i <= 0 or params[:bet].to_i < @options[:blinds][:big])

    case params[:action].to_sym
      when :struggle
        raise 'Not supported'
        params[:type]#:small, :big, :struggle
        raise 'Error: Bad action. U cant struggle' if players.index user != STRUGGLE
        with_user_bet(user, stats[:blinds][:big]*2){}
      when :check
        raise "Error: Bad action. Should be 'call|raise'" if(@bet - user.bet) != 0
      when :bet
        raise 'Error: Bad action. Should be "call|raise"' if(@bet - user.bet) != 0
        with_user_bet(user, params[:bet].to_i) do
#          @bet = @bet + params[:bet].to_i
        end
      when :raise
        raise 'Error: Bad action. Should be "check|bet"' if(@bet - user.bet) == 0
        with_user_bet(user, (@bet - user.bet) + params[:bet].to_i) do
#          @bet = @bet + params[:bet]
        end
      when :call
        raise 'Error: Bad action. Should be "check"' if(@bet - user.bet) == 0
        with_user_bet(user, params[:bet].to_i - user.bet){}
      when :fold
        players.delete user
        user.bet = 0
      else
        raise 'Bad action'
    end
    # change current user
    @current_user = next_user

    make_response :all, {event: params[:action], user: params[:user]}

    # change current state
    next_state
  end

  def next_state
    # bet already has been changed
#    checked = @players.all?{|p| p.money == 0 || p.bet == @bet}
    return unless @players.all?{|p| p.money == 0 || p.bet == @bet}

    return unless @current_user == players[0]
    @state = STATES.rotate(STATES.index(@state))[1]

    make_response :all, {event: :change_state, state: @state}

    turn
  end
  private :next_state

  def self.can_user_do_action game, user, action
    case action
      when :check
      when :bet
        game.stats[:bet] - user.bet == 0
      when :raise
      when :call
        game.stats[:bet] - user.bet != 0
      when :fold
        true
#      else
#        false
#        case game.users.index user
#          when SB: [:small_blind]
#          when BB: [:big_blind]
#          when STRUGGLE: [:call, :struggle]
#          else
#            [:call]
#        end
    end
    false
  end

  def self.available_actions game, player
    case game[:last_action]
      when :check; [:check, :bet, :fold]
      when :bet
      when :raise
      when :call; [:call, :raise, :fold]
      when :fold; raise 'Action fold should not be in :last_action'
      else
        case game.players.index player
          when SB; [:small_blind]
          when BB; [:big_blind]
          when STRUGGLE; [:call, :struggle]
          else
            [:call]
        end
    end
  end

  def self.find_best_combo cards
#    [foo3, foo2, foo1].reduce(cards){}
#    [STRAIGHT_FLUSH, QUADS, FULL_HOUSE, FLUSH, STRAIGHT, SET, TWO_PAIRS, PAIR, HIGHCARD].reduce(cards){}
    best_cards = nil
    best_combo = COMBOS.find do |combo|
      res = self.check_combo(cards, combo)
      best_cards = res unless res.nil?
      not res.nil?
    end
    [best_combo, best_cards]
  end

  def self.check_combo cards, combo
    #in most cases is enough to check n-m(m \in [1;3]) cards
    case combo
    when HIGHCARD
      [cards.max{|a,b| a.value <=> b.value}]
    when PAIR
      m = cards.map(&:value).reduce(nil){|r, x| r = x if cards.count{|c|c.value==x} == 2 && (r.nil? || x > r);r}
      cards.find_all{|c| c.value == m} unless m.nil?
    when TWO_PAIRS
      m = cards.map(&:value).uniq.reduce([nil,nil]){|r,x| r = (r << x).sort{|x,y|(x||0)<=>(y||0)}[-2,2] if cards.count{|c|c.value==x} == 2; r}
      cards.find_all{|x|x.value==m[0]} + cards.find_all{|x|x.value==m[1]} unless m.nil? || m.size < 2 || m.any?(&:nil?)
    when SET
      m = cards.map(&:value).reduce(nil){|r, x| r = x if cards.count{|c|c.value==x} == 3 && (r.nil? || x > r); r}
      cards.find_all{|c| c.value == m} unless m.nil?
    when STRAIGHT
      m = cards.map(&:value).uniq.sort.reduce([]){|r, x| break r if r.size >= 5; if(r.empty? || (r.last-x != -1)); [x] else (r << x) end }
      res = m.map{|rc| cards.find{|c| c.value == rc}} unless m.nil? || m.size < 5
      # additional check for low ace combos
      if res.nil? and cards.any?{|c| c.value == ACE}
        lace = Card.new(LOW_ACE, :spades)
        # TODO: refactor to non-recursion
        res = self.check_combo(cards.map{|c|c.value==ACE ? lace : c}, combo)
      else
        res
      end
    when FLUSH
      m = SUITS.find{|s| cards.count{|c| c.suit == s} >= 5}
      cards.find_all{|x|x.suit==m} unless m.nil?
    when FULL_HOUSE
      set = cards.map(&:value).reduce(nil){|r, x| r = x if cards.count{|c|c.value==x} == 3 && (r.nil? || x > r); r}
      pair = cards.map(&:value).reduce(nil){|r, x| r = x if cards.count{|c|c.value==x} == 2 && (r.nil? || x > r);r}
      [cards.find_all{|x|x.value==set}, cards.find_all{|x|x.value==pair}].flatten unless set.nil? || pair.nil?
    when QUADS
      m = cards.map(&:value).reduce(nil){|r, x| r = x if cards.count{|c|c.value==x} == 4 && (r.nil? || x > r); r}
      cards.find_all{|c| c.value == m} unless m.nil?
    when STRAIGHT_FLUSH
      m = cards.map(&:value).uniq.sort.reduce([]){|r, x| break r if r.size >= 5; if(r.empty? || (r.last-x != -1)); [x] else (r << x) end }
      m.map!{|rc| cards.find_all{|c| c.value == rc}}.flatten!
      m if !m.empty? && m.map(&:suit).count(m[0].suit) >= 5
    else
      nil
    end
  end

end
