require 'pattern-match'
require_relative 'parser.rb'

=begin
Terms:
  [:Var, i, _]
  [:Abs, x, t1, t2]
  [:Abs, x, nil, t2]
  [:App, t1, t2]
  [:Let, x, t1, t2]
  [:Zero]
  [:Succ, t1]
  [:Pred, t1]
  [:IsZero, t1]
  [:True]
  [:False]
  [:If, t1, t2, t3]
=end

module Tapl
  class Evaluator
    class NoRuleApplies < StandardError; end

    def numeric_val?(t)
      match(t) {
        with(_[:Zero]) { true }
        with(_[:Succ, t1]) { numeric_val?(t1) }
        with(_){ false }
      }
    end

    def val?(t)
      match(t) {
        with(_[:True]) { true }
        with(_[:False]) { true }
        with(t, guard{ numeric_val?(t) }) { true }
        with(_) { false }
      }
    end

    def eval1(t)
      match(t) {
        with(_[:If, [:True], t2, t3]) {
          t2
        }
        with(_[:If, [:False], t2, t3]) {
          t3
        }
        with(_[:If, t1, t2, t3]) {
          [:If, eval1(t1), t2, t3]
        }
        with(_[:Succ, t1]) { 
          [:Succ, eval1(t1)]
        }
        with(_[:Pred, [:Zero]]) {
          [:Zero]
        }
        with(_[:Pred, _[:Succ, nv1]], guard{ numeric_val?(nv1)}) {
          nv1
        }
        with(_[:Pred, t1]) {
          [:Pred, eval1(t1)]
        }
        with(_[:IsZero, [:Zero]]) {
          [:True]
        }

        with(_[:IsZero, _[:Succ, nv1]], guard{ numeric_val?(nv1)}) {
          [:False]
        }
        
        with(_[:IsZero, t1]) {
          p [:IsZero3, t1: t1]
          [:IsZero, eval1(t1)]
        }
        with(_) {
          raise NoRuleApplies
        }
      }
    end

    def eval(t)
      eval(eval1(t))
    rescue NoRuleApplies
      t
    end
  end

  module Type
    class Base; end
    class TyId < Base
      def initialize(id)
        @id = id
      end
      attr_accessor :id
    end
    class TyArr < Base
      def initialize(t1, t2)
        @t1, @t2 = t1, t2
      end
      attr_accessor :t1, :t2
    end
    class TyBool < Base; end
    TY_BOOL = TyBool.new
    class TyNat < Base; end
    TY_NAT = TyNat.new
  end

  class Typer
    include Type

    def recon(ctx, nextuvar, t)
      match(t) {
        with(_[:Var, i, _])
        with(_[:Abs, x, t1, t2])
        with(_[:Abs, x, nil, t2])
        with(_[:App, t1, t2])
        with(_[:Let, x, t1, t2])
        with(_[:Zero])
        with(_[:Succ, t1])
        with(_[:Pred, t1])
        with(_[:IsZero, t1])
        with(_[:True])
        with(_[:False])
        with(_[:If, t1, t2, t3])
      }
    end

    def unify(fi, msg, constr)
      u = ->(constr) {
        first, *rest = *constr
        match(first) {
          with(nil) { [] }
          with(_[left, right & TyId]) {
            if left.is_a?(TyId) && left.id == right.id
              u.(rest)
            elsif occurs_in?(right.id, left)
              raise "#{msg}: circular constraints"
            else
              u.(substinconstr(right.id, left, rest)) + 
                [[TyId.new(right.id), left]]
            end
          }
          with(_[left & TyId, right]) {
            u.( [[right, left], *rest] )
          }
          with(_[TyNat, TyNat]) { u.(rest) }
          with(_[TyBool, TyBool]) { u.(rest) }
          with(_[a1 & TyArr, a2 & TyArr]) {
            u.( [[a1.t1, a2.t1], [a1.t2, a2.t2], *rest] )
          }
          with(_) {
            raise "Unsolvable constraints"
          }
        }
      }

      u.(constr)
    end

  end
end

if $0 == __FILE__
  p 1

  typer = Typer.new
  p typer.unify(:fi, :msg, [])
end
