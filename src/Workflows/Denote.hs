-- |
-- Module      : Workflows.Denote
-- Description : Denotational design — the meaning first, and the representation
--               only through it.
--
-- == The map: old Markdown -> new program
--
-- +-------------------------------------------+---------------------------------------------------------------+
-- | @~\/src\/nix\/config\/ai@                 | here                                                          |
-- +===========================================+===============================================================+
-- | @skills\/denotational-design\/SKILL.md@   | @denote@ — the ground rules as the standing context every      |
-- |                                           | phase carries                                                  |
-- +-------------------------------------------+---------------------------------------------------------------+
-- | its @## When to use, and when not@        | 'admissionBrief' — a @'Agentic.Workflow.confirm'@ __before__    |
-- |                                           | the body, so a run over I\/O glue ends before it costs a phase |
-- +-------------------------------------------+---------------------------------------------------------------+
-- | @references\/dialog-protocol.md@ phases   | 'objectBrief', 'operationsBrief', 'lawsBrief',                 |
-- | 1–4                                       | 'derivedBrief' — the meaning half, in the protocol's order      |
-- +-------------------------------------------+---------------------------------------------------------------+
-- | @assets\/design-worksheet.md@             | 'worksheetBrief' — the living document, assembled once and     |
-- |                                           | then the __only__ thing the exit tests revise                  |
-- +-------------------------------------------+---------------------------------------------------------------+
-- | every phase's \"__Exit test__\"           | @'Workflows.Escalation.escalating'@ — a judge on a different   |
-- |                                           | engine, three endings, and a bound                             |
-- +-------------------------------------------+---------------------------------------------------------------+
-- | phases 5–8                                | 'representationsBrief', 'denotationsBrief',                    |
-- |                                           | 'operationsPerRepBrief', 'squaresBrief' — reachable __only__    |
-- |                                           | through the arm where the meaning settled                      |
-- +-------------------------------------------+---------------------------------------------------------------+
-- | phases 9–10                               | 'realizationBrief', which is tier 1 over the @realization@     |
-- |                                           | input: \"whether a final foreign-language realization is        |
-- |                                           | planned … decides whether phase 10 exists\"                    |
-- +-------------------------------------------+---------------------------------------------------------------+
-- | @## Closing every engagement@             | 'closingBrief' — the four completion tests, the elimination    |
-- |                                           | list, and what resisted                                        |
-- +-------------------------------------------+---------------------------------------------------------------+
-- | the seven @references\/*.md@ (1,921 lines)| @'Agentic.Workflow.input' \"method\"@ — an @--input-file@, not   |
-- | and the 209-line worksheet                | prompt bulk                                                    |
-- +-------------------------------------------+---------------------------------------------------------------+
--
-- The Markdown was read as __data__. Nothing in @~\/src\/nix\/config\/ai@ is
-- modified by this module, and no party in it points at that tree.
--
-- == The leveling-up, item by item
--
--   1. __\"Do not reach for the prover before the meaning\" becomes
--      reachability.__ The skill says it twice — once as a ground rule
--      (\"meaning constrains implementation; implementation never constrains
--      meaning\") and once as phase 7's literal __Gate__: \"do not begin on
--      operations until the level's meaning function is written … without it
--      there are three\" unknowns. Here the representation half of the program
--      sits inside the arm where the meaning's exit tests __settled__, so a run
--      whose meaning did not survive review cannot reach a single question about
--      representations. That is not a rule; it is the shape of the printed
--      program, and @wf plan denote --raw@ shows it.
--
--   2. __The admission test is a branch, and it is first.__ @## When to use, and
--      when not@ is the strongest \"do not run me\" section in the corpus — \"do
--      NOT apply the full method to I\/O glue, config parsing, log formatting,
--      migration scripts, test scaffolding, or build tooling\" — and in the
--      corpus it is a paragraph the reader has already blown past by the time it
--      matters. Here it is one 'Agentic.Workflow.confirm' before the body, and
--      its @no@ arm reports the skill's own proportionate minimum: \"name the
--      mathematical object and write one line of @⟦·⟧@, then stop\".
--
--   3. __A retrofit may end in \"start over\", and that ending is a success.__
--      @references\/dialog-protocol.md@ is explicit and the sentence is easy to
--      miss: \"The defect inventory licenses __two__ verdicts, not one: fix these
--      defects, or /start over/ … A retrofit that ends in a documented start-over
--      recommendation succeeded; say so rather than forcing a repair.\" Nothing in
--      Markdown can take that branch. Here it is
--      'Workflows.Deciders.startOverRecommended' over the retrofit's own defect
--      inventory — zero questions — and it is the one ending in this program that
--      reports a success without a single proof obligation discharged.
--
--   4. __The exit tests are judged by somebody who did not write the artefact.__
--      Ten phases each carry an exit test and in the corpus the same reader
--      applies all ten to its own work. The loop's judge is
--      @'Workflows.Parties.lateral'@ and its author is
--      @'Workflows.Parties.reasoning'@, which is 'Workflows.Rubrics.Voice''s
--      argument — the model that wrote the draft is a bad judge of whether it
--      opened with a forbidden opening — arriving at a design method.
--
--   5. __\"A failed morphism is a finding, not a defeat\" gets an ending that
--      says so.__ The skill insists on it and then has nowhere to put the
--      finding. @'Agentic.Workflow.revisingOn'@'s three tags are three endings
--      here: the meaning settled, the meaning still has an open equation after
--      every round the run was given, or the judge would not judge it at all.
--      The middle one yields the worksheet it was working on — because
--      \"an equation that will not close is a redesign\", and a redesign wants
--      the worksheet.
--
-- == Two honest departures from @doc\/design.md@ §7.4 row 6, both recorded
--
-- That row reads: \"ten phases each with questions, an artifact and an exit test
-- = ten @documentPanel@\/@confirm@\/@revisingOn@ triples\".
--
-- __The phases are a chain, not ten panels.__ A @'Agentic.Workflow.panel'@ is
-- independent by construction — no member sees another's answer — and these
-- phases are the opposite of independent: phase 2's operations are operations /on
-- the object phase 1 chose/, phase 6's meaning functions are into /phase 5's
-- levels/, and phase 7 is gated on phase 6 by the protocol's own word. A panel
-- here would ask ten questions about nothing. So each phase is a bind whose
-- prompt splices the artefacts before it, which is what a dialog is.
--
-- __One bounded loop, not ten.__ Ten @revisingOn@s at @'Agentic.Workflow.atMost'
-- 2@ would be 5 to the tenth power paths in the plan — @'Agentic.Plan.costSummary'@
-- would print a number nobody can read, and @ci\/workflows.sh@ would pin it. The
-- loop is over the __worksheet__, which is the artefact the skill itself says the
-- phases produce (\"produce the design as a living document … an empty section is
-- a visible unmet obligation rather than an absence nobody notices\"), and its
-- judge is given every phase's exit test at once. What is lost is a per-phase
-- stopping point; what is kept is every exit test, applied by somebody else, with
-- a bound and three endings. Both halves of that trade are stated here rather
-- than discovered by a reader of the price.
{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QualifiedDo #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE RebindableSyntax #-}
{-# LANGUAGE TypeApplications #-}

module Workflows.Denote
  ( -- * The program
    denoteProgram,
    denoteDoc,
    denoteHelp,
    denoteScript,

    -- * The tier-1 readings of an invocation
    proverOf,
    realizationBrief,

    -- * The rubrics, transplanted
    groundRules,
    admissionBrief,
    objectBrief,
    operationsBrief,
    lawsBrief,
    derivedBrief,
    worksheetBrief,
    exitBrief,
    reviseBrief,
    representationsBrief,
    denotationsBrief,
    operationsPerRepBrief,
    squaresBrief,
    closingBrief,

    -- * The function
    denoteReportFn,
    denoteTable,
  )
where

import qualified Agentic.Workflow.Do as W
import Data.String (fromString)
import Data.Text (Text)
import qualified Data.Text as T
import Workflows.Prelude
import Prelude

-- ---------------------------------------------------------------------------
-- The tier-1 readings of an invocation
-- ---------------------------------------------------------------------------

-- | Which proof assistant the design's phases 6–8 are written in.
--
-- __Tier 1__ ("Workflows.Deciders"): ordinary Haskell over the invocation, zero
-- questions and zero paths.
--
-- /Source:/ @references\/provers.md@ by way of the dialog protocol's framing
-- points — \"Lean 4 (default), Rocq, or Agda\" — and its instruction to \"ask the
-- user's preference in phase 1; do not re-litigate it later without cause\". An
-- input read once before the program exists is exactly that: asked in the
-- invocation, and unavailable to re-litigate.
proverOf :: Text -> Text
proverOf p
  | T.null (T.strip p) = "Lean 4"
  | otherwise = T.strip p

-- | What the realization phases are told, which is where phase 10 exists or does
-- not.
--
-- __Tier 1__, and it is the cleanest example in this module of a judgment the
-- corpus asks a reader to make and this program computes: the protocol says to
-- settle \"whether a final foreign-language realization (Rust, C++, …) is
-- planned, since that decides whether phase 10 exists\". An empty input is a
-- design with no foreign realization, and the brief then says phase 10 does not
-- exist for it — rather than asking ten questions about a bisimulation nobody
-- will run.
realizationBrief :: Text -> Text
realizationBrief raw
  | T.null (T.strip raw) =
      [wft|
      Phase 9, and phase 9 only. No foreign-language realization is planned for
      this design, so phase 10 -- cross-language realization fidelity -- does
      not exist here, and you are not to invent one.

      Produce the empirical layer:

      - acceptance cards, committed BEFORE the work they judge: what will be
        measured, on what input, against what threshold, and who decides.
        Gates only tighten. A criterion written after the measurement is not a
        criterion.
      - the evidence-ceiling table: for each card, what its passing does NOT
        prove. A diagnostic never upgrades to semantic evidence by being cited.
      - the gate ladder: which cards block, which advise, and in what order
        they run.

      Say plainly which claims in this design rest on proof and which rest on
      sampling, and do not let the second borrow the first's certainty. An
      unmeasured performance claim is labelled as an impression, in the method's
      own words, rather than dressed as a gate.|]
  | otherwise =
      [wft|
      Phases 9 and 10. A realization in {lang} is planned, so the design has a
      component outside the proof kernel and phase 10 exists.

      Produce the empirical layer first:

      - acceptance cards, committed BEFORE the work they judge, with pinned
        comparison tuples; gates only tighten;
      - the evidence-ceiling table: for each card, what its passing does NOT
        prove;
      - the gate ladder: which cards block and which advise.

      Then the fidelity plan, and the first clause is the one that makes it a
      plan rather than a diff:

      - give the {lang} realization ITS OWN meaning function into the SAME
        mathematical object. Bisimilarity comes from the shared target, never
        from comparing two implementations with each other.
      - choose the strategies: golden-vector corpora exported from the prover,
        differential drivers, the morphism equations as property-based tests,
        probes at the foreign-function boundary, and a stage ladder that
        computes the first failing stage and the next owner.
      - state the single-oracle doctrine: exactly one fresh semantic oracle,
        and every other implementation is comparison evidence only.
      - do NOT transliterate the prover's notation. Express the denotation and
        the morphism obligations in {lang}'s own idiom.|]
  where
    lang = T.strip raw

-- ---------------------------------------------------------------------------
-- The rubrics, transplanted
-- ---------------------------------------------------------------------------

-- | The standing context every phase in this run carries.
--
-- /Source:/ @SKILL.md@'s @## Ground rules (hold these in every phase)@,
-- compressed to the clauses that change what an answer /is/. The three that are
-- quoted rather than paraphrased are quoted because paraphrasing them is how they
-- get lost: \"solve, do not verify\", \"the specification may be unrunnable\", and
-- the three provisos under which the laws come already paid for.
groundRules :: Text
groundRules =
  [wft|
  You are working in Conal Elliott's denotational design discipline. The method
  in one line: before asking how it runs, ask what it means; then require that
  the meaning be preserved; let the implementation be whatever the equations
  force it to be.

  Hold all of these in every answer:

  - MEANING CONSTRAINS IMPLEMENTATION; IMPLEMENTATION NEVER CONSTRAINS MEANING.
    The specification is pulled toward precise simplicity and the realization
    toward the machine in front of you, and each is pushed to its extreme. The
    theorem is not a tax on the fast path; it is the permission slip for it.
  - SOLVE, DO NOT VERIFY. Every homomorphism equation is an algebra problem with
    exactly one unknown -- the representation's operation -- and every solution
    is correct. Implementations are read off solved forms, and efficiency work
    is the choice AMONG solutions.
  - THE SPECIFICATION MAY BE UNRUNNABLE. Prefer the non-computable meaning that
    is clear over the executable one that is compromised: we only compute with
    representations, and we only think with meanings.
  - COMPOSE FIRST, APPROXIMATE LAST. Resolution, sample rates, frame
    boundaries, step sizes and fixed precision live at exactly one level -- the
    bottom -- applied once after everything has been combined. Errors that are
    individually small compound past usefulness under composition.
  - ADEQUACY ADMITS, EFFICIENCY VETOES, SIMPLICITY DECIDES. A model that cannot
    answer the domain's questions is disqualified whatever its beauty; so is
    one whose realizations are unaffordably slow. Simplicity is the tiebreaker
    among candidates that already pass both, and never an admission criterion.
  - THE SIMPLICITY CRITERION IS A TEST, NOT A TASTE. A meaning is elegant when
    it can be stated concisely in mathematics that already exists FOR OTHER
    REASONS. "Now I am finally motivated to learn it" passes; bespoke machinery
    invented for this one design fails. When someone calls a candidate simpler,
    check whether they mean familiar.
  - LAWS COME ALREADY PAID FOR UNDER EXACTLY THREE PROVISOS: the specification
    is in homomorphic form, equality is semantic (a and b are equal exactly
    when their meanings are), and the type stays abstract. A leaked constructor
    voids the transfer.
  - A FAILED MORPHISM IS A FINDING, NOT A DEFEAT. Diagnose it and repair the
    model, choosing the repair that improves overall simplicity. An equation
    that will not close is the method's most valuable output.
  - EVIDENCE CEILINGS ARE DECLARED, NOT INFERRED. Every artifact states what its
    passing does not prove.
  - Where the semantically right meaning is not computable and you substitute
    the computable neighbour, RECORD THE WART and name the declined
    alternative. Never take that move silently, and never for a whole object.|]

-- | The admission test, asked before any phase runs.
--
-- /Source:/ @SKILL.md@'s @## When to use, and when not@, whole: the
-- infinite-expressiveness admission test, the applications amnesty, the list of
-- fragments to refuse, the reason (\"those fragments are not /denotative/ — the
-- meaning of an expression does not depend only on the meanings of its
-- components\"), and the honest carve-out clause.
--
-- __Asked as a flag, of a laterally served party.__ A flag is what an admission
-- test is, and the party is not the one that would go on to do the design work —
-- a designer asked whether the thing in front of it is worth designing has an
-- interest.
admissionBrief :: Text
admissionBrief =
  [wft|
  Before anything else: is this subject one the denotational design method
  should be applied to at all?

  The positive admission test is INFINITE EXPRESSIVENESS -- a vocabulary whose
  values compose into unboundedly many more values: a library, a
  DSL-as-library, a compiler, a runtime, a protocol. Design a vocabulary, not a
  language: a domain-independent host language plus an embedded domain
  vocabulary, and only the second is reinvented. When only one type in a design
  carries composition, that is the one type to denote.

  Say NO if the subject is I/O glue, config parsing, log formatting, a
  migration script, test scaffolding or build tooling. The reason is not effort
  budget: those fragments are not DENOTATIVE -- the meaning of an expression
  does not depend only on the meanings of its components -- so there is no
  compositional meaning for a meaning function to be a homomorphism over. The
  antidote is the usual one: make the effects into values, interpret them with
  one driver at the edge, and denote the values.

  Applications get amnesty. Applications are quite rigid and you do not expect
  to be systematic about them.

  Two things this test is NOT. It is not a paradigm line drawn by scale or
  layer -- "a functional core and an imperative shell" is not a reading of this
  method and must never be cited as one. And it is not a judgment about
  difficulty: a subject conceived operationally is harder, not out of scope,
  and its opening move is different (write down the denotation the code already
  implicitly has, defects included).

  Answer yes if the method applies. Answer no if it does not, and a no ends the
  run here.|]

-- | Phase 1 — the principal mathematical object.
--
-- /Source:/ @references\/dialog-protocol.md@ phase 1, including its facilitation
-- mechanics (\"ask for bad answers by name\", \"collect every candidate without
-- ranking, then price each with precision\"), its scoring rubric, its artifact
-- and all five of its exit tests.
objectBrief :: Text
objectBrief =
  [wft|
  Phase 1 -- the principal mathematical object.

  Take the subject's types and operation signatures as RAW MATERIAL, explicitly
  un-meant. Nobody yet knows what they mean; this is a process of clarifying
  ideas. Refuse only one question: how do we implement it. How is an answer,
  what is a question, and "how do we implement WHAT?"

  State the scoring rubric before offering any candidate. A mathematical model
  must be ADEQUATE (it can express what the domain and its users need), SIMPLE
  (you can reason with it practically and reliably) and PRECISE (so that you
  really have simplicity and adequacy rather than only believing you do).
  Minimality is NOT a specification goal -- that is bought later, in the
  operation vocabulary and the representation, never by narrowing the semantic
  domain first.

  Work it this way, and the order matters:

  1. Enumerate candidate meanings, INCLUDING BAD ONES, and say so: every
     suggestion is illuminating, for its strengths or its weaknesses or both.
     Do not rank while collecting.
  2. Price each candidate with precision, because many ideas are simple only
     because they are not precise -- made precise, their complexity becomes
     apparent. Name each candidate's baggage.
  3. Pick one, in a semantic domain whose mathematics ALREADY EXISTS for other
     reasons: functions, monoids, semirings, linear maps, sets, complete
     partial orders. That is a menu and not a boundary, and "go learn it" is a
     passing answer.
  4. Record the SUBTRACTIONS: everything the sketch mentioned that the meaning
     does not, and the level at which each removed thing will reappear as a
     REPRESENTATION rather than as meaning.

  Your artifact: one line giving the object's name, shape and definition; the
  candidate board with each candidate's baggage; and the subtraction list.

  Then apply the exit tests and report each one's outcome:

  (a) the definition fits on a line, and it may be non-computable;
  (b) the IDENTITY TEST -- the domain's most primitive observation denotes the
      identity function. This discriminates for container-shaped candidates and
      passes vacuously when the primitive observation IS the meaning function;
      where it is vacuous, fall back to the adequate/simple/precise triad plus
      the forcing criterion -- do the chosen meaning's operations become nearly
      forced by type-checking alone?
  (c) a value can be said to BE something without mentioning any
      representation;
  (d) the CLOSURE TEST -- the object is built out of things of its own kind,
      without bound;
  (e) REACH AND HARD-TO-VARY -- the model explains more than it was built for,
      and no part of it can be changed freely while it still works.

  IF THIS IS A RETROFIT of an existing codebase, the opening move is different
  and this is where it happens. First write down the denotation the code ALREADY
  IMPLICITLY HAS, defects included. Expect it to be ugly; the ugliness is the
  evidence. Retrofit one type, not the system. Then the defect inventory
  licenses TWO verdicts and you must choose between them explicitly:

    - repair: these defects are fixable, and here is what each costs;
    - or start over: this is basically unfixable, and the inventory has shown
      clearly what mistakes were made in the past.

  A retrofit that ends in a documented start-over recommendation HAS SUCCEEDED.
  If that is your verdict, say so rather than forcing a repair, and make the
  FIRST LINE of your answer exactly

    START OVER

  followed by the defect inventory that licenses it and what a greenfield
  design would do differently. Nothing after this phase will be asked, and that
  is the correct outcome, not a failure of the engagement.|]

-- | Phase 2 — the fundamental operations.
operationsBrief :: Text
operationsBrief =
  [wft|
  Phase 2 -- the fundamental operations on that object.

  The model's vocabulary IS the API, verbatim: you take the language the
  mathematics wants to talk about and you make that your API. The user's story
  and the implementer's obligation list are the same list.

  For each operation: is it forced by the object's structure, or is it a
  documented need? Name it by its standard algebraic class -- functor,
  applicative, monoid, semiring, monad, comonad, category -- and write the
  semantic equation, because the SHAPE OF THE WRITTEN EQUATION is what makes
  the standard instance visible.

  Put semantic choices -- a bias, a direction, which monoid -- into VISIBLE
  WRAPPER TYPES in the semantic domain, never into a hand-written instance and
  never into a comment.

  Then RECOGNIZE, THEN DELETE: every bespoke name where a standard class
  supplies one goes, and the class it collapses into is named.

  Your artifact: the operation set, each operation either a class method or
  carrying a one-line justification for its bespoke existence, plus the list of
  classes the type inhabits.

  Exit test: no bespoke name remains where a standard class supplies one, and
  each class choice names why the weaker alternative does not suffice and why
  this is the weakest that does -- OR records the open question. "At least a
  semiring, possibly just a monoid, I am not sure exactly where the line is" is
  an acceptable answer when it is RECORDED, and it goes on the non-theorems
  list.|]

-- | Phase 3 — the fundamental theorems, and the non-theorems.
lawsBrief :: Text
lawsBrief =
  [wft|
  Phase 3 -- the fundamental theorems on that object and those operations.

  Equations with downstream force: a law is worth stating when something later
  depends on it. For each one give an ID from a single-letter family, the
  statement, what downstream it forces, and -- for a retrofit -- which defect
  in the inventory it descends from.

  Then write the explicit NON-THEOREMS LIST: the plausible-but-false properties
  nobody should assume. No exchangeability, no continuity, no compositionality
  of one thing over another. A property left off both lists is a property
  somebody will assume the convenient direction of.

  Your artifact: the law table (ID, statement, downstream force, defect
  lineage) plus the non-theorems list.

  Exit test, and it is the diagnostic for a skipped denotation: LAWS ARE
  LEMMAS-TO-BE FROM A DENOTATION, NOT AXIOMS ABOUT AN IMPLEMENTATION. Using
  algebraic properties AS the specification, rather than as lemmas that follow
  from a denotational specification, is the mistake -- Kepler's laws against
  Newton's. If any law here is an axiom about an implementation, say so and say
  what denotation it should be a lemma of.|]

-- | Phase 4 — the derived layer.
derivedBrief :: Text
derivedBrief =
  [wft|
  Phase 4 -- derived operations and theorems. This phase is exploration, and its
  value is subtraction.

  Run RECOGNIZE, THEN DELETE again over everything invented in phases 2 and 3.
  Let the composition rule dictate interface shape -- extra outputs, argument
  order -- rather than convention.

  Your artifact: the derived-layer notes. What came free from the classes; what
  became IMPOSSIBLE and is therefore not a gap; which obligations collapsed
  into others; and which dilemmas DISSOLVED because the construct that forced
  the choice is gone.

  One standing warning for this phase. THE DERIVED VOCABULARY IS A COMPILATION
  TARGET, NOT A USER INTERFACE. A point-free or categorical form is where
  reinterpretation becomes possible, not where people write. Keep the friendly
  surface -- lambdas, ordinary functions -- and generate the target form
  mechanically. A GENERATED graph, tape or matrix is fine and is often the
  payoff; requiring the USER to construct one when the host language can express
  the thing directly is the defect.|]

-- | The worksheet: the living document the phases produce and the exit tests
-- revise.
--
-- /Source:/ @SKILL.md@'s @## The worksheet@ and @assets\/design-worksheet.md@ —
-- \"the worksheet's sections mirror the phases, so an empty section is a visible
-- unmet obligation rather than an absence nobody notices\". That sentence is why
-- this is one artefact and one loop rather than ten: an unmet obligation is
-- visible because it is a hole in a document, and a document is the thing a
-- reviewer reviews.
worksheetBrief :: Text
worksheetBrief =
  [wft|
  Assemble the design worksheet for the meaning half of this design: phases 1
  through 4, as one living document.

  One section per phase, in order, each holding that phase's artifact in full
  and nothing else:

  1. The principal mathematical object -- the one-line definition, the
     candidate board with each candidate's baggage, the subtraction list with
     the level each subtracted thing will reappear at, and the outcome of each
     of the five exit tests.
  2. The fundamental operations -- the operation set, the class list, and the
     semantic equation for each operation.
  3. The fundamental theorems -- the law table with IDs, and the non-theorems
     list.
  4. The derived layer -- what came free, what became impossible, what
     collapsed, what dissolved.

  Two rules about the shape, and they are the reason this document exists.

  AN EMPTY SECTION STAYS EMPTY AND SAYS SO. Do not fill a gap with plausible
  text: a visible unmet obligation is the point of the worksheet, and a
  plausible filler is an obligation nobody will ever notice again.

  DO NOT IMPROVE THE PHASES WHILE ASSEMBLING THEM. If you disagree with a
  phase's answer, add a line under it beginning "OPEN:" and leave the answer
  alone. A worksheet silently edited during assembly is a worksheet whose
  review reviewed something nobody wrote.|]

-- | What the exit-test judge is told.
--
-- /Source:/ every phase's @__Exit test__@ line in
-- @references\/dialog-protocol.md@, gathered, plus @SKILL.md@'s
-- \"do not advance a phase without its artifact\" and its instruction that the
-- failure-diagnosis table is \"the part to have open when an equation resists\".
--
-- __The judge is not the author.__ See the module header, item 4.
exitBrief :: Text
exitBrief =
  [wft|
  You are reviewing a denotational design worksheet against the exit tests of
  the phases that produced it. You did not write it. Apply the tests; do not
  rewrite the design.

  Phase 1 -- the object:
    (a) the definition fits on a line, and may be non-computable;
    (b) the identity test holds, or is vacuous and the forcing criterion is
        answered instead;
    (c) a value can be said to BE something without mentioning a
        representation;
    (d) the closure test -- the object is built out of things of its own kind;
    (e) reach and hard-to-vary.
    And: is the semantic domain's mathematics PRE-EXISTING, or was it invented
    for this design and given a name? The pre-existence clause is what makes
    the simplicity claim falsifiable, and a bespoke object pointed at by a
    name fails it.

  Phase 2 -- the operations: no bespoke name remains where a standard class
  supplies one; each class choice names why the weaker alternative does not
  suffice and why this is the weakest that does, or records the open question.

  Phase 3 -- the theorems: the laws are lemmas-to-be from a denotation and not
  axioms about an implementation. A law that is an axiom about an
  implementation is the diagnostic for a skipped denotation, and it is an
  objection.

  Phase 4 -- the derived layer: what came free is named, and nothing invented in
  phases 2 or 3 survives that a standard class supplies.

  And two tests across the whole document:

  - Every subtraction phase 1 recorded reappears at exactly one named level, or
    is marked as not yet placed. A subtraction that reappears nowhere is a
    capability the design has quietly dropped.
  - The type defines equality THROUGH ITS MEANING. A type that does not has no
    meaning function, whatever the candidate is called.

  Objecting is the useful outcome here, not the harsh one: a morphism that will
  not close is this method's most valuable output, and the repair is a design
  finding. Say WHICH test failed and WHAT the repair would be -- and choose the
  repair that improves overall simplicity rather than the one that is nearest.

  Do not object to a recorded open question. "I am not sure exactly where the
  line is", written down and on the non-theorems list, is a passing answer by
  the method's own rule.|]

-- | What the author is told on a repair trip.
reviseBrief :: Text
reviseBrief =
  [wft|
  A reviewer applied the phases' exit tests to your worksheet and objected.
  Produce the next version of the worksheet and nothing else -- the same
  sections in the same order, no commentary about what you changed.

  Repair the MODEL, not the prose. If the objection is that a law is an axiom
  about an implementation, the repair is a denotation the law follows from. If
  it is that a bespoke name survives, the repair is the class that supplies it.
  If it is that the object's mathematics was invented here, the repair is a
  different object in mathematics that already exists.

  Where a repair is genuinely not available, do not weaken the specification to
  make the objection go away. Say what the obstruction is, under a line
  beginning "OPEN:", and leave the section honest. A design with a named open
  problem is a result; a design whose specification was loosened until every
  test passed is not.

  And where you take the computable neighbour of a meaning that is not
  computable, RECORD THE WART and name the alternative you declined.|]

-- | Phase 5 — the candidate fan, then the tower.
representationsBrief :: Text
representationsBrief =
  [wft|
  Phase 5 -- candidate representation objects: first the fan, then the tower.

  ENUMERATE candidate representations before picking one, and enumerate them
  DELIBERATELY RADICALLY DIFFERENT -- radically different ways to implement the
  interface, every one of which respects the denotation. The plurality is the
  payoff and not a survey step: a non-operational meaning is what lets one
  denotation carry an interpreter, a code generator and a radically transformed
  representation at once. A fan of one is a sign the meaning was chosen
  operationally.

  Then pick, and say why: adequacy admits, efficiency vetoes, simplicity
  decides.

  Then the tower, from the mathematical object down to the final realization.
  For each level, define its boundary POSITIVELY and NEGATIVELY:

    "nothing above level k may mention floats, devices, or time"
    "nothing below level j may introduce a user-visible knob"

  The negative clauses are what convert a violation from a matter of taste into
  a diagnosable specification defect.

  Your artifact: the candidate fan with the pick recorded; the level table with
  its negative boundary clauses.

  Exit test: EVERY subtraction phase 1 recorded reappears at exactly one named
  level, or in exactly one named peer backend. Report each one and where it
  landed.|]

-- | Phase 6 — the meaning functions between levels.
denotationsBrief :: Text
denotationsBrief =
  [wft|
  Phase 6 -- denotations between representations.

  Give each level a NAMED meaning function into the level above it -- `at`,
  `occs`, `pred`, `force`, `value_at`. Naming it is much of the work. Each is
  compositional, and each may be uncomputable; that is not a defect and is
  often the point.

  Then compose them, and state the end-to-end denotation from the bottom
  representation to the mathematical object. The composed type is the design's
  correctness statement, and it should be one line.

  Assign an AUDIENCE to each edge of every square you will state in phase 8:
  the user reads the top, the implementation does the bottom, and correctness
  ties them. A specification file with two audiences is doing two jobs and
  should be split.

  Your artifact: per level, the named meaning function's signature and
  definition, plus the composed end-to-end statement.|]

-- | Phase 7 — the operations per representation, solved.
--
-- /Source:/ phase 7 of the protocol, whose first bullet is a literal __Gate__ —
-- and which is why the whole second half of this program stands where it does.
operationsPerRepBrief :: Text
operationsPerRepBrief =
  [wft|
  Phase 7 -- typed operations per representation, SOLVED from the homomorphism
  equations rather than written and checked.

  The gate this phase stands behind has already been passed: the meaning
  function for each level is written, which is what makes each equation have
  exactly one unknown. Without it there are three.

  For each level and each operation, write the homomorphism equation with the
  meaning function on both sides and the representation's operation as the
  single unknown, then SOLVE it. Every solution is correct; the choice among
  solutions is the efficiency work, and it comes after.

  Keep the derivations. Read backwards, they ARE the proofs, and they are the
  minimum viable proof artifact for a design with no prover.

  Your artifact: per level, the operation definitions, each traceable to the
  equation that forced it; the best REJECTED candidate per operation; and any
  warts recorded with the alternative declined.

  Two exit tests, and the second is an audit you must actually perform rather
  than assert:

  - No operation was written first and checked second. If one was, say which,
    and solve it.
  - Every argument on the right-hand side of every semantic equation is either
    wrapped in the meaning function or RECORDED as a deliberately meaning-free
    primitive. An un-denoted argument is either an accepted primitive or an
    unnoticed hole, and you must say which for each one.

  When an equation will not close, that is a finding. Diagnose it, name the
  repair, and never weaken the specification to make it close.|]

-- | Phase 8 — the commuting squares, in a prover.
squaresBrief :: Text
squaresBrief =
  [wft|
  Phase 8 -- the commuting theorems: statements and proofs, in {prover}.

  State one commuting square per adjacent-level operation pair. The square's
  STATEMENT is kernel and is human-reviewed; its PROOF is checker-validated and
  is never human-reviewed. That division is the whole reason a prover is here.

  Run counterexample search BEFORE proof, so false laws die cheaply.

  Fix the AXIOM POLICY: the short, public, versioned list of seams where the
  mathematics is allowed to end, and what empirically covers each gap. Refuse
  to claim a theorem the substrate cannot support.

  Your artifact: the square statements as {prover} declarations; the obligation
  ledger, one row per law ID with its status; and the axiom policy.

  Exit test: every needed observation factors through the denotations, and no
  junk states are representable IN ANY REPRESENTATION -- or the junk is named.
  Scope that clause carefully: junk in the SEMANTIC DOMAIN, meanings that
  nothing expressible will ever denote, is usually a deliberate purchase of
  simplicity and headroom rather than a defect, and has occasionally been a
  prediction. Junk in a representation is a defect.

  The prover is an amplifier and not a constituent: if this design has few
  levels, few hands, and laws whose proofs are one-liners, say that a comment
  plus a property test is the proportionate home for these statements, and do
  not manufacture a formalization to fill this section.|]
  where
    prover :: Text
    prover = "the chosen proof assistant"

-- | The closing: the four completion tests, the elimination list, and what
-- resisted.
closingBrief :: Text
closingBrief =
  [wft|
  Close the engagement. You did not do the design work below; you are auditing
  it against the method's own completion tests and then stating the result to a
  skeptical practitioner.

  Run the four completion tests and report each one's outcome:

  1. Every type's meaning is stated in one line.
  2. Every operation's meaning is forced by a WRITTEN morphism equation, and no
     bespoke names remain.
  3. Nothing is left to prove: the laws hold by morphism, the types are
     abstract, and the remaining proofs are lemmas from the denotation.
  4. Efficiency lives elsewhere, as refinement of an UNMOVED denotation.

  Then the negative test, and it is the one that catches a design that looks
  finished: DOES IT MORPHISM-CHECK, not merely type-check?

  Then produce the ELIMINATION LIST: the standard machinery of this field that
  the finished design never needed -- no graphs, no tapes, no tags, no mutation,
  whatever the field's usual apparatus is. It is the exit-side counterpart of
  phase 1's subtraction list, and it is how the result is stated to somebody
  who does not already believe the method.

  Finally, record WHAT RESISTED: types with no semantic morphism, equations that
  did not close, structural evidence ceilings. Publish them as open problems.
  Some types may resist the discipline entirely, and the honest move is to
  publish the exception rather than to pretend the morphism holds.

  One thing you must not do: do not upgrade an impression into a measurement. If
  an efficiency claim in this design has no measurement behind it, label it an
  impression. The method's own author labels his that way.|]

-- ---------------------------------------------------------------------------
-- The provenance lines
-- ---------------------------------------------------------------------------

-- | The arm where the method does not apply.
notAdmittedNote :: Text
notAdmittedNote =
  [wft|
  Outcome: NOT A DENOTATIONAL DESIGN ENGAGEMENT. The admission test answered no:
  this subject is not a composing vocabulary whose values build unboundedly many
  more values, and the full method would ask a proof assistant to certify
  something that has no compositional meaning to preserve. That is the skill's
  own ruling and it is a real answer, not a refusal. Report the proportionate
  minimum it prescribes instead: name the mathematical object such of it as
  there is, write one line of the meaning function, and stop. Say plainly that
  this is the effort budget talking and NOT method doctrine -- a denoted core
  with an undenoted shell is not a reading of this method, and this ending must
  never be cited as licence for one.|]

-- | The arm where a retrofit's own defect inventory says to start again.
startOverNote :: Text
startOverNote =
  [wft|
  Outcome: START OVER, AND THAT IS A SUCCESSFUL RETROFIT. The opening move of a
  retrofit is to write down the denotation the code already implicitly has,
  defects included, and the inventory that came back licenses two verdicts
  rather than one. This run's verdict is the second: the existing model is not
  worth repairing, and the inventory has shown clearly what mistakes were made.
  Report it as a result -- the skill is explicit that a retrofit ending in a
  documented start-over recommendation has succeeded -- and do not soften it
  into a repair plan. No representation, no proof and no realization work was
  done, on purpose: there is nothing yet to represent. What the report owes the
  reader is the defect inventory, the one line each defect costs, and what a
  greenfield design would do differently.|]

-- | The arm where the meaning settled and the whole tower was built.
settledNote :: Text
settledNote =
  [wft|
  Outcome: THE MEANING SETTLED, AND THE REPRESENTATIONS FOLLOW FROM IT. The four
  meaning phases produced a worksheet that a reviewer on another engine approved
  against every phase's own exit tests, and only then were representations,
  meaning functions, solved operations, commuting squares and realizations asked
  about at all -- which is phase 7's own gate expressed as reachability rather
  than as a rule. Report the worksheet as the design of record and the second
  half as what the equations forced. Two things the report must carry verbatim:
  the elimination list, because it is how this result is stated to a skeptic,
  and what resisted, because an unpublished exception is a claim that the
  morphism holds everywhere.|]

-- | The arm where an equation was still open when the rounds ran out.
openNote :: Text
openNote =
  [wft|
  Outcome: THE MEANING HAS AN OPEN EQUATION. The reviewer still objected after
  every repair trip this run was given, so the worksheet below is the one the
  last trip produced and the final review objected to -- no trip was spent
  answering that last objection. NO representation, proof or realization work
  was done, and that is the method working rather than failing: meaning
  constrains implementation, so a design whose meaning is unsettled has nothing
  to represent yet. Report the outstanding objection FIRST, verbatim, then the
  worksheet, then the repair the reviewer named. A morphism that will not close
  is this method's most valuable output; the next session starts from that
  equation and not from a blank page.|]

-- | The arm where the reviewer would not judge the worksheet.
--
-- Named @unjudgedNote@ and not @blockedNote@ because
-- @'Workflows.Escalation.blockedNote'@ is the generic one this tree already has
-- and "Workflows.Prelude" re-exports it: the specific note wins here and the
-- name says so.
unjudgedNote :: Text
unjudgedNote =
  [wft|
  Outcome: THE EXIT TESTS WERE NOT APPLIED. The reviewer declined to judge the
  worksheet at all, so no phase's exit test was checked by anybody but its
  author -- which is the arrangement this row exists to avoid. Report the
  worksheet as UNREVIEWED, name the four meaning phases as the author's own
  unchecked work, and do not report any exit test as passed. Nothing downstream
  ran: a design whose meaning nobody would judge is not a design whose
  representations are worth asking about.|]

-- | The third argument the two ending arms with no second half hand the report.
--
-- __Tier 1__: the arms that never reached the representation half have no
-- artefact to pass, and \"nothing\" is the wrong thing to hand a report function
-- — a reader of a report that stops at the meaning wants to be told that it
-- stopped there deliberately.
nothingBuiltNote :: Text
nothingBuiltNote =
  [wft|
  No representation, denotation, solved operation, commuting square or
  realization work exists for this run. The program does not contain a path from
  this ending to any of it: phase 7's gate -- do not begin on operations until
  the level's meaning function is written -- is expressed here as reachability,
  and this ending is outside the arm the second half stands in. Report the
  absence as a fact about the run and not as a gap in the design.|]

-- ---------------------------------------------------------------------------
-- The function
-- ---------------------------------------------------------------------------

-- | What the report is written through.
denoteReportBrief :: Text
denoteReportBrief =
  [wft|
  Write the design document for a denotational design engagement. It is read by
  whoever will implement against this design, and by whoever will be skeptical
  of it.

  Open with the provenance line you were given, verbatim, on its own line. It is
  the run's own account of how far the design got and it is not yours to soften
  -- in particular, if it says the meaning did not settle, do not present the
  document as a finished design.

  Then, from the work below and nothing else:

  - the design worksheet, section by section, exactly as it stands. Do not
    re-edit it here: it has been through the review it is going to get, and a
    change made at this point has been checked by nobody. An empty section
    stays empty.
  - the representation tower, the meaning functions, the solved operations and
    the commuting squares -- where the run produced them, and the provenance
    line says whether it did.
  - the elimination list.
  - what resisted, as open problems, with the reason each one resisted.

  Two things you must not write. Do not fill an empty worksheet section: a
  visible unmet obligation is the artefact working, and a plausible filler is an
  obligation nobody will notice again. And do not describe an unmeasured
  efficiency claim as a measurement -- label it an impression, which is what the
  method's own author does with his.

  Then reply DONE with the path you wrote.|]

-- | One act, five provenance lines.
--
-- Three parameters, in the order the body reads them: the provenance first, for
-- "Workflows.Report"'s reason; then the worksheet, which is the design of record;
-- then the representation half, which two of the five endings do not have and
-- which they therefore hand 'nothingBuiltNote'.
denoteReportFn :: Fn '[ 'CodeText, 'CodeText, 'CodeText] 'CodeAck
denoteReportFn =
  function
    "denote.report"
    ( takes @"provenance" Text
        . takes @"worksheet" Text
        . takes @"tower" Text
        $ noParams
    )
    \provenance worksheet tower -> W.do
      act reporter [wf|
          {writing}

          Provenance:

          {provenance}

          The design worksheet -- the meaning:

          {worksheet}

          The representation tower and what followed from it:

          {tower}

          Write the document, then reply DONE.|]
      done
  where
    writing = denoteReportBrief

-- | The table 'denoteProgram' hands @'Agentic.Workflow.defining'@.
denoteTable :: [SomeFn]
denoteTable = [SomeFn denoteReportFn]

-- ---------------------------------------------------------------------------
-- The program
-- ---------------------------------------------------------------------------

-- | The admission test, the meaning, the exit tests — and the representations
-- only through them.
--
-- Four inputs. @subject@ is the API sketch or the codebase under retrofit;
-- @method@ is the seven reference files and the worksheet skeleton as an
-- @--input-file@ (1,921 lines and 209 more, which are data and not prompt bulk);
-- @prover@ is Lean 4, Rocq or Agda, read once in Haskell so it cannot be
-- re-litigated mid-dialog; @realization@ names the foreign language phase 10
-- would bisimulate against, and an empty one is a design where phase 10 does not
-- exist.
--
-- The shape, top to bottom: put the admission test and stop if the answer is no;
-- run the four meaning phases as a chain, each spliced with the artefacts before
-- it; read the retrofit's start-over verdict for nothing and end there if it
-- came; assemble the worksheet; hand it to a reviewer on another engine under
-- every phase's exit tests, bounded; and __only in the arm where that settled__
-- ask about representations, meaning functions, solved operations, commuting
-- squares and realization. Then close, and report.
--
-- __Five endings, five provenance lines, one__ 'denoteReportFn' — except the
-- not-admitted arm, which reports through @'Agentic.Workflow.ask_'@ because it
-- has neither a worksheet nor a tower, and a call with two empty arguments would
-- be a report about nothing shaped like a report about something.
denoteProgram :: Parameterized
denoteProgram =
  taking (input "subject" :> input "method" :> input "prover" :> input "realization" :> noInputs)
    \subject method proverArg realizationArg ->
      -- Tier 1, twice: which prover the squares are stated in, and whether phase
      -- 10 exists at all. Both are ordinary Haskell over the invocation, so
      -- neither costs a question and neither adds a path.
      let prover = proverOf proverArg
          realizing = realizationBrief realizationArg
       in defining denoteTable W.do
            -- The admission test, before the body. A `no` here is the cheapest
            -- correct answer this program has.
            applies <- confirm (lateral (model "denote-admission")) [wf|
                {admitting}

                The subject:

                {subject}|]

            if applies
              then W.do
                -- Phase 1. The chain starts here, and every phase below splices
                -- what came before it, because a phase whose predecessor it
                -- cannot see is a phase about nothing.
                object <- ask (reasoning (model "denote-object")) [wf|
                    {phase1}

                    {rules}

                    The subject:

                    {subject}

                    The method's own reference material, which is authoritative
                    where this brief is brief:

                    {method}|]

                -- The retrofit's second licensed verdict, read for nothing.
                overable <- tested startOverRecommended object

                if overable
                  then W.do
                    call_ denoteReportFn (arg startOverNote :> arg object :> arg nothingBuiltNote :> noArgs)
                    stop
                  else W.do
                    ops <- ask (reasoning (model "denote-operations")) [wf|
                        {phase2}

                        {rules}

                        The object this design is about:

                        {object}|]

                    laws <- ask (reasoning (model "denote-laws")) [wf|
                        {phase3}

                        {rules}

                        The object:

                        {object}

                        The operations:

                        {ops}|]

                    derived <- ask (broad (model "denote-derived")) [wf|
                        {phase4}

                        {rules}

                        The object:

                        {object}

                        The operations:

                        {ops}

                        The theorems and non-theorems:

                        {laws}|]

                    -- The living document. One artefact, so there is one thing
                    -- for the exit tests to be tests OF.
                    worksheet <- ask (reasoning (model "denote-worksheet")) [wf|
                        {assembling}

                        Phase 1 -- the principal mathematical object:

                        {object}

                        Phase 2 -- the fundamental operations:

                        {ops}

                        Phase 3 -- the theorems and non-theorems:

                        {laws}

                        Phase 4 -- the derived layer:

                        {derived}|]

                    -- The exit tests, on another engine, with a bound. This is
                    -- the loop `doc/design.md` §7.4 row 6 sketches ten of; see
                    -- the module header for why there is one.
                    reviewed <-
                      escalating
                        (lateral (model "denote-exit"))
                        exitBrief
                        (reasoning (model "denote-object"))
                        reviseBrief
                        worksheet
                        (atMost 2)

                    case reviewed of
                      SettledOn meaning -> W.do
                        -- Phase 5 onwards. Reachable only from here, which is
                        -- phase 7's Gate as a property of the printed program.
                        reps <- ask (reasoning (model "denote-representations")) [wf|
                            {rules}

                            {phase5}

                            The meaning this design must not move:

                            {meaning}|]

                        denotations <- ask (reasoning (model "denote-denotations")) [wf|
                            {rules}

                            {phase6}

                            The meaning:

                            {meaning}

                            The representation tower:

                            {reps}|]

                        solved <- ask (reasoning (model "denote-solve")) [wf|
                            {rules}

                            {phase7}

                            The meaning:

                            {meaning}

                            The tower:

                            {reps}

                            The meaning functions between its levels:

                            {denotations}|]

                        squares <- ask (reasoning (model "denote-squares")) [wf|
                            {rules}

                            {phase8}

                            The proof assistant this design uses: {prover}.

                            The meaning functions:

                            {denotations}

                            The solved operations:

                            {solved}|]

                        empirical <- ask (broad (model "denote-realization")) [wf|
                            {realizing}

                            The meaning:

                            {meaning}

                            The tower and its meaning functions:

                            {denotations}

                            The solved operations:

                            {solved}|]

                        closed <- ask (lateral (model "denote-closing")) [wf|
                            {closing}

                            The worksheet -- the meaning:

                            {meaning}

                            The tower:

                            {reps}

                            The meaning functions:

                            {denotations}

                            The solved operations:

                            {solved}

                            The commuting squares and the axiom policy:

                            {squares}

                            The empirical layer:

                            {empirical}|]

                        call_ denoteReportFn (arg settledNote :> arg meaning :> arg closed :> noArgs)
                        stop
                      UnsettledOn meaning -> W.do
                        call_ denoteReportFn (arg openNote :> arg meaning :> arg nothingBuiltNote :> noArgs)
                        stop
                      AbandonedOn meaning -> W.do
                        call_ denoteReportFn (arg unjudgedNote :> arg meaning :> arg nothingBuiltNote :> noArgs)
                        stop
              else W.do
                ask_ reporter [wf|
                    {notAdmitted}

                    The subject the admission test was put about:

                    {subject}|]
  where
    rules = groundRules
    admitting = admissionBrief
    phase1 = objectBrief
    phase2 = operationsBrief
    phase3 = lawsBrief
    phase4 = derivedBrief
    assembling = worksheetBrief
    phase5 = representationsBrief
    phase6 = denotationsBrief
    phase7 = operationsPerRepBrief
    phase8 = squaresBrief
    closing = closingBrief
    notAdmitted = notAdmittedNote

-- ---------------------------------------------------------------------------
-- The registry's two other columns
-- ---------------------------------------------------------------------------

-- | The one line @wf list@ prints beside this row.
denoteDoc :: Text
denoteDoc =
  "denotational-design/SKILL.md: the meaning first, its exit tests judged elsewhere, and representations reachable only through them"

-- | The page @wf help denote@ prints under the computed header
-- ('Agentic.Cli.rowHelp').
--
-- __The @realization@ bullet states a fact about the /shape/ of the run__, not
-- about a default: an empty one is a design in which the last phase does not
-- exist, which is a different program and not a phase quietly skipped. An
-- operator who reads it as "left blank, so it will do something sensible" will
-- expect a bisimulation that was never in the plan, and @wf plan denote --raw@
-- is where he could have seen so.
--
-- __It states no price.__ The header above it carries the numbers off the same
-- 'Agentic.Plan.Facts' @wf list@ publishes.
denoteHelp :: Text
denoteHelp =
  [wft|
  `skills/denotational-design/SKILL.md` as a program: the meaning first, its
  exit tests judged by somebody who did not propose it, and the representation
  tower reachable **only** through those tests. The phases are a chain and not
  ten independent loops, which is what keeps a ten-phase design method finite.

  **Inputs.**

  * `subject` — the API sketch, the library, or the codebase being retrofitted:
    what is to be given a meaning. It is the subject of every phase.
  * `method` — the skill's reference files and worksheet skeleton as an
    `--input-file`: *data* the phases are held to, not bulk prepended to a
    prompt. This is what makes "follow the method exactly" checkable.
  * `prover` — Lean 4, Rocq or Agda. It is read **once**, in ordinary Haskell,
    so the choice cannot be re-litigated mid-dialog by a party that would rather
    use something else. Empty is the corpus's own default, printed by the plan.
  * `realization` — the foreign language the last phase would bisimulate the
    design against. An empty one is a design in which **that phase does not
    exist** — a different program, not a skipped step.

  **Transport.** Fine anywhere: it is a long dialog that produces documents and
  proof obligations, and it writes no file of yours unless you give it
  `--scratch "$PWD"` and mean to keep the worksheet. An adapter of the run's own
  is the usual shape.

  ```sh
  wf run denote --engine acp --adapter claude --require-pinned \
     --input-arg subject='the workflow cost algebra' \
     --input-file method="$HOME/.claude/skills/denotational-design/SKILL.md" \
     --input-arg prover=lean --input-arg realization=rust
  ```

  **Rehearsal.** All four inputs named empty, every question answered from the
  row's own canned table, consulting nobody:

  ```sh
  wf run denote --scripted --input-arg subject= --input-arg method= \
     --input-arg prover= --input-arg realization=
  ```

  **Caveats.**

  * **The cheapest ending is the admission test answering *no*.** A subject this
    method should not be applied to costs two questions and stops there, which
    is the correct answer and the one the skill's own "when not to use it"
    section is written to produce. Read it as the method working.
  * A retrofit whose own defect inventory says to start over is a **successful**
    retrofit here, and it is nearly as cheap. Neither of those endings is a
    failed run.
  * The phases are a chain: each reads the handle the last one bound, so there
    is no order in which they could run but this one, and a representation
    cannot be reached without the exit tests that admit it.
  |]

-- | The canned replies a @--scripted@ run answers from, keyed by prefix.
--
-- __The keys are the defines themselves__, so each is a prefix of the rendered
-- prompt by construction — and __that is why each phase's brief stands before
-- 'groundRules' in its question and not after it__. The ground rules are the
-- standing context every phase carries, so they would read naturally at the top;
-- put there, they would be a prefix of /every/ phase question, and one canned
-- answer would serve all eight. The brief goes first, the rules follow it, and
-- each phase has a key of its own. This is the same arrangement
-- @'Workflows.Tron.stageClosing'@ arrives at from the other direction — the
-- varying part goes after the brief so the key stays fixed.
--
-- The phases the table does __not__ carry a row for fall through to
-- @'Agentic.Exec.scriptedDefault'@, which echoes the prompt. That is deliberate:
-- what a phase of this dialog produces is a page of mathematics, and a canned
-- page of mathematics here would be a design nobody wrote.
--
-- __The phase-1 row is the load-bearing one, and it is load-bearing for an
-- unobvious reason.__ 'objectBrief' tells a retrofit to make @START OVER@ the
-- first line of its answer, and an echoed prompt /contains that instruction on a
-- line of its own/ — which
-- @'Workflows.Deciders.startOverRecommended'@ reads exactly as it would read the
-- verdict. So without this row the rehearsal walks the start-over ending instead
-- of the design, having asked three questions. With it, the run walks the whole
-- tower. Deleting the row rehearses the other arm, and both exit 0.
--
-- The rest of the table is the questions whose answers the program /reads/:
--
--   * 'admissionBrief' answers @yes@, so the body runs. @\"no\"@ reaches the
--     not-admitted terminal.
--   * 'exitBrief' answers @APPROVE@, which is the settled arm. An @OBJECTION:@
--     reaches @UnsettledOn@ and an empty answer reaches @AbandonedOn@.
--
-- __The approval is the bare word__, for @'Workflows.Transcribe.transcribeScript'@'s
-- reason: @Agentic.Text.approvesB@ approves only a reply that /is/ an approve word
-- and nothing else, so a row carrying the word and a sentence would rehearse the
-- unsettled arm while claiming the settled one.
--
-- All five endings exit 0, and each of the other four is one line away from this
-- table.
denoteScript :: [(Text, Text)]
denoteScript =
  [ (admissionBrief, "yes"),
    (objectBrief, objectAnswer),
    (exitBrief, "APPROVE"),
    (reviseBrief, objectAnswer),
    (worksheetBrief, worksheetAnswer)
  ]
  where
    -- Deliberately does NOT open a line with `START OVER`: the scripted run
    -- designs, and the retrofit's other verdict is reached by changing this
    -- row's first line.
    objectAnswer =
      [wft|
      The object is a SCHEDULE, and its meaning is a function from time to the
      set of tasks live at that time:

        meaning of a Schedule = Time -> Set Task

      Candidate board: a list of intervals (baggage: an ordering nobody needs,
      and two representations of the empty schedule); a difference of sets
      (baggage: no way to say when); the function above (baggage: not
      computable, which costs nothing because we only compute with
      representations).

      Subtractions: the interval list reappears at level 2 as a representation;
      the calendar's time zone reappears at level 3, which is the bottom,
      because approximation belongs after composition.

      Exit tests: (a) one line, non-computable, fine. (b) the identity test is
      vacuous -- the primitive observation IS the meaning function -- so the
      forcing criterion answers instead, and the operations are forced by
      type-checking. (c) yes. (d) closure holds: a schedule is built out of
      schedules. (e) reach: the model explains recurrence, which it was not
      built for.|]

    worksheetAnswer =
      [wft|
      # Denotational design worksheet

      ## 1. The principal mathematical object
      meaning of a Schedule = Time -> Set Task. Candidate board and subtractions
      as recorded in phase 1.

      ## 2. The fundamental operations
      Monoid (union, pointwise), Functor over Task, and a shift that is an
      action of the additive group of time. No bespoke names survive.

      ## 3. The fundamental theorems
      S1 union is associative and commutative (from Set). S2 shift distributes
      over union. Non-theorems: shift does NOT distribute over intersection with
      a bounded window; there is no total ordering on schedules.

      ## 4. The derived layer
      `during`, `never` and `always` all came free from the monoid and the
      functor. OPEN: whether the semiring is the right home for the windowed
      product is not settled.|]
