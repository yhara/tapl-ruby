#!rspec
require_relative 'tapl'

module Tapl
  describe Typer do
    describe "#unify" do
      before(:all) do
        @typer = Typer.new
        @unify = ->(constr) { @typer.unify(:fi, :msg, constr) }
      end

      it "empty constraints" do
        expect(@unify.([])).to eq([])
      end

      context "remove obvious constraints" do
        it "nat = nat" do
          expect(@unify.([[Type::TY_NAT, Type::TY_NAT]])).to eq([])
        end

        it "bool = bool" do
          expect(@unify.([[Type::TY_BOOL, Type::TY_BOOL]])).to eq([])
        end

        it "x = x" do
          expect(@unify.([[Type::TyId.new("x"), Type::TyId.new("x")]])).to eq([])
        end
      end

      it "compare two functions" do
        a = Type::TyId.new("a")
        b = Type::TyId.new("b")

        fun1 = Type::TyArr.new(a, b)
        fun2 = Type::TyArr.new(Type::TY_NAT, Type::TY_BOOL)

        expected = [[b, Type::TY_BOOL], [a, Type::TY_NAT]]
        expect(@unify.([[fun1, fun2]])).to eq(expected)
      end

      it "compare two functions2" do
        a = Type::TyId.new("a")
        b = Type::TyId.new("b")

        fun1 = Type::TyArr.new(a, b)
        fun2 = Type::TyArr.new(b, a)

        expect(@unify.([[fun1, fun2]])).to eq([[b, a]])
        #    ['a->'b == 'b->'a]
        # -> ['a=='b, 'b=='a]
        # -> ['a=='a]  + ['b=='a]
      end
    end
  end
end
