#lang scribble/base

@(require scriblib/figure
          scribble/core
          scribble/manual
          scriblib/footnote
          (only-in slideshow/pict scale-to-fit scale)
          (only-in "models/stlc.rkt" stlc-type-pict-horiz)
          "deriv-layout.rkt"
          "citations.rkt"
          "typesetting.rkt"
          "models/clp.rkt"
          "pat-grammar.rkt")

@(define (mymath start end . strs)
   (make-element (make-style "relax" '(exact-chars)) `(,start ,@strs ,end)))

@(define (math-in . strs) (apply mymath "\\(" "\\)" strs))

@(define (math-disp . strs) (apply mymath "\\[" "\\]" strs))

This chapter explains the method used to generate terms satisfying
judgment forms and metafunctions. To introduce the approach,
it begins by working through an example generation for a well-typed
term. The generation method is then explained in general,
starting with a subset of Redex's pattern and term languages, which is
used as a basis for describing judgment-form based generation.
The generation method works by searching for derivations that satisfy
the relevant relation definitions, using a constraint
solver to maintain consistency during the search.

Following the explanation of the basic generation method, 
metafunction generation is introduced along with some
necessary extensions to the constraint solver. Then the 
constraint solver is explained in some detail. Finally
the methods used to handle Redex's full pattern language 
are discussed.

@section{An Example Derivation}

@figure["fig:types"
        "Typing judgment for the simply-typed lambda calculus"
        @centered[stlc-type-pict-horiz]]

The judgment-form based random generator uses the strategy of
attempting to generate a random derivation satisfying the
judgment. To motivate how it works, we will work through the
generation of an example derivation for the type system shown
in @figure-ref["fig:types"]. We can begin with a schema for
how we would like the resulting judgment to look. We would like
to find a derivation for some expression @(stlc-term e_^0)
with some type @(stlc-term τ_^0) in the empty environment:

@(centered
  (typ • e_^0 τ_^0))

Where we have added superscripts to distinguish variables introduced 
in this step from those introduced later; since this is the initial
step, we mark them with the index 0.
The rule chosen in the initial generation step will be final
rule of the derivation.
The derivation will have to end with some rule, so 
we randomly choose one, suppose it is the abstraction rule.
Choosing that rule will require us to specialize the values
of @(stlc-term e_^0) and @(stlc-term τ_^0) in order to agree
with the form of the rule's conclusion.
Once we do so, we have a partial derivation that looks like:

@(centered
  (infer (typ • (λ (x_^1 τ_x^1) e_^1) (τ_x^1 → τ_^1))
         (typ (x_^1 τ_x^1 •) e_^1 τ_^1)))

Variables from this step are marked with a 1.
This will work fine, so long as we can recursively generate a derivation
for the premise we have added. We can randomly choose a rule again and try
to do so. 

If we next choose abstraction again, followed by function application, 
we arrive at the following partial derivation:

@(centered
  (infer #:h-dec min (typ • (λ (x_^1 τ_x^1) (λ (x_^2 τ_x^2) (e_1^3 e_2^3))) (τ_x^1 → (τ_x^2 → τ_^2)))
         (infer  #:h-dec min (typ (x_^1 τ_x^1 •) (λ (x_^2 τ_x^2) (e_1^3 e_2^3)) (τ_x^2 → τ_^2))
                (infer (typ (x_^2 τ_x^2 (x_^1 τ_x^1 •)) (e_1^3 e_2^3) τ_^2)
                       (typ (x_^2 τ_x^2 (x_^1 τ_x^1 •)) e_1^3 (τ_2^3 → τ_^2))
                       (typ (x_^2 τ_x^2 (x_^1 τ_x^1 •)) e_2^3 τ_2^3)))))
Abstraction has two premises, so now there are two branches of the derivation
that need to be filled in. We can work on the left side first.
Suppose we make a random choice to use the variable rule there, and
arrive at the following:

@(centered
  (infer #:h-dec min (typ • (λ (x_^1 τ_x^1) (λ (x_^2 τ_x^2) (x_^4 e_2^3))) (τ_x^1 → (τ_x^2 → τ_^2)))
         (infer #:h-dec min (typ (x_^1 τ_x^1 •) (λ (x_^2 τ_x^2) (x_^4 e_2^3)) (τ_x^2 → τ_^2))
                (infer (typ (x_^2 τ_x^2 (x_^1 τ_x^1 •)) (x_^4 e_2^3) τ_^2)
                       (infer (typ (x_^2 τ_x^2 (x_^1 τ_x^1 •)) x_^4 (τ_2^3 → τ_^2))
                              (eqt (lookup (x_^2 τ_x^2 (x_^1 τ_x^1 •)) x_^4) (τ_2^3 → τ_^2)))
                       (typ (x_^2 τ_x^2 (x_^1 τ_x^1 •)) e_2^3 τ_2^3)))))

At this point it isn't obvious how to continue, because @tt{lookup} is defined as
a metafunction, and we are generating a derivation using a method based on judgment forms. 
To complete the derivation for @tt{lookup}, we will treat it as a judgment form, except that 
we have to be careful to preserve its meaning, since judgment form cases don't apply in order
and, in fact, the second case of @tt{lookup} overlaps with the first. So that we can never
apply the rule corresponding to the second case when we should be using the first, we
will add a second premise to that rule stating that @italic{x@subscript{1} ≠ x@subscript{2}}.
The new version of @tt{lookup} is shown in @figure-ref["fig:lookups"], alongside the original. If
we now choose the @tt{lookup} rule that recurs on the tail of the environment (corresponding
to the second clause of the metafunction), the partial 
derivation looks like: 

@figure["fig:lookups"
        "Lookup as a metafunction (left), and as a judgment form."
        @centered[(lookup-both-pict)]]

@(centered
  (infer #:h-dec min (typ • (λ (x_^1 τ_x^1) (λ (x_^2 τ_x^2) (x_^4 e_2^3))) (τ_x^1 → (τ_x^2 → τ_^2)))
         (infer #:h-dec min (typ (x_^1 τ_x^1 •) (λ (x_^2 τ_x^2) (x_^4 e_2^3)) (τ_x^2 → τ_^2))
                (infer (typ (x_^2 τ_x^2 (x_^1 τ_x^1 •)) (x_^4 e_2^3) τ_^2)
                       (infer (typ (x_^2 τ_x^2 (x_^1 τ_x^1 •)) x_^4 (τ_2^3 → τ_^2))
                              (infer (eqt (lookup (x_^2 τ_x^2 (x_^1 τ_x^1 •)) x_^4) (τ_2^3 → τ_^2))
                                     (neqt x_^2 x_^4)
                                     (eqt (lookup (x_^1 τ_x^1 •) x_^4) (τ_2^3 → τ_^2))))
                       (typ (x_^2 τ_x^2 (x_^1 τ_x^1 •)) e_2^3 τ_2^3)))))
This branch of the derivation can be completed by choosing the rule corresponding to
the first clause of @tt{lookup} to get:

@(centered
  (infer #:h-dec min (typ • (λ (x_^1 (τ_2^3 → τ_^2)) (λ (x_^2 τ_x^2) (x_^1 e_2^3))) ((τ_2^3 → τ_^2) → (τ_x^2 → τ_^2)))
         (infer #:h-dec min (typ (x_^1 (τ_2^3 → τ_^2) •) (λ (x_^2 τ_x^2) (x_^1 e_2^3)) (τ_x^2 → τ_^2))
                (infer (typ (x_^2 τ_x^2 (x_^1 (τ_2^3 → τ_^2) •)) (x_^1 e_2^3) τ_^2)
                       (infer (typ (x_^2 τ_x^2 (x_^1 (τ_2^3 → τ_^2) •)) x_^1 (τ_2^3 → τ_^2))
                              (infer (eqt (lookup (x_^2 τ_x^2 (x_^1 (τ_2^3 → τ_^2) •)) x_^1) (τ_2^3 → τ_^2))
                                     (neqt x_^2 x_^1)
                                     (infer (eqt (lookup (x_^1 (τ_2^3 → τ_^2) •) x_^1) (τ_2^3 → τ_^2)))))
                       (typ (x_^2 τ_x^2 (x_^1 (τ_2^3 → τ_^2) •)) e_2^3 τ_2^3)))))

It is worth noting at this point that the form of the partial derivation may sometimes exclude
rules from being chosen. For example, we couldn't satisfy the right branch of the derivation in the same way,
since that would eventually mean that @(eqt τ_2^3 (τ_2^3 → τ_^2)), leaving us with no finite value
for @(stlc-term τ_2^3). 
However, we can complete the right branch by again choosing (randomly) the variable rule, followed
by the rule corresponding to @tt{lookup}'s first clause, arriving at:

@(centered
  (infer #:h-dec min (typ • (λ (x_^1 (τ_x^2 → τ_^2)) (λ (x_^2 τ_x^2) (x_^1 x_^2))) ((τ_x^2 → τ_^2) → (τ_x^2 → τ_^2)))
         (infer #:h-dec min (typ (x_^1 (τ_x^2 → τ_^2) •) (λ (x_^2 τ_x^2) (x_^1 x_^2)) (τ_x^2 → τ_^2))
                (infer (typ (x_^2 τ_x^2 (x_^1 (τ_x^2 → τ_^2) •)) (x_^1 x_^2) τ_^2)
                       (infer (typ (x_^2 τ_x^2 (x_^1 (τ_x^2 → τ_^2) •)) x_^1 (τ_x^2 → τ_^2))
                              (infer (eqt (lookup (x_^2 τ_x^2 (x_^1 (τ_x^2 → τ_^2) •)) x_^1) (τ_x^2 → τ_^2))
                                     (neqt x_^2 x_^1)
                                     (infer (eqt (lookup (x_^1 (τ_x^2 → τ_^2) •) x_^1) (τ_x^2 → τ_^2)))))
                       (infer (typ (x_^2 τ_x^2 (x_^1 (τ_x^2 → τ_^2) •)) x_^2 τ_x^2)
                              (infer (eqt (lookup (x_^2 τ_x^2 (x_^1 (τ_x^2 → τ_^2) •)) x_^2) τ_x^2)))))))

At this point we have a complete derivation for a pattern of non-terminals that is valid for
any term that matches that pattern as long as the new premise that 
@(neqt x_^2 x_^1) is also satisfied. Thus we can simply
pick appropriate random values for @(stlc-term x_^1) and all other non-terminals
in the pattern to get
a random term that satisfies the typing judgment. An example would be:

@(centered
  (typ • (λ (f (num → num)) (λ (a num) (f a))) ((num → num) → (num → num))))
and the constraint that @tt{f} ≠ @tt{a} is satisfied. We note however, the 
importance of this constraint, since a term that does not satisfy it, such
as @(stlc-term (λ (f (num → num)) (λ (f num) (f f)))), is not well-typed.

In the remainder of this chapter, the approach used in this example
is generalized to all Redex judgment forms and metafunctions.

@section{Patterns and Terms in Redex}

Redex handles two s-expression-based grammars internally: patterns and
terms. Simplified forms of both are shown in @figure-ref["fig:pat-terms"].
Terms @italic{t} are essentially s-expressions built from Racket
constants @italic{a}, except that Redex provides a term
environment with bindings for
term variables@note{Variables are just Racket symbols that are bound
   or in binding positions in Redex's term context. In pattern they 
   are in a binding position, and are bound when they appear in
   a term.} 
@italic{x} and metafunctions @italic{f}. When a metafunction
is a applied in a term, the result will be a term, and the result term
is inserted in place of the application. Term variables are simply bound to 
other terms and are replaced by their values. They are bound at the
successful match of a pattern variable.

Patterns @italic{p} are used to match against and decompose terms. They are 
composed of literals @italic{a} which match themselves only, and built in patterns
@italic{b} which match some set of literals --- @tt{number}, which matches
any Racket number, is one example. Pattern variables @tt{x} match against
a term and bind the variable to the term. 
Finally, lists of patterns may be matched against lists of terms.

@figure["fig:pat-terms" 
        (list @"Simplified grammar for Redex patterns ("
              @italic{p}
              @") and terms ("
              @italic{t}
              @").")]{
  @centered[r-lang-pict]}

The term generator actually operates on patterns and produces a pattern as
an intermediate result. The conversion of the resulting pattern to a term is
straightforward. As a first step in generation, then, terms in judgment form 
and metafunction definitions are converted into corresponding patterns
(as described in more detail below).

@section{Judgment Form Generation}
A judgment form in Redex is defined in the following manner, as a set of
inference rules:
@centered[judgment-pict]
Where the @italic{J} non-terminals indicate judgment form ids, and a single
judgment form is defined by a set of rules with matching ids in the conclusion.
Note that that the number of patterns and terms in the conclusion of a single 
judgment form  must be a constant @italic{k}. 
The premise of a single rule (above the line) consists of the conjunction
of some further set of judgments. 
To derive the conclusion of a judgment, there must exist derivations
of all of its premises; the complete derivation of a judgment is the tree
generated by satisfying all such recursive derivations.
A judgment form @italic{J} then inductively defines a relation over a k-tuple of terms, such
that the k-tuple @italic{@math-in{\langle}t@subscript{1}, ... ,t@subscript{k}@math-in{\rangle}} 
is in the relation if there  exists a complete derivation of 
@italic{(J t@subscript{1} ... t@subscript{k})} using the available inference rules.

In Redex, judgment forms are required to have a specified mode determining
which positions in the judgment definition are inputs, and which are outputs.
(These are also sometimes referred to as positive and negative positions.)
In the conclusion of a judgment, input mode positions are patterns, which deconstruct
input terms, and in the premises, input positions are considered terms, which are
used as inputs to recursive attempts to satisfy the judgment. Output positions in premises are
patterns which deconstruct the results of recursive calls, and in the conclusion output positions 
are terms which are the result of trying to satisfy the judgment for some set of inputs. Pattern
positions may bind parts of a successful match for use in building terms in the term
positions. Thus a judgment may be executed as a function
by providing input terms, the result of which will be
some (possibly empty) set of term tuples corresponding to possible values of 
the output positions of the judgment.

For random generation of terms satisfying a judgment, however, it isn't practical to maintain
the distinction between modes of different judgment positions, because it is very
difficult to successfully pick a set of input terms that will satisfy a judgment.
Instead we choose to attempt to construct a random derivation tree, maintaining the invariant 
that a partial derivation is valid as we do so. Since this precludes choosing values
for term position, all positions of the judgment must be treated as patterns. 
Thus the judgment is pre-processed by traversing all pattern
positions in the appropriate order to extract binding identifiers, which are used to
rewrite terms in term positions into patterns. Binding identifiers then create constraints
between the patterns in the rule, as the same identifier may appear in multiple patterns.
Metafunction applications are also transformed during this this step, as is
explained in the next section on metafunction generation.

To try to generate terms satisfying a given judgment @italic{J}, 
we can attempt to construct some random derivation that ends with
of one the rules defining @italic{J}. A randomly chosen rule will have the form:
@centered[j-pict/p]
(Where the @italic{p}'s are meant to reflect that all positions have now been
rewritten as patterns.)
If this rule is chosen, in order to complete the derivation,
@italic{m} sub-derivations must be generated as well, 
one for each judgment @italic{(J@subscript{k} p@subscript{k} ...)}
in @italic{k = 1...m}. Generation thus proceeds recursively, generating
goals of the form @italic{(J@subscript{g} p@subscript{g} ...)} which are to be filled in with
subderivations. In general, a rule with a conclusion @italic{(J@subscript{c} p@subscript{c} ...)}
can be used to attempt to generate a derivation for the goal
@italic{(J@subscript{g} p@subscript{g} ...)}
if rule defines the correct judgment, i.e. @italic{J@subscript{c} = J@subscript{g}}, and
the set of equations @italic{@"{"p@subscript{c} = p@subscript{g}, ...@"}"} 
has solutions. Thus a derivation
will generate a set of equational constraints, which are solved by successively
unifying the patterns in each equation. The result of unification is a substitution
for the pattern variables that satisfies the constraints, or failure, if
such a substitution does not exist.
(Unification and disunification over Redex patterns are addressed in more 
detail Section 3.5.)
The final substitution can be applied
to the original goal to extract terms satisfying the judgment.


The derivation procedure is presented as a set of reduction rules in @figure-ref["fig:derivation"].
The rules presented here are based on the operational semantics for constraint logic 
programming@~cite[clp-semantics], used for their clarity and extensibility with respect 
to the constraint domain, as it will
be necessary to add some new constraints to deal with metafunctions. The rules shown correspond
exactly to those in @citet[clp-semantics], meaning the derivation generator is actually a random constraint
logic programming system.

@figure["fig:derivation" "Derivation generation"]{
  @centered[clp-pict]}
   
The rules operate on a program state @italic{S}, which consists of the program @italic{P}, the current
goal @italic{G}, and the current constraint store @italic{C}. A ``program'' corresponds to 
judgment form definitions in Redex, and consists of a set of
inference rules @italic{(L ← L ...)}, written here such that the conclusion is left of the arrow
and the premises are on the right. The current goal is a list of literals @italic{L}, which 
correspond to subderivations yet to be completed, and constraints @italic{c}, which are just
equations between terms. The constraint store is either @italic{C}, which represents a consistent
set of constraints, or @italic{⊥}, which represents inconsistent constraints and indicates a failed
derivation. (For simplicity the constraint store is kept opaque for the moment.)

The rules process the current goal and modify the constraint store until the goal is empty, at which
point the derivation process is finished. When a constraint is the first element in the goal, it is checked
for consistency with the procedure @tt{add-constraint}, which returns an updated current constraint 
store on success or @italic{⊥} on failure (rules @tt{new constraint} and @tt{invalid constraint}).

When a literal @italic{(J p@subscript{g} ...)} is the first element of the goal, 
the procedure @tt{select} is used to choose a rule from the
program that can be used to satisfy the indicated subderivation. The rule must be from the correct
judgment (the judgment id of its conclusion must match that of the literal), and if such a rule
cannot be found @tt{select} may fail (rule @tt{invalid literal}). Otherwise, the @tt{reduce} rule
applies and the rule is freshened to yield an instance 
@italic{((J p@subscript{f} ...) ← L@subscript{f} ...)} of the rule with uniquely named variables.
Then constraints @italic{p@subscript{g} = p@subscript{f} ...} equating the patterns in the 
goal literal and the conclusion of the rule
are added to the current goal, along with
the premises @italic{L@subscript{f} ...} of the chosen rule, which all must now be satisfied to
complete the derivation.

The specification of the @tt{select} function is especially important from the standpoint
of random generation.
The rules for derivation generation are deterministic aside from the behavior of
@tt{select}, which may affect the form of a derivation by varying the rule used
to attempt to satisfy a literal.
To generate a @italic{random} derivation, @tt{select} simply chooses randomly among the set
of valid candidate rules for a given literal goal. However, this behavior can easily lead to 
non-terminating or inconveniently large derivations, since the @tt{reduce} rule may expand
the size of the goal. To account for this, once a certain depth bound is reached, rules
are selected according to the number of premises they have, from least to greatest. This
makes it much more likely for a derivation to terminate finitely. 

Finally, the model shown in @figure-ref["fig:derivation"] doesn't address the search
behavior of the implementation. Specifically, when an attempted derivation results in 
failure, the generator @italic{backtracks} to the state before most recent application 
of the @tt{reduce} rule and tries again, with the constraint that @tt{select} is no
longer allowed to choose the rule that led to the failed derivation. This introduces 
the possibility of the search getting stuck in an arbitrarily long cycle, which is
avoided by introducing a bound on the number of times such backtracking can occur
in a single attempt to generate a derivation. 
@;{
The implementation thus maintains a stack of derivation states that precede calls to
@tt{select}, sometimes referred to as the failure continuation. The current goal
is sometimes called the success continuation.}

@section{Metafunction Generation}
In this section the requirements of adding support for metafunctions to term 
generation are considered.
Aside from generating inputs and outputs of metafunctions directly, we have to
handle the fact that metafunction application may be embedded inside any term, 
specifically term positions in judgment forms and metafunctions themselves.
This is dealt with during the preprocessing phase that transforms terms into patterns by
lifting out all metafunction applications and providing variable bindings for the result of the
application. The applications are then added as premises of the 
rules used by the term generator. Exactly what it means for a metafunction application
to be the premise of a rule will become clear as metafunction compilation and generation
is explained.

Metafunctions are defined in Redex as a sequence of cases, each of which has some
sequence of left-hand-side patterns and a right-hand-side, or result, term:
@centered[f-pict]
Where the @italic{p}'s are the left-hand-side patterns, and the @italic{t}'s are the result
terms for the @italic{n} clauses.
Metafunctions are applied to terms, and metafunction application attempts to match the argument
term against the left-hand-side patterns in order from @italic{1} to @italic{n}. The
result is the term corresponding to the first successful match, i.e. if the pattern
@italic{p@subscript{k}} from clause @italic{k} matches the input term, 
and none of the patterns @italic{p@subscript{1}} ... @italic{p@subscript{k-1}} does,
then the term @italic{t@subscript{k}} is the result.
The pattern may bind parts of the match for use in constructing the result term.

To handle metafunctions in the derivation generation framework discussed in the
previous section, the strategy of treating them as relations is adopted. First metafunctions
are preprocessed in the same way as judgment forms, transforming terms into patterns and
lifting out metafunction applications. Then, for a clause with left-hand side @italic{p@subscript{l}}
and right-hand side @italic{p@subscript{r}}, a rule with the conclusion 
@italic{(f p@subscript{l} p@subscript{r})} is added, where @italic{f} is the metafunction name.
For a metafunction application of @italic{(f p@subscript{input})} with result @italic{p@subscript{output}},
a premise of the form @italic{(f p@subscript{input} p@subscript{output})} is added, and 
@italic{p@subscript{output}} is inserted at the location of the application:
@centered[f-comp-pict]
The lifting of applications to premises occurs in both metafunction and judgment-form compilation,
and transforms recursive metafunctions into recursive judgments. For example, if
the term @italic{t@subscript{r}} in the illustration above contained a call to @italic{f}, that
call would become a premise of the resulting judgment, and its position in the pattern @italic{p@subscript{r}}
would be replaced by the variable in the output position of the premise.

This translation accomplishes the goal of producing judgments as inputs for the generation
scheme, but it doesn't preserve the semantics of metafunctions. Treating a metafunction 
definition as a relation ignores the ordering of the metafunction clauses. For a metafunction
@italic{f} with  left-hand-side patterns @italic{p@subscript{1}...p@subscript{n}}, if the generator
attempts to satisfy a goal of the form @italic{(f p@subscript{g})} with clause @italic{k}, a constraint
of the form @italic{p@subscript{k} = p@subscript{g}} will be added. But it is possible that
@italic{p@subscript{g}} is eventually instantiated as some term that would have matched some previous pattern
@italic{p@subscript{j}, 1 ≤ j < k}. In this case, an application of @italic{f} to the term in question
@italic{should} have used clause @italic{j}, but the generator has instead generated an application that
used clause @italic{k}. To avoid this situation, constraints that exclude the possibility of matching
clauses @italic{1} through @italic{k - 1} must be added; to generate an application that uses clause
@italic{k} the necessary condition becomes 
@italic{p@subscript{k} = p@subscript{g} ∧ p@subscript{1} ≠ p@subscript{g} ∧ ... ∧ p@subscript{k-1} ≠ p@subscript{g}}.

This seems sufficient at first, but further thought shows this constraint is not quite correct. 
Consider the following definition of the metafunction @italic{g}:
@(newline)
@centered[f-ex-pict]
Where in this context we can consider @italic{p} to be pattern variable that will match any pattern, equivalent
to @code{any} in Redex.
Suppose when generating an application @italic{(g p@subscript{in})} of this metafunction the second clause is chosen. 
This will generate the constraint @italic{p@subscript{in} = p ∧ p@subscript{in} ≠ (p@subscript{1} p@subscript{2})}.
(The fact that variables aside from @italic{p@subscript{in}} will be freshened is elided.) Now suppose that later on
in the generation process, the constraint @italic{p@subscript{in} = (p@subscript{3} p@subscript{4})} is added, so
the relevant part of the constraint store will be equivalent (after a bit of simplification) to:
@centered{@italic{p@subscript{in} = (p@subscript{3} p@subscript{4}) ∧ p@subscript{1} ≠ p@subscript{3} ∧ p@subscript{2} ≠ p@subscript{4}}}
The problem at this point is that it is possible to satisfy these constraints simply by choosing 
@italic{p@subscript{3}} to be anything other than
@italic{p@subscript{1}}, or @italic{p@subscript{4}} anything other than @italic{p@subscript{2}}, but @italic{p@subscript{in}} will still
be a two element list and thus would match the first clause of the metafunction. 

The constraint excluding the first clause must
be strong enough to disallow @italic{any} two element list, which can be satisfied by requiring that:
@centered{@italic{∀ p@subscript{1} ∀ p@subscript{2} p@subscript{in} ≠ (p@subscript{1} p@subscript{2})}}
This suggests the general recipe for transforming metafunctions into judgments suitable for use in
the derivation generator. Each clause is transformed into a rule as described above, with the addition
of premises that are primitive constraints excluding the previous rules. For example, if clause @italic{k} is
being processed, the constraints will be of the form @italic{∀ x ... p@subscript{k} ≠ p@subscript{i}}, for
@italic{i = 1...k-1}, where @italic{p@subscript{k}} is the left hand side of clause @italic{k}.
There will be one constraint for each previous clause where the disallowed pattern
@italic{p@subscript{i}} is the left hand side pattern of clause @italic{i}, and all of the variables in
@italic{p@subscript{i}} must be universally quantified, i.e. for constraint @italic{i}, 
@italic{@tt{Variables}(p@subscript{i})=@tt{@"{"}x ...@tt{@"}"}}.

The derivation generation framework of @figure-ref["fig:derivation"] can easily be modified to handle the addition of the new
constraints, the @italic{c} non-terminal is simply extended with a single new production to be:
@centered[c-ext-pict]
Disequational constraints in a judgment resulting from a metafunction transformation are added to
the goal by the @tt{reduce} rule and
are handled in the same way as the equational constraints by the
@tt{new constraint} rule, provided that the constraint solver, no longer a simple
unification algorithm, can deal with both types of constraints. 
The constraint solver and its extension to deal with disequations is
discussed in the next section.

@section{Equational and Disequational Constraints}

This section presents a model of the constraint solver that operates on a simplified language.
First, the operation of the solver on exclusively equational constraints, where it performs
straightforward syntatic unification, is presented.
Then the extension of the unifier to handle the form of disequational
constraints introduced in the previous section is discussed. Finally issues specific to Redex's full
pattern language are addressed.

The grammar for the constraint solver model is shown in @figure-ref["fig:language"]. The 
model operates on the simplified term language of the @italic{t} non-terminal, which has
only two productions, one for @tt{f}, a single multi-arity term constructor, and one for variables
@italic{x}. This corresponds closely to the Redex pattern language, which also has one multi-arity
constructor, @tt{list}. For now other complexities of the pattern language are ignored, as they
don't directly impact the operation of the constraint solver.
A problem @italic{P} is a list of constraints @italic{c}, which can be equations between terms
@italic{eq} or disequations @italic{dq} (where some variables in the disequations are considered
to be universally quantified). Given a problem, the solver constructs (and maintains, as the problem 
is extended) a substitution @italic{S} that validates the equations and a set of
simplified disequations @italic{D}, such that @italic{S} also validates @italic{D}, and if @italic{D}
is valid, so are all the original disequations in @italic{P}. The substitution@note{To be more precise, 
                                                  @italic{S} is actually the 
                                                  equational representation of some substitution
                                                  @italic{γ}, where @italic{γ} is defined by its
                                                  operation on terms. We will refer to the two
                                                  interchangeably unless it is necessary to
                                                  differentiate between them.} is written
as a set of equations @italic{x=t} between variables and terms, with the understanding that
it can be @italic{applied} to a term by, for each equation, finding each occurrence of @italic{x}
in the term and replacing it with @italic{t}. 
A substitution validates an equation if both
sides of the equation are syntactically identical after the substitution is applied.

@figure["fig:language" "Grammar for the constraint solver model."]{
  @centered[lang-pict]
}

@subsection{Syntactic Unification}

The portion of the solver that deals with equational constraints performs
straightforward syntactic unification of patterns. The algorithm is well
known; @citet[baader-snyder] provide a particularly good survey of theory
in this area, including a similar presentation of syntactic unification
that goes into greater detail.


@figure["fig:unify-func"
        @list{@literal{The metafunction } @tt{U} 
               @literal{ performs unification over the language of } @figure-ref["fig:language"]
               @literal{. (Cases apply in order.)}}
         @(centered (unify-func-pict/contract))]

The metafuction that performs unfication, U, is shown in @figure-ref["fig:unify-func"].
It operates on a problem @italic{P}, a current substitution (or solution) @italic{S}, and 
a current set of disequational constraints @italic{D}, which is ignored by U.
(Except in one case that will be addressed along with the disequational portion 
of the solver.) The result of U is either the the pair @italic{(S : D)} of the substitution 
@italic{S} and the disequations @italic{D} that validate the entire problem, or @italic{⊥}, 
if the problem is inconsistent.

The cases of U apply in order and dispatch on the first equation in @italic{P}.
In the first case, the equation is between two identical terms, and the equation is
dropped before recurring on the rest of @italic{P}.
In the second case, the equation is between two terms applying the function
constructor @tt{f} to the same number of arguments; here the arguments in each position
are equated and added to @italic{P} before recurring.
In the third case, two terms are contructed with @tt{f} but have different numbers
of arguents, in this case U fails and returns @italic{⊥} since it is impossible to
make the terms equal.
The fourth case equates a variable @italic{x} with a term that contains the variable, which
again leads to failure. (The metafunction @tt{occurs?} takes a variable and a term, and
returns true if the term contains the variable, false otherwise.)
The fifth case equates a variable @italic{x} and a term @italic{t}, where it is known (because
the fourth case has already been attempted) that @italic{x} does not occur in @italic{t}.
In this case @italic{t} is substituted for @italic{x} in the remaining equations of the problem
@italic{c...}, the equations of the current substitution @italic{c@subscript{s}...}, and the
current disequations @italic{dq...}, after which the equation @italic{x=t} itself is added
to the current substitution before recurring.
The second to last case of U simply commutes an equation with a variable on the right hand
side before recurring, after which the equation in question will be handled by one of the
previous two cases.
The final case returns @italic{S} and @italic{D} as the solution if the problem is empty.

To make a precise statement about the correctness of U, a few definitions are necessary.
In the following, for a term @italic{t} and substitution @italic{σ}, @italic{σt} is written
to mean the application of @italic{σ} to @italic{t}.

Given two substitutions @italic{σ = ((x@subscript{σ} = t@subscript{σ}) ...)} and 
@italic{θ = ((x@subscript{θ} = t@subscript{θ}) ...)}, their @italic{composition}, 
written @italic{θσ}, is
@italic{θσ = ((x@subscript{σ} = θt@subscript{σ}) ... (x@subscript{θ} = t@subscript{θ}) ...)},
where trivial bindings of the form @italic{(x = x)} are removed and when there is a duplicate
binding @italic{(x@subscript{σ} = θt@subscript{σ})} and @italic{(x@subscript{θ} = t@subscript{θ})}
where @italic{x@subscript{σ} = x@subscript{θ}}, then 
@italic{(x@subscript{θ} = t@subscript{θ})} is removed.

Two substitutions @italic{σ} and @italic{θ} are @italic{equal}, @italic{σ = θ}, if for any variable @italic{x},
@italic{σx = θx}. A substitution @italic{σ} is @italic{more general} than a substitution @italic{θ}, written
@italic{σ ≤ θ}, if there exists some substitution @italic{γ} such that @italic{θ = γσ}. 

A substitution @italic{σ} is called the @italic{most general unifier} of two terms @italic{s}
and @italic{t} if @italic{σs = σt} and
for any substitution @italic{γ} such that @italic{γs = γt}, @italic{σ ≤ γ}.
Similarly, @italic{σ} is a unifier for a unification problem @italic{P = ((s = t) ...)}
if for every equation @italic{s = t} in @italic{P}, @italic{σs = σt}. It is a
most general unifier for @italic{P} if for every @italic{γ} that is a unifier of @italic{P},
@italic{σ ≤ γ}.

@(define inline-init-pict
   (scale
    (unify-init-pict) 1.1))

Finally, we can state that U is correct (again, ignoring the @italic{D} part of the
result for now):
@nested[ #:style 'inset]{@bold{Theorem 1} 
                          For any problem @italic{P}, @inline-init-pict terminates with
                          ⊥ if the equations in @italic{P} have no unifier. Otherwise, it terminates
                          with @italic{(S@subscript{mgu} : D)} where @italic{S@subscript{mgu}} is
                          a most general unifier for @italic{P}.}
Proofs of this proposition can be found in many references on unification, for example @citet[baader-snyder].

The version of U shown in @figure-ref["fig:unify-func"] corresponds fairly closely with the
implementation in Redex, except that the current substitution is represented as a hash table and the function 
recurs on the structure of input terms instead of using the current problem as a stack (as in 
the decomposition rule). As shown here, U has exponential complexity in both time and space. 
The space complexity arises because the substitution may have many identical terms, so by using 
a hash table it may be represented as a DAG (instead of a tree) with
sharing between identical terms and linear space. However the worst-case running time is still
exponential. Interestingly, this is still the most common implementation of unification because
in practice the exponential running time never occurs, and in fact it is usually faster than algorithms
with polynomial or near-linear worst-case complexity.@~cite[unification-comparison]

@subsection{Solving Disequational Constraints}

This section extends the constraint solver of the previous section to process 
disequational constraints of the form @italic{(∀ (x ...) (s ≠ t))} as well as the 
equational constraints already discussed. To handle disequations, U is extended with
four new clauses. The new function is called DU, as this form of constraint solving
is sometimes referred to as disunification@~cite[equational-problems]. The new clauses are shown in 
@figure-ref["fig:du-func"] along with the auxiliary metafunction @tt{param-elim}.
We now provide an informal explanation of DU's operation. A formal justification
can be found in Appendix A.

@figure["fig:du-func"
        @list{@literal{Extensions to } @figure-ref["fig:unify-func"] 
               @literal{ to handle disequational constraints.
                        DU extends U with four new clauses.}}
        @(centered (du-pict))]

The first three clauses of DU all address the situation where the first constraint
in the problem @italic{P} is a disequation of the form @italic{(∀ (x ...) (s ≠ t))}.
Actually in all three cases, the metafunction U (recall that U is the portion of the
solver that applies exclusively to equations) is called with a problem
containing the single equation @italic{(s = t)} and an empty substitution. The result of
this call is passed to the metafunction @tt{param-elim} along with a list of the
parameters, which is where special
handling of the universally quantified variables takes place. (Borrowing the
terminology of @citet[equational-problems], the universally quantified
variables are referred to as ``parameters''.) It is the result of this process
that determines which of the first three cases of DU applies. Of course, in the
Redex implementation, the calls to U and @tt{param-elim} occur only once.

The call to U will return either @italic{⊥} or @italic{(S : ()))}.
If the result is @italic{⊥}, then @tt{param-elim} does nothing and DU simply
drops the constraint in question and recurs. 
(This is the second clause of DU.)
The reasoning here is that it is impossible to unify the terms, 
so the disequation will always be satisfied.

If U returns a value of the form @italic{(S : ()))}, then @italic{S} is 
a most general unifier for the equation in question, 
so for any substitution @italic{γ} such that 
@italic{γs = γt}, @italic{S ≤ γ}. Thus S is used to create a new constraint
excluding all such @italic{γ}. In the absence of parameters, for 
@italic{S = ((x = t@subscript{x}) ...)}, this would involve simply
adding a constraint of the form @italic{(x ≠ t@subscript{x}) ∨ ...}, since 
validating any one of the disequations excludes @italic{S} (and by 
doing so excludes all @italic{γ} where @italic{γ ≤ S}). If @italic{S}
contains any parameters not underneath a function constructor, they
are eliminated by @tt{param-elim}, the intuition being that it is 
impossible to satisfy a disequation of the form @italic{(∀ (x) (x ≠ t))} 
since @italic{x} cannot be chosen to be a term other than @italic{t}.

The auxiliary metafunction @tt{param-elim} takes a substitution @italic{S}
and a list of parameters @italic{(x ...)} as its arguments, and returns a 
modified substitution @italic{S'} such that the intersection of both the domain 
and the range of @italic{S'} with @italic{(x ...)} is empty. (Although either
may contain terms that contain variables in @italic{(x ...)}).
A parameter @italic{x} is eliminated by @tt{param-elim} by simply dropping
the disequation @italic{x ≠ t}, if @italic{x} does not occur as the right or
left-hand side of any other equation in @italic{S}. Otherwise if there are equations
@italic{@"{"x ≠ t@subscript{1}, ..., x ≠ t@subscript{n}@"}"}, 
it is eliminated by replacing those
equations with @italic{@"{"t@subscript{i} ≠ t@subscript{j}, ...@"}"}, where
@italic{i ≤ i,j ≤ n, i ≠ j}.
@note{The @tt{elim-x} metafunction, seen in the specification of @tt{param-elim}
      in @figure-ref["fig:du-func"], implements this find/pair operation.}

If after this process @italic{S} is empty, then DU fails (the first clause), 
since it is impossible to find a substitution to make @italic{s} and
@italic{t} different. Otherwise (DU's third clause), a constraint of the form
@italic{(∀ (x@subscript{a} ...) (f x ...) ≠ (f t ...))} is added.
This is equivalent to the disjunction @italic{(x ≠ t) ∨ ...},
under the quantifier with parameters @italic{x@subscript{a} ...} (which may
remain because we have only eliminated them at the top level of the terms 
@italic{t ...}).

Finally, if it is ever the case that a constraint in @italic{D} no longer
has at least one disequation @italic{x ≠ t} where the right hand side is
a variable, then it is removed and added to the top of the current
problem @italic{P} (DU's final clause). The intuition is that as long as one disequation in a 
constraint looks like @italic{x ≠ t}, where @italic{x} is not a parameter,
it can be satisfied by simply choosing
@italic{x} to be something other than @italic{t}. Otherwise it may be
invalid so it must be checked by applying U and @tt{param-elim} once again.

@(define inline-du-pict
   (scale
    (du-init-pict) 1.1))

@nested[ #:style 'inset]{@bold{Theorem 2} 
                          For any problem @italic{P}, @inline-du-pict terminates with
                          ⊥ if the equations in @italic{P} have no unifier consistent
                          with the disequational constraints in @italic{P}. 
                          Otherwise, it terminates
                          with @italic{(S@subscript{Ω} : D)} where @italic{S@subscript{Ω}} is
                          a most general unifier for the equations in @italic{P}, and 
                          @italic{S@subscript{Ω}} is consistent with the 
                          disequational constraints in @italic{P}. The constraints in
                          @italic{D} are equivalent to the originals in @italic{P}.}

A proof of this theorem is given in Appendix A.
This method of solving disequational constraints is based on the approaches
detailed in @citet[colmerauer-inequations] and @citet[equational-problems].
@citet[colmerauer-inequations] shows how to solve disequational constraints
by using a unifier to simplify them, as we do here, however his constraints
do not include universal quantifiers. @citet[equational-problems], on the other
hand, show how to solve the more general case of problems
of the form @italic{∃ x... ∀ y... φ} where @italic{φ} is a formula consisting of term
equalities and their negation,
disjunction, and conjunction. They give their solution as a set of rewrite rules,
and although their approach will solve the same constraints as ours, the equivalence 
of the two isn't completely trivial. One advantage of the approach we take is 
that it can be easily understood and implemented as an extension to the unifier.

@section{Handling More of the Pattern Language}

Up to this point term generation and the constraint solver have been presented 
using a very simplified version of Redex's internal pattern language.
Here the extension of both to handle a more complete subset of the pattern
language is discussed. The part of the pattern language actually supported by 
the generator is shown in @figure-ref["fig:full-pats"]. Racket symbols
are indicated by the @italic{s} non-terminal, and the @italic{c} non-terminal
represents any Racket constant (which is considered to be equal to itself only by the
matcher and the unifier.) The generator is not able to handle parts of the
pattern language that deal with evaluation contexts, compatible closure, or 
``repeat'' patterns (ellipses). 


@figure["fig:full-pats" "The subset of the internal pattern language supported by the generator"]{
  @centered[(pats-supp-lang-pict)]}

The extensions to the pattern language are enumerated by the new@note{New with respect to
                                                                      @figure-ref["fig:pat-terms"]}
productions of the @italic{p} non-terminal in @figure-ref["fig:full-pats"]. 
We now explain briefly each of the new productions along with the approach used
to handle it in the generator.

@bold{Named Patterns} 
These corrsepond to variables @italic{x} in the simplified version of the pattern
language from @figure-ref["fig:pat-terms"], except now the variable is attached to a sub-pattern.
From the matcher's perspective, the @tt{(name @italic{s p})} production is intended to match a 
term with a pattern @italic{p} and then bind the matched term to the name @italic{s}. 
In the generator named patterns are treated essentially as logic variables. When two patterns are
unified, they are both pre-processed to extract the pattern @italic{p} for each
named pattern, which is rewritten into a logic variable with the
identifier @italic{s}. This is done by finding the value for @italic{s} in the
current substitution, and unifying @italic{p} with that value. The result is used
to update the value of @italic{s} in the current substitution. (If @italic{s} is
a new variable, then its value simply becomes @italic{p}).

@bold{Built-in Patterns}
The @italic{b} and @italic{v} non-terminals are built-in patterns that match subsets of
Racket values. The productions of @italic{b} are self-explanatory; @tt{integer}, for example,
matches any Racket integer, and @tt{any} matches any Racket s-expression.
From the perspective of the unifier, @tt{integer} is a term that
may be unified with any integer, the result of which is the integer itself.
The value of the term in the current substitution is then updated.
Equalities between built-in patterns have the obvious relationship; the result
of an equality between @tt{real} and @tt{natural}, for example, is @tt{natural}, whereas
an equality between @tt{real} and @tt{string} simply fails.
As equalities of this type are processed, the values of terms in the current
substitution are refined.

The @italic{v} non-terminals match Racket symbols in varying and commonly useful ways;
@tt{variable-not-otherwise-mentioned}, for example, matches any symbol that is not used
as a literal elsewhere in the language. These are handled similarly to the patterns of
the @italic{b} non-terminal within the unifier.

@bold{Mismatch Patterns}
These are patterns of the from @tt{(mismatch-name @italic{s} @italic{p})} which match the pattern 
@italic{p} with the constraint that two mismatches of the same name @italic{s} may never
match equal terms. These are straightforward: whenever a unification with a mismatch takes
place, disequations are added between the pattern in question and other patterns
that have been unified with the same mismatch pattern.

@bold{Non-terminal Patterns}
Patterns of the form @tt{(nt @italic{n})} are intended to successfully match a term 
if the term matches one of the productions of the non-terminal @italic{n}. (Recall that
patterns are always constructed in relation to some language.) It is less clear how
non-terminal patterns should be dealt with in the unifier. It would be nice to have
an efficient method to decide if the terms defined by some pattern intersected with
those defined by some non-terminal, but this reduces to the problem of computing
the intersection of tree automata, which is known to have exponential complexity.
@~cite[tata] Instead a conservative check is used at the time of unification and the
non-terminal information is saved.

When a pattern is equated with a non-terminal, the non-terminal is unfolded once
by retrieving all of its productions and replacing any recursive positions of the
non-terminal with the pattern @tt{any}. 
The pattern is normalized by replacing all variable positions with @tt{any}.
Then it is verified that the normalized pattern unifies with at least 
one of the abbreviated productions. The check is relatively
inexpensive, and the results can be cached. This method is effective at catching cases
where a pattern should obviously fail to unify with a non-terminal, but because
it may succeed where a more complete method would fail, a later check is necessary.

When a pattern successfully unifies with a non-terminal, the pattern is annotated
with the name of the non-terminal in the current substitution. The intention of this
is that once a pattern becomes fully instantiated (once it becomes a term), it
becomes simple to verify that it does indeed match one of the non-terminal's productions.
All annotated non-terminals are verified when result patterns are instantiated as terms.

This approach to handling grammar information in a unifier is somewhat ad-hoc, 
and it might be interesting to consider more fully how such structure could be used
to aid unification.

@subsection{Instantiating Patterns}

The result of the derivation generation process is a pattern that corresponds to the
original goal, an environment that corresponds to the substitution generated by the
generation process, and a set of disequational constraints. 
The final step is to perform the necessary random instantiations of pattern
variables to produce a term as the result.
Variables in the environment will resolve to patterns consisting of @tt{list}
constructors, racket constants, non-terminals, and built-in patterns.
The portion of the environment necessary to instantiate the goal pattern is
processed to eliminate built-in patterns and non-terminals by using
the context-free generation method, and @tt{list} terms are converted to racket lists.
Then the disequational constraints are checked for consistency with the new environment.
Finally, the goal pattern is converted to a term by using the same process and resolving
the necessary variables.