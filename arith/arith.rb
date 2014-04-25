require 'pattern-match'

=begin
Terms:
  [:True]
  [:False]
  [:If, t1, t2, t3]
  [:Zero]
  [:Succ, t1]
  [:Pred, t1]
  [:IsZero, t1]
=end

module Arith
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
end
