class Tapl::Parser
  options no_result_var
rule
  toplevel : Term { val[0] }

  Term :
    AppTerm
      { val[0] }
    | IF Term THEN Term ELSE Term
      { [:If, val[1], val[3], val[5]] }

  AppTerm :
      ATerm
        { val[0] }
    | SUCC ATerm
        { [:Succ, val[1]] }
    | PRED ATerm
        { [:Pred, val[1]] }
    | ISZERO ATerm
        { [:IsZero, val[1]] }

  /* Atomic terms are ones that never require extra parentheses */
  ATerm :
      LPAREN Term RPAREN  
        { val[1] } 
    | TRUE
        { [:True] }
    | FALSE
        { [:False] }
    | INTV
        { (0...val[0]).inject([:Zero]){|sum, item|
            [:Succ, sum]
          } }

#  hash    : '{' contents '}'   { val[1] }
#          | '{' '}'            { Hash.new }
#           
#  # Racc can handle string over 2 bytes.
#  contents: IDENT '=>' IDENT              { {val[0] => val[2]} }
#          | contents ',' IDENT '=>' IDENT { val[0][val[2]] = val[4]; val[0] }
end

---- header

require 'strscan'

---- inner

  def parse(str)
    @s = StringScanner.new(str)
    yyparse self, :scan
  end

  private

  KEYWORDS = %w(if then else true false succ pred iszero)
  KEYWORDS_REXP = Regexp.new(KEYWORDS.join("|"))
  SYMBOLS = {
    "_"   => "USCORE",
    "'"   => "APOSTROPHE",
    "\""  => "DQUOTE",
    "!"   => "BANG",
    "#"   => "HASH",
    "$"   => "TRIANGLE",
    "*"   => "STAR",
    "|"   => "VBAR",
    "."   => "DOT",
    ";"   => "SEMI",
    ","   => "COMMA",
    "/"   => "SLASH",
    ":"   => "COLON",
    "::"  => "COLONCOLON",
    "="   => "EQ",
    "=="  => "EQEQ",
    "["   => "LSQUARE",
    "<"   => "LT",
    "{"   => "LCURLY",
    "("   => "LPAREN",
    "<-"  => "LEFTARROW",
    "{|"  => "LCURLYBAR",
    "[|"  => "LSQUAREBAR",
    "}"   => "RCURLY",
    ")"   => "RPAREN",
    "]"   => "RSQUARE",
    ">"   => "GT",
    "|}"  => "BARRCURLY",
    "|>"  => "BARGT",
    "|]"  => "BARRSQUARE",
    ":="  => "COLONEQ",
    "=>"  => "ARROW",
    "=>"  => "DARROW",
    "==>" => "DDARROW",
  }
  SYMBOLS_REXP = Regexp.new(SYMBOLS.map{|k, v| Regexp.quote(k)}.join("|"))

  def scan
    until @s.eos?
      case
      when (s = @s.scan(KEYWORDS_REXP))
        yield [s.upcase.to_sym, s.upcase.to_sym]
      when (s = @s.scan(SYMBOLS_REXP))
        name = SYMBOLS[s]
        yield [name.to_sym, name.to_sym]
      when (s = @s.scan(/\d+/))
        n = s.to_i
        yield [:INTV, n]
      when @s.scan(/\s+/)
        # skip
      else
        p "@s" => @s
        raise "Syntax Error"
      end
    end
    yield [false, '$']   # is optional from Racc 1.3.7
  end
