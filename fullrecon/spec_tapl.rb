#!rspec
require_relative 'tapl'

module Tapl
  describe Typer do
    describe "#recon" do
      before do
        @typer = Typer.new
        @recon = ->(t) { @typer.recon(Context.new, t) }
      end

      it "const" do
        expect(@recon.([:Zero])).to eq([Type::TY_NAT, []])
        expect(@recon.([:True])).to eq([Type::TY_BOOL, []])
        expect(@recon.([:False])).to eq([Type::TY_BOOL, []])
      end

      it "builtin" do
        expect(@recon.([:Succ, [:Zero]])).to eq(
          [Type::TY_NAT, [Type::TY_NAT, Type::TY_NAT]]
        )
        expect(@recon.([:Pred, [:Zero]])).to eq(
          [Type::TY_NAT, [Type::TY_NAT, Type::TY_NAT]]
        )
        expect(@recon.([:IsZero, [:Zero]])).to eq(
          [Type::TY_NAT, [Type::TY_NAT, Type::TY_NAT]]
        )
      end

      it "if" do
        term = [:If, [:True], [:Zero], [:False]]
        expect(@recon.(term)).to eq(
          [Type::TY_BOOL, [
            [Type::TY_BOOL, Type::TY_BOOL],
            [Type::TY_NAT, Type::TY_BOOL] # Thus this program is wrong! :-)
          ]]
        )
      end

      context "function abstraction" do
        it "without type annotation" do
          term = [:Abs, "x", nil, [:Zero]]
          expect(@recon.(term)).to eq(
            [Type::TyArr.new(Type::TyId.new("?1"), Type::TY_NAT),
             []]
          )
        end

        it "with type annotation" do
          # Bool -> Nat
          term = [:Abs, "x", Type::TY_BOOL, [:Zero]]
          expect(@recon.(term)).to eq(
            [Type::TyArr.new(Type::TY_BOOL, Type::TY_NAT),
             []]
          )
        end
      end

      it "variable reference" do
        # Bool -> Bool
        term = [:Abs, "x", Type::TY_BOOL, [:Var, 0, 99]]
        expect(@recon.(term)).to eq(
          [Type::TyArr.new(Type::TY_BOOL, Type::TY_BOOL),
           []]
        )
      end

      it "function application" do
        term = [:App,
          [:Abs, "x", Type::TY_BOOL, [:Var, 0, 99]], # Bool -> Bool
          [:Zero]                                # invalid argument (Nat)
        ]
        expect(@recon.(term)).to eq(
          [Type::TyId.new("?1"), [
            [Type::TyArr.new(Type::TY_BOOL, Type::TY_BOOL),
             Type::TyArr.new(Type::TY_NAT, Type::TyId.new("?1"))]
          ]]
        )
      end

      context "let" do
        it "let with constant" do
          term = [:Let, "n", [:Zero], [:True]]
          expect(@recon.(term)).to eq(
            [Type::TY_BOOL, []]
          )
        end

        it "let with abs" do
          term = [:Let, "f",
            [:Abs, "x", nil, [:Var, 0, 99]],
            [:Var, 0, 99]]
          expect(@recon.(term)).to eq(
            [Type::TyArr.new(Type::TyId.new("?1"), Type::TyId.new("?1")),
              []]
          )
        end

        #it "temp1" do
        #  # fn(x){ let f = fn(y){ true ? y : x+1 } in 0 }
        #  term = [:Abs, "x", nil,
        #    [:Let, "f",
        #      [:Abs, "y", nil, 
        #        [:If, [:True], [:Var, 1, 99], [:Succ, [:Var, 0, 99]]]],
        #      [:Zero]]]
        #      #[:Var, 0, 99]]]
        #  expect(@recon.(term)).to eq(
        #    nil
        #  )
        #end

        #it "temp2" do
        #  # let id = fn(y){ y } in 0 
        #  term = [:Let, "id",
        #    [:Abs, "x", nil, [:Var, 0, 99]],
        #    [:If, [:True], 
        #      [:App, [:Var, 0, 99], [:False]],
        #      [:App, [:Var, 0, 99], [:Zero]]]]
        #  ty, constr = *@recon.(term)
        #  p ty: ty, constr: constr
        #  expect(@typer.unify(:fi, :msg, constr)).to eq(
        #    nil
        #  )
        #end
      end
    end

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
