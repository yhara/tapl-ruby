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
      def ==(other)
        other.is_a?(TyId) && other.id == self.id
      end
      attr_accessor :id
    end
    class TyArr < Base
      def initialize(t1, t2)
        @t1, @t2 = t1, t2
      end
      def ==(other)
        other.is_a?(TyArr) && other.t1 == self.t1 && other.t2 == self.t2
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

    # Return [type, constr]
    def recon(ctx, t)
      match(t) {
        with(_[:Var, i, _])
        with(_[:Abs, x, t1, t2])
        with(_[:Abs, x, nil, t2])
        with(_[:App, t1, t2])
        with(_[:Let, x, t1, t2])
        with(_[:Zero]) {
          [TY_NAT, []]
        }
        with(_[:Succ, t1]) {
          ty1, constr1 = recon(ctx, t1) 
          [TY_NAT, [ty1, TY_NAT]+constr1]
        }
        with(_[:Pred, t1]) {
          ty1, constr1 = recon(ctx, t1) 
          [TY_NAT, [ty1, TY_NAT]+constr1]
        }
        with(_[:IsZero, t1]) {
          ty1, constr1 = recon(ctx, t1) 
          [TY_NAT, [ty1, TY_NAT]+constr1]
        }
        with(_[:True]) {
          [TY_BOOL, []]
        }
        with(_[:False]) {
          [TY_BOOL, []]
        }
        with(_[:If, t1, t2, t3]) {
          ty1, constr1 = recon(ctx, t1)
          ty2, constr2 = recon(ctx, t2)
          ty3, constr3 = recon(ctx, t3)
          newconstr = [[ty1, TY_BOOL], [ty2, ty3]]
          [ty3, newconstr + constr1 + constr2 + constr3]
        }
        with(_) { raise "no match" }
      }
    end

    def unify(fi, msg, constr)
      u = ->(constr) {
        first, *rest = *constr
        match(first) {
          with(nil) { [] }
          with(_[left, right & TyId]) {
            if left == right
              u.(rest)
            elsif occurs_in?(right.id, left)
              raise "#{msg}: circular constraints"
            else
              u.(subst_constr(right.id, left, rest)) + 
                [[TyId.new(right.id), left]]
            end
          }
          with(_[left & TyId, right]) {
            u.( [[right, left], *rest] )
          }
          with(_[TyNat, TyNat]) { u.(rest) }
          with(_[TyBool, TyBool]) { u.(rest) }
          with(_[fun1 & TyArr, fun2 & TyArr]) {
            u.( [[fun1.t1, fun2.t1], [fun1.t2, fun2.t2], *rest] )
          }
          with(_) {
            raise "Unsolvable constraints"
          }
        }
      }

      u.(constr)
    end

    private

    def occurs_in?(name, type)
      match(type) {
        with(TyArr) { occurs_in?(name, type.t1) ||
                      occurs_in?(name, type.t2) }
        with(TyNat) { false }
        with(TyBool) { false }
        with(TyId) { name == type.id }
      }
    end

    def subst_constr(name, type, constr)
      constr.map{|(t1, t2)|
        [subst_ty(name, type, t1),
         subst_ty(name, type, t2)]
      }
    end

    def subst_ty(name, type, substee_type)
      match(substee_type) {
        with(TyArr) { 
          TyArr.new(subst_ty(substee_type.t1),
                    subst_ty(substee_type.t2))
        }
        with(TyNat) { substee_type }
        with(TyBool) { substee_type }
        with(TyId) { substee_type.id == name ? type : substee_type }
      }
    end

  end
end

if $0 == __FILE__
  p 1

  typer = Typer.new
  p typer.unify(:fi, :msg, [])
end
