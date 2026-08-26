-- |
-- Module      : Workflows.Rubrics.Voice
-- Description : The register a document is written in — named once, where three
--               commands write in it and none of them says so.
--
-- __Provenance.__ @~\/src\/nix\/config\/ai\/skills\/it-voice\/SKILL.md@ (the
-- whole file, compressed); @commands\/narrative.md@'s @Style standard:@ block,
-- which is the same register written a second time and shorter;
-- @commands\/smooth.md@'s \"it should yet retain its exalted and high
-- character\", which is that register asked for in one clause and defined
-- nowhere.
--
-- @doc\/design.md@ §7.4 row 15 states the fold: @narrative@, @smooth@ and
-- @proofread@ \"all write in this register and none names it\". Here it is one
-- binding, and the three programs that want it splice it.
--
-- == What the compression dropped, and why
--
-- @it-voice\/SKILL.md@ is a page and a half of bullets. House rule 5 (@README@)
-- is that a rubric over roughly sixty lines is a program input and not a define,
-- so this is the operative slice: what the diction must do, what the sentences
-- must do, what the stance must do, and the list of things that must not appear.
-- Three sections are __not__ carried and each is a decision rather than an
-- omission:
--
--   * the @## Examples in register@ block (five flat\/in-register pairs) — it is
--     an illustration of the rules above it and costs a third of the prompt to
--     repeat;
--   * @## Grounding and citation@ — it is about /sourcing/, which
--     'Workflows.Account.sourcingBrief' asks a different party about, over the
--     receipts; a register rubric that also adjudicated evidence would be two
--     rules in one define;
--   * @## Structural conventions@ — it is about a /manual's/ chapter shape, and
--     none of the three callers is writing a manual.
--
-- == The @johnw@ split is decided and deliberately not written here
--
-- @doc\/design.md@ §7.4 row 16 is one of the seven reworks: @skills\/johnw@ is
-- \"two things fused — a generation rubric and a critique function\", and the
-- level-up is to split them, @johnwGenerate@ as a define and @johnwCritique@ as
-- an @'Agentic.Workflow.Fn'@ on a different @'Agentic.Workflow.servedBy'@,
-- because the model that wrote the draft is a bad judge of whether it opened
-- with a forbidden opening.
--
-- That decision stands and is not re-argued. What is not written is the code,
-- for the reason "Workflows.Parties" gives about @rocq-pro@ — \"it stays a name
-- until something calls it\". No row in waves 1–5 writes in the owner's personal
-- voice: the three callers of this module write a sitrep, a narrative and a
-- proofread, and all three are the /institutional/ register. The 487 lines and
-- two references are program inputs when a caller arrives (§7.4 row 16's own
-- ruling), and a 487-line define with no call site would be the largest unpaid
-- prompt in the tree.
--
-- Nothing in @~\/src\/nix\/config\/ai@ is modified by this module.
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}

module Workflows.Rubrics.Voice
  ( -- * The register
    itVoice,

    -- * The gate over a draft written in it
    itVoiceSelfCheck,
  )
where

import Agentic.Workflow (wft)
import Data.Text (Text)

-- | The elevated, sedate, institutionally grounded register.
--
-- /Source:/ @skills\/it-voice\/SKILL.md@ — @## Register and diction@,
-- @## Sentence architecture and rhythm@, @## Rhetorical stance and tone@ and
-- @## Avoid@, compressed to the constraints an answer can be held to. The
-- header says what was dropped.
--
-- @commands\/narrative.md@'s own @Style standard@ list is nine bullets of this
-- same register — \"calm, measured English … humane, practical, and dignified\",
-- \"avoid self-congratulation, marketing language, theatrical language, and
-- false drama\" — and it is not transcribed a second time: the two agree, and
-- the only clause of narrative's list that is /not/ about register is \"
-- distinguish fact from inference\", which is a sourcing rule and belongs to the
-- party that reads the receipts.
itVoice :: Text
itVoice =
  [wft|
  Write in an elevated, sedate, institutionally grounded register: measured,
  authoritative and formal, never casual and never promotional. The voice is
  instructional yet impersonal, grounded yet unhurried. It never sells, never
  hectors, and never raises its voice for grave material.

  Diction. Sustain one formal register throughout, and use no contractions at
  all -- write cannot, do not, need not, it is -- including inside
  instructions. Where two phrasings exist, choose the more formal one provided
  it is exact. State standing norms and the behaviour of systems as plain
  facts in the present indicative, so that a requirement reads as settled
  practice; give procedures in the bare imperative; soften recommendations
  with evaluative framings such as "does well to" or "warrants emphasis"; and
  reserve must and is to for firm obligations, letting the stated stake rather
  than the modal carry the weight. Instruct impersonally: almost never address
  the reader as "you", make roles and systems the grammatical subjects, and
  reserve direct address for the rare passage that turns on the reader's own
  judgment. Embrace technical terms and gloss each at first use. Carry logic
  with elevated connectives -- It follows that, Yet, At the same time, Rather
  than -- in place of plain so, but, also.

  Sentences. Vary length deliberately and widely: build through an occasional
  long sentence that stacks its clauses, then discharge it with a short plain
  declarative that lands one fact. Never settle into uniform length. Join a
  set of parallel provisions with semicolons inside one sentence, closing the
  series with "and" before the last member. Use the colon as a hinge from the
  general to the specific. Give em dashes defined work -- paired for an
  appositive, single and trailing for an illustration or a qualifying turn --
  and never as an all-purpose connective. Open a meaningful share of sentences
  with a fronted subordinate clause, so the governing circumstance is set
  before the main clause resolves it. Give every paragraph a thesis-first
  topic sentence, and close it on a shorter, weighted sentence that draws the
  consequence.

  Stance. Convey importance by naming the concrete consequence, never by
  intensifiers, urgency or exclamation. State risks and limitations in
  measured terms: name the condition, then a flat verdict. Bind each directive
  to the reasoning that justifies it, in the same sentence or the next. Stay
  non-promotional: state every trade-off as plainly, and in the same neutral
  register, as the benefit beside it. Address the reader as a capable steward.
  Resolve a line of reasoning into a compact, understated maxim rather than a
  flourish.

  Do not use: marketing verbs or superlatives -- leverage, empower, unlock,
  seamless, powerful, robust, best-in-class; any contraction; a promise of
  durability or future-proofing; an over-promise of ease, speed or
  completeness; a throat-clearing opener; a decorative triad; the inflating
  antithesis "not just X, it is Y"; anonymous authority such as "studies show"
  or "experts agree"; an exclamation point; a figurative flourish the argument
  has not earned; or condescension of any kind.|]

-- | @it-voice@'s own closing checklist, as the brief of a question put to
-- somebody else.
--
-- /Source:/ @skills\/it-voice\/SKILL.md@ @## Self-check before finishing@, whose
-- ten items are carried as the six that are about the register (the four about
-- grounding and structure belong to the sections this module does not carry —
-- see the header).
--
-- __Why it is a separate binding.__ §7.4 row 15 reads \"its
-- self-check-before-finishing is a @'Agentic.Workflow.confirm'@ gate over the
-- draft\", and a gate is a question put to a party. In the corpus the checklist
-- is ticked by whoever wrote the draft, which is the same defect
-- @commands\/meeting-notes.md@ has and "Workflows.MeetingNotes" names: a discipline
-- audited by its own author is not audited. So this text is written to be read
-- by a /second/ party, and every caller in this tree puts it to one whose
-- primary is not the writer's.
itVoiceSelfCheck :: Text
itVoiceSelfCheck =
  [wft|
  Check the draft below against the register it was written in. You did not
  write it, and that is why you are being asked.

  - No contraction remains anywhere, including inside instructions.
  - No marketing verb, superlative, exclamation point or anonymous authority
    appears.
  - Sentence length visibly varies: there is no run of same-length sentences,
    and the enumerations are not all triads.
  - Em dashes do only appositive, illustrative or qualifying-turn work.
  - Standing norms and system behaviour read as present-indicative fact;
    procedures read as bare imperatives; heavier modal force is reserved for
    firm obligations.
  - Instruction stays impersonal, and direct address appears only where the
    reader must exercise personal judgment.

  Quote the offending sentence in every objection. A verdict without a
  quotation is not checkable by the person who has to act on it.|]
