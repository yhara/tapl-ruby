#!/usr/bin/env ruby
Dir.chdir(__dir__)
system "bundle exec racc -o parser.rb parser.y"
require './tapl.rb'

src = <<EOD
if iszero 0 then 1 else 0
EOD

puts <<EOD
Source:
--
#{src}
--

Ast:
--
#{ast = Tapl::Parser.new.parse(src)}
--

Result:
--
#{Tapl::Evaluator.new.eval(ast)}
--
EOD
