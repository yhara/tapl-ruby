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
    end
  end
end
