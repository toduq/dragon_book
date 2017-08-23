# 正規表現から作られたStateTreeを読み込んで
# それをNFA及びDFAに変換するクラスです

class FiniteAutomaton
  attr_reader :nfa, :dfa
  attr_reader :states, :d_states

  def initialize(state_tree)
    raise 'Need StateTree' unless state_tree.is_a?(StateTree)
    @tree = state_tree.tree
    @states = {}
    prepare
    create_dfa
    prettify
  end

  def plot_nfa(filename='nfa.png')
    require "graphviz"
    g = GraphViz.new :G, rankdir: :LR
    nodes = @nfa.map do |state|
      g.add_nodes state[:name], shape: GRAPH_SHAPE[state[:type]]
    end
    @nfa.map.with_index do |state, from|
      state[:trans].each do |to|
        g.add_edges nodes[from], nodes[to]
      end
    end
    g.output png: filename
  end

  def plot_dfa(filename='dfa.png')
    require "graphviz"
    g = GraphViz.new :G, rankdir: :LR
    nodes = @dfa.map do |state|
      g.add_nodes state[:name], shape: GRAPH_SHAPE[state[:type]]
    end
    @dfa.map.with_index do |state, from|
      state[:trans].each do |char, to|
        g.add_edges nodes[from], nodes[to], label: char
      end
    end
    g.output png: filename
  end

  private

  GRAPH_SHAPE = {start: :box, mid: :oval, end: :diamond}.freeze

  def prepare
    collect_state(@tree, @states)
    nullable(@tree)
    firstpos(@tree)
    lastpos(@tree)
    @states.each {|_, state| state[:followpos] = [] }
    followpos(@tree)
    @states.each {|_, state| state[:followpos].sort!.uniq! }
  end

  def collect_state(tree, hash={})
    case tree[:type]
    when :char
      hash[tree[:pos]] = tree
    when :star
      collect_state(tree[:val], hash)
    when :or, :cat
      collect_state(tree[:left], hash)
      collect_state(tree[:right], hash)
    end
  end

  def nullable(tree)
    return tree[:nullable] if tree.key?(:nullable)
    tree[:nullable] = case tree[:type]
      when :char
        false
      when :star
        nullable(tree[:val])
        true
      when :or
        left = nullable(tree[:left])
        right = nullable(tree[:right])
        left || right
      when :cat
        left = nullable(tree[:left])
        right = nullable(tree[:right])
        left && right
    end
  end

  def firstpos(tree)
    return tree[:firstpos] if tree.key?(:firstpos)
    tree[:firstpos] = case tree[:type]
      when :char
        [tree[:pos]]
      when :star
        firstpos(tree[:val])
      when :or
        firstpos(tree[:left]) + firstpos(tree[:right])
      when :cat
        left = firstpos(tree[:left])
        right = firstpos(tree[:right])
        tree[:left][:nullable] ? left + right : left
    end
  end

  def lastpos(tree)
    return tree[:lastpos] if tree.key?(:lastpos)
    tree[:lastpos] = case tree[:type]
      when :char
        [tree[:pos]]
      when :star
        lastpos(tree[:val])
      when :or
        lastpos(tree[:left]) + lastpos(tree[:right])
      when :cat
        left = lastpos(tree[:left])
        right = lastpos(tree[:right])
        tree[:right][:nullable] ? left + right : right
    end
  end

  def followpos(tree)
    case tree[:type]
    when :or
      followpos(tree[:left])
      followpos(tree[:right])
    when :cat
      followpos(tree[:left])
      followpos(tree[:right])
      tree[:left][:lastpos].each do |pos|
        @states[pos][:followpos] += tree[:right][:lastpos]
      end
    when :star
      followpos(tree[:val])
      tree[:lastpos].each do |pos|
        @states[pos][:followpos] += tree[:firstpos]
      end
    end
  end

  def create_dfa
    @d_states = [{checked: false, states: @tree[:firstpos], trans: {}}]
    chars = @states.map{|_,s| s[:val] }.compact.sort.uniq
    loop do
      s = @d_states.find{|states| !states[:checked] }
      break unless s
      s[:checked] = true
      chars.each do |char|
        u = s[:states].map{|i| @states[i][:val] == char ? @states[i][:followpos] : [] }.flatten.sort.uniq
        next if u.empty?
        unless @d_states.find{|states| states[:states] == u }
          @d_states << {checked: false, states: u, trans: {}}
        end
        s[:trans][char] = u
      end
    end
  end

  def prettify
    done_state = @states.size - 1
    @nfa = @states.map do |i, state|
      {name: "#{i}:#{state[:val] || '#'}", trans: state[:followpos], type: i == done_state ? :end : :mid}
    end
    @dfa = @d_states.map.with_index do |state, i|
      name = state[:states].join(',')
      trans = state[:trans].map {|char, to| [char, @d_states.index{|s| s[:states] == to}]}.to_h
      type = state[:states].include?(done_state) ? :end : (i == 0 ? :start : :mid)
      {name: name, trans: trans, type: type}
    end
  end
end

if $PROGRAM_NAME == __FILE__
  require './state_tree'
  require 'pry'
  fa = FiniteAutomaton.new(StateTree.new('(a|b)*abb'))
  fa.plot_nfa
  fa.plot_dfa
  pp fa.dfa
end
