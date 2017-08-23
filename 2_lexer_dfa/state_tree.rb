# 「連結、和、閉包」のみをサポートしたプリミティブな正規表現を与えると
# それを木構造に変換するクラスです

# === Regexp Syntax ===
# regexp -> or '#'
# or     -> cat ('|' cat)*
# cat    -> star+
# star   -> term '*'?
# term   -> '(' or ')'
#         | char

class StateTree
  attr_reader :tree

  def initialize(str)
    @str = str.to_s.split('')
    @lookahead = @str.shift
    # 再帰でパースする
    @tree = _or
    raise "Syntax error, rest #{@str}" unless @str.empty?
    # 終端記号#をつける
    @tree = {type: :cat, left: @tree, right: char}
  end

  private

  SPECIAL_CHARS = ['|', '*', '(', ')'].freeze

  def _or
    tree = _cat
    while @lookahead == '|'
      match('|')
      tree = { type: :or, left: tree, right: _cat }
    end
    tree.size == 2 ? tree[1] : tree
  end

  def _cat
    tree = _star
    until @lookahead.nil? || ['*', '|', ')'].include?(@lookahead)
      tree = { type: :cat, left: tree, right: _star }
    end
    tree
  end

  def _star
    tree = _term
    if @lookahead == '*'
      match('*')
      { type: :star, val: tree }
    else
      tree
    end
  end

  def _term
    if @lookahead == '('
      match('(')
      tree = _or
      match(')')
      tree
    else
      char
    end
  end

  def char
    raise "Syntax error, expected:char, found:'#{@lookahead}'" if SPECIAL_CHARS.include? @lookahead
    @pos = @pos ? @pos + 1 : 0
    { type: :char, pos: @pos, val: match(@lookahead) }
  end

  def match(str)
    raise "Syntax error, expected:'#{str}', found:'#{@lookahead}'" unless @lookahead == str
    tree = @lookahead
    @lookahead = @str.shift
    tree
  end
end

if $PROGRAM_NAME == __FILE__
  require 'pp'
  require 'test/unit'
  tree = StateTree.new('(a|b)*abb').tree
  pp tree
  include Test::Unit::Assertions
  assert_equal tree[:type], :cat
  assert_equal tree[:right][:type], :char
  assert_equal tree[:right][:val], nil
  assert_equal tree[:left][:left][:type], :cat
  assert_equal tree[:left][:left][:left][:type], :cat
  assert_equal tree[:left][:left][:left][:left][:type], :star
  assert_equal tree[:left][:left][:left][:right][:type], :char
  assert_equal tree[:left][:left][:left][:right][:val], 'a'
  assert_equal tree[:left][:left][:left][:left][:val][:type], :or
  assert_equal tree[:left][:left][:left][:left][:val][:left][:type], :char
  assert_equal tree[:left][:left][:left][:left][:val][:left][:val], 'a'
  assert_equal tree[:left][:left][:left][:left][:val][:right][:type], :char
  assert_equal tree[:left][:left][:left][:left][:val][:right][:val], 'b'
end
