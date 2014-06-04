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
  module Type
    class Base; end
    class TyId < Base
      def initialize(id)
        @id = id
      end
      attr_accessor :id
      def ==(other)
        other.is_a?(TyId) && other.id == self.id
      end
      def inspect
        "#{@id}"
      end
    end
    class TyArr < Base
      def initialize(t1, t2)
        @t1, @t2 = t1, t2
      end
      attr_accessor :t1, :t2
      def ==(other)
        other.is_a?(TyArr) && other.t1 == self.t1 && other.t2 == self.t2
      end
      def inspect
        "#<#{@t1.inspect} -> #{@t2.inspect}>"
      end
    end
    class TyBool < Base
      def inspect
        "BOOL"
      end
    end
    TY_BOOL = TyBool.new
    class TyNat < Base
      def inspect
        "NAT"
      end
    end
    TY_NAT = TyNat.new
  end

  class Context
    def initialize(list=[])
      @list = list
    end

    def add_binding(str, bind)  # bind: Type(=VarBind) || :NameBind
      Context.new([[str, bind]] + @list)
    end

    def add_name(str)
      add_binding(str, :NameBind)
    end

    def get(i)
      raise "invalid varref" if i >= @list.length
      @list[i][1]
    end
  end

  class Typer
    include Type

    # Return [type, constr]
    def recon(ctx, t)
      match(t) {
        # Variable reference
        with(_[:Var, i, _]) {
          ty = ctx.get(i)
          [ty, []]
        }
        # Function abstraction without type annotation
        with(_[:Abs, name, nil, t2]) {
          tyx = TyId.new(gen_uvar)
          ctx2 = ctx.add_binding(name, tyx)
          ty2, constr2 = recon(ctx2, t2)
          [TyArr.new(tyx, ty2), constr2]
        }
        # Function abstraction with type annotation
        with(_[:Abs, name, tyx, t2]) {
          ctx2 = ctx.add_binding(name, tyx)
          ty2, constr2 = recon(ctx2, t2)
          [TyArr.new(tyx, ty2), constr2]
        }
        # Function application (function call)
        with(_[:App, t1, t2]) {
          ty1, constr1 = recon(ctx, t1)
          ty2, constr2 = recon(ctx, t2)
          tyx = TyId.new(gen_uvar)
          newconstr = [[ty1, TyArr.new(ty2, tyx)]]
          [tyx, newconstr + constr1 + constr2]
        }
        with(_[:Let, x, t1, t2]) {
          if value?(t1)
            recon(ctx, termSubstTop(t1, t2))
          else
            ty1, constr1 = recon(ctx, t1)
            ctx1 = ctx.add_binding(x, ty1)
            ty2, constr2 = recon(ctx1, t2)
            [ty2, constr1 + constr2]
          end
        }
        with(_[:Zero]) {
          [TY_NAT, []]
        }
        with(_[:Succ, t1]) {
          ty1, constr1 = recon(ctx, t1) 
          [TY_NAT, [[ty1, TY_NAT]]+constr1]
        }
        with(_[:Pred, t1]) {
          ty1, constr1 = recon(ctx, t1) 
          [TY_NAT, [[ty1, TY_NAT]]+constr1]
        }
        with(_[:IsZero, t1]) {
          ty1, constr1 = recon(ctx, t1) 
          [TY_NAT, [[ty1, TY_NAT]]+constr1]
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
        with(_) { raise "no match: #{t.inspect}" }
      }
    end

    def numeric?(t)
      match(t) {
        with(_[:Zero]) { true }
        with(_[:Succ, t1]) { numeric?(t) }
        with(_) { false }
      }
    end
    private :numeric?

    def value?(t)
      match(t) {
        with(_[:True]) { true }
        with(_[:False]) { true }
        with(_[t1], guard{ numeric?(t1) }) { true }
        with(_[:Abs, _, _, _]) { true }
        with(_) { false }
      }
    end
    private :value?

    def gen_uvar
      @last_uvar ||= 0
      @last_uvar += 1
      "?#{@last_uvar}"
    end
    private :gen_uvar

    def termSubstTop(s, t)
      termShift(-1, termSubst(0, termShift(1, s), t))
    end
    def termSubst(j, s, t)
      tmmap(j, t){|j, x, n|
        if x == j then termShift(j, s) else [:Var, x, n] end
      }
    end

    def termShift(d, t)
      termShiftAbove(d, 0, t)
    end
    def termShiftAbove(d, c, t)
      tmmap(c, t){|c, x, n|
        if x >= c then [:Var, x+d, n+d] else [:Var, x, n+d] end
      }
    end
    def tmmap(c, t, &block)
      walk = ->(c, t){
        match(t) {
          with(_[:Var, x, n]){ block.call(c, x, n) }
          with(_[:Let, x, t1, t2]){ [:Let, x, walk.(c, t1), walk.(c+1, t2)] }
          with(_[:True]){ t }
          with(_[:False]){ t }
          with(_[:If, t1, t2, t3]){ [:If, walk.(c, t1), walk.(c, t2), walk.(c, t3)] }
          with(_[:Zero]){ t }
          with(_[:Succ, t1]){ [:Succ, walk.(c, t1)] }
          with(_[:Pred, t1]){ [:Pred, walk.(c, t1)] }
          with(_[:IsZero, t1]){ [:IsZero, walk.(c, t1)] }
          with(_[:Abs, x, tyx, t2]){ [:Abs, x, tyx, walk.(c+1, t2)] }
          with(_[:App, t1, t2]){ [:App, walk.(c, t1), walk.(c, t2)] }
          with(_){ raise "tmmap: no match: #{t.inspect}" }
        }
      }
      walk.(c, t)
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
            raise "Unsolvable constraints: #{constr.inspect}"
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
          TyArr.new(subst_ty(name, type, substee_type.t1),
                    subst_ty(name, type, substee_type.t2))
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
