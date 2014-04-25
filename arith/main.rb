#!/usr/bin/env ruby
Dir.chdir(__dir__)
system "bundle exec racc -o parser.rb parser.y"
require './parser.rb'
require './arith.rb'


#p Arith::Evaluator.new.eval([:If, [:IsZero, [:Succ, [:Zero]]],
#                              [:Zero],
#                              [:Succ, [:Zero]]])
src = "if iszero 0 then 1 else 0"
puts <<EOD
Source:
--
#{src}
--

Ast:
--
#{ast = Arith::Parser.new.parse(src)}
--

Result:
--
#{Arith::Evaluator.new.eval(ast)}
--
EOD
