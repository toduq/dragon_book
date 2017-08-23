class Parser
  def initialize(str)
    @str = str
    @lookahead = @str.shift
    expr
    raise 'syntax error' unless @str.empty?
  end

  def expr
    term
    loop do
      if @lookahead == '+'
        match('+')
        term
        print '+'
      elsif @lookahead == '-'
        match('-')
        term
        print '-'
      else
        return
      end
    end
  end

  def term
    raise 'syntax error' unless @lookahead =~ /\A[0-9]\z/
    print @lookahead
    match(@lookahead)
  end

  def match(str)
    raise 'syntax error' unless @lookahead == str
    @lookahead = @str.shift
  end
end

Parser.new(STDIN.read.split(''))
puts ''
