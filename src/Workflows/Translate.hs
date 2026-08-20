-- |
-- Module      : Workflows.Translate
-- Description : The translation team — one draft, six lenses in priority order,
--               and a bound on the loop the corpus leaves open.
--
-- == The map: old Markdown -> new program
--
-- +-------------------------------------------+---------------------------------------------------------------+
-- | @~\/src\/nix\/config\/ai@                 | here                                                          |
-- +===========================================+===============================================================+
-- | @skills\/persian\/SKILL.md@               | @translate@ — English into Persian: the five phases, with      |
-- |                                           | phase 3's review /team/ as a panel                             |
-- +-------------------------------------------+---------------------------------------------------------------+
-- | its @### Phase 3: Team Review@ (six       | 'teamRoster' — six lenses, in the __priority order phase 4     |
-- | @Task@ calls, spawn order arbitrary)      | gives__ rather than the spawn order, because the fold is       |
-- |                                           | noncommutative and the priority list is what it encodes        |
-- +-------------------------------------------+---------------------------------------------------------------+
-- | its @### Phase 4: Synthesis@ and its      | @'Agentic.Workflow.revisingOn'@ at                             |
-- | \"run Phase 3 again on the synthesis\"    | @'Agentic.Workflow.atMost' 2@ — the loop the file states and   |
-- |                                           | never bounds                                                   |
-- +-------------------------------------------+---------------------------------------------------------------+
-- | @agents\/persian-translator.md@           | 'registerBrief' (the lead translator's identity) and           |
-- |                                           | 'bahaiGlossary' (its 52 established terms, as one define)      |
-- +-------------------------------------------+---------------------------------------------------------------+
-- | its closing paragraph (\"double-check by  | the @fidelity@ lens — the back-translation, and the one seat   |
-- | translating back into English\")          | on a different serving model                                   |
-- +-------------------------------------------+---------------------------------------------------------------+
-- | @skills\/persian\/TERMS.csv@              | @'Agentic.Workflow.input' \"glossary\"@ — authoritative, and    |
-- |                                           | it outranks 'bahaiGlossary' by a stated rule                   |
-- +-------------------------------------------+---------------------------------------------------------------+
-- | @skills\/persian\/PersianTerms.txt@       | __deliberately absent__; see the third honest note             |
-- +-------------------------------------------+---------------------------------------------------------------+
-- | @skills\/persian\/Translations\/@         | @'Agentic.Workflow.input' \"references\"@ — the four reference  |
-- |                                           | letters as an @--input-file@                                    |
-- +-------------------------------------------+---------------------------------------------------------------+
-- | its last line (\"for Persian-to-English   | @translate-en@ — the same body, the directions swapped, and    |
-- | translation, reverse the process\")       | the external @translate-en@ skill's edge transplanted rather   |
-- |                                           | than its text                                                  |
-- +-------------------------------------------+---------------------------------------------------------------+
-- | @prompts\/spanish.md@                     | @translate-es@ — 'translateFn' called once, and the answer      |
-- |                                           | /is/ the artefact                                              |
-- +-------------------------------------------+---------------------------------------------------------------+
--
-- The Markdown was read as __data__. Nothing in @~\/src\/nix\/config\/ai@ is
-- modified by this module, and no party in it points at that tree.
--
-- == The leveling-up, item by item
--
--   1. __The conflict-resolution priority list becomes the fold order, so it
--      cannot drift from the fan-out.__ @persian\/SKILL.md@ spawns its six
--      reviewers in one order and then resolves their conflicts in another, and
--      the second list is the load-bearing one: meaning fidelity first,
--      terminology second (\"mandatory, non-negotiable\"), aesthetics last.
--      @'Agentic.Workflow.panel'@ folds right in the __noncommutative__ verdict
--      monoid, so 'teamRoster' is written in the priority order and the first
--      objection a run reports is the highest-priority one, by construction. The
--      file's own list has already drifted once — @beauty-eloquence@ appears at
--      both rank 5 and rank 7 — and one table is what ends that.
--
--   2. __The loop is bounded.__ \"Once this is completed, run Phase 3 again on
--      the synthesis, and then come back here to phase 4 to produce the final
--      synthesis\" is a loop with no exit condition and no count.
--      @doc\/design.md@ §7.3 calls this \"the cleanest @revising@ in the corpus\"
--      and it is: candidate = the translation, review = the panel, amendment =
--      the synthesis, bound = @atMost 2@. @wf cost translate@ says what two
--      rounds of a six-seat review costs before a word is translated.
--
--   3. __The team dissolves.__ Phase 3 step 1 is @TeamCreate@, step 3 is \"wait
--      for all teammates to respond\", and phase 5 step 4 is \"shut down the team
--      by sending shutdown_request messages to all teammates, then use
--      TeamDelete\". None of that has a referent here: a panel is a fan-out and
--      not a resource, nothing is allocated, and there is nothing to leak if the
--      run ends early. Three of the file's twelve numbered steps are lifecycle
--      management for a thing this program does not have.
--
--   4. __The reviewers are given the whole glossary, not the relevant slice.__
--      Phase 1 asks for \"a __terminology brief__: a compact list of only the
--      relevant English-Persian term pairs\", and phase 3 hands that brief to all
--      six teammates. But the @terminology@ lens's own mandate is \"correct use
--      of __ALL__ mandatory terminology\" — and a reviewer checking /all/ of a
--      list somebody else filtered for relevance is checking the terms that were
--      already thought of. That is exactly how a terminology violation escapes.
--      Here the compact brief goes to the __drafter__, where filtering is a
--      drafting aid, and the reviewers get 'bahaiGlossary' and the @glossary@
--      input in full. Context economy was the only reason to filter, and it is
--      the cost this repository exists to stop paying in judgment.
--
--   5. __\"Do not show the user intermediate drafts, individual reviews, or
--      back-translations\" is an absence.__ 'translateReportFn' is handed the
--      provenance, the final translation and the source — and __not__ the review
--      verdicts, which are not in its scope. The prohibition is not a rule the
--      writing turn is trusted with; it is the argument list.
--
--   6. __A phrase does not buy a six-seat review.__ \"If the source text is very
--      short (a single sentence or phrase), you may skip the team process\" is a
--      permission the corpus grants and cannot act on. 'shortSource' is ordinary
--      Haskell over the invocation — tier 1, zero questions, __zero paths__ — and
--      it reduces the roster to the one seat that still matters at that length:
--      the back-translation. Six consultations become one, and the shape of the
--      program is unmoved.
--
--   7. __\"Use the @opus@ model with @max@ effort for ALL review team members\"
--      is a pin, and @--require-pinned@ enforces it.__ Five of the six seats are
--      @'Workflows.Parties.reasoning'@, whose primary is @opus@. The sixth is
--      not, and that is the corpus's own distinction: the back-translator is the
--      one teammate it gives @subagent_type: general-purpose@ rather than
--      @persian-translator@, because its job is an /independent/ reading of
--      meaning. It is @'Workflows.Parties.lateral'@ here, which is a different
--      primary, and the one seat where independence of judgement — not merely of
--      context — is what the seat is for. The other five share a backend with
--      each other and with the drafter; that is what the file asks for, and
--      @'Workflows.Confer.conferProvenance'@'s caveat applies to them verbatim.
--
-- == Three honest notes
--
-- __@translate-en@'s skill is external, so its edge is transplanted and not its
-- text.__ @translate-en@ is a plugin skill the owner has installed elsewhere and
-- it is not in this corpus; what /is/ in the corpus is @persian\/SKILL.md@'s own
-- last line — \"for Persian-to-English translation, reverse the process: you
-- draft the English, and reviewers check English quality, fidelity, and Baha'i
-- terminology in English\" — plus the one-line register the external skill names,
-- which is the elevated register of Shoghi Effendi. The @En@ direction is those
-- two sentences and nothing invented on top of them. That is
-- @'Workflows.Review.Ladder.ponytailLens'@'s arrangement: transplant the edge,
-- and let the owner's own files say what the rubric is.
--
-- __@PersianTerms.txt@ is not an input, and that is the point.__ The skill's own
-- warning is that it \"is a raw PDF extraction and contains text artifacts —
-- broken lam-alef ligatures … stray bidirectional control characters, and
-- scrambled layout\", that it must be used \"only to look up which accepted term
-- corresponds to an English phrase\", and that Persian text must \"never\" be
-- copied from it verbatim. A file no party in this program can read is a file
-- nothing can be copied from. The lookup it was useful for is 'bahaiGlossary',
-- which is the same terms typed once, in a source file a reviewer can proofread.
--
-- __@doc\/design.md@ §7.4 assigns @prompts\/spanish.md@ to
-- @Prose.translateFn@, and the function lives here instead.__ §8 puts spanish in
-- the @translate@ family and §7.4 puts its function in the prose family; both
-- cannot be true of one binding. It is here, because this is where its callers
-- are: 'translateFn' has __three__ call sites — @translate@, @translate-en@ and
-- @translate-es@ — and a function in "Workflows.Prose.Polish" would have one
-- there and two importing across families for it. The deviation is this sentence
-- and no more; the shape §7.4 asks for is exactly what landed, which is a
-- one-argument-per-hole @'Agentic.Workflow.function'@ over the corpus's clearest
-- existing @$ARGUMENTS@.
{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QualifiedDo #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE RebindableSyntax #-}
{-# LANGUAGE TypeApplications #-}

module Workflows.Translate
  ( -- * The three directions
    Direction (..),
    translateName,
    translateDoc,

    -- * The tier-1 readings of an invocation
    shortSource,
    teamRoster,

    -- * The rubrics, transplanted
    bahaiGlossary,
    registerBrief,
    termsBrief,
    synthesisBrief,
    reviewClosing,

    -- * The programs
    translateProgram,
    translateScript,

    -- * The functions
    translateFn,
    translateReportFn,
    translateTable,
  )
where

import qualified Agentic.Workflow.Do as W
import Data.String (fromString)
import Data.Text (Text)
import qualified Data.Text as T
import Workflows.Prelude
import Prelude

-- ---------------------------------------------------------------------------
-- The three directions
-- ---------------------------------------------------------------------------

-- | The three directions the owner translates in.
--
-- One program and three rows, because two of the three are the /same shape/ —
-- @doc\/design.md@ §7.4's \"one program, two directions, one glossary
-- discipline\" — and the third is a different one: @prompts\/spanish.md@ has no
-- team, no glossary and no loop, so it is one call and one artefact.
data Direction
  = -- | @skills\/persian\/SKILL.md@ — English into Persian, for the Baha'i World
    -- Centre.
    Fa
  | -- | the external @translate-en@ skill, authorised by
    -- @persian\/SKILL.md@'s own last line: Persian or Arabic into English, in
    -- the elevated register of Shoghi Effendi.
    En
  | -- | @prompts\/spanish.md@ — English into Latin-American Spanish.
    Es
  deriving (Eq, Show)

-- | The name the operator types.
--
-- The bare family name goes to the direction @doc\/design.md@ §7.4 row 17 marks
-- __T__, which is the Persian one; the other two carry their target language,
-- which is the only thing that distinguishes them.
translateName :: Direction -> Text
translateName Fa = "translate"
translateName En = "translate-en"
translateName Es = "translate-es"

-- | The one line @wf list@ prints beside a rung.
translateDoc :: Direction -> Text
translateDoc Fa =
  "persian/SKILL.md: English into Persian — six reviewers folded in the priority order the file resolves conflicts by, under a bound"
translateDoc En =
  "translate-en: Persian or Arabic into English in Shoghi Effendi's register — the same six seats, the directions swapped"
translateDoc Es =
  "prompts/spanish.md: English into elevated Latin-American Spanish — one call of `translateFn`, whose answer is the artefact"

-- | The language a rung translates __into__.
targetLanguage :: Direction -> Text
targetLanguage Fa = "Persian (Farsi)"
targetLanguage En = "English"
targetLanguage Es = "Latin-American Spanish"

-- | The language a rung translates __from__.
sourceLanguage :: Direction -> Text
sourceLanguage Fa = "English"
sourceLanguage En = "Persian or Arabic"
sourceLanguage Es = "English"

-- ---------------------------------------------------------------------------
-- The tier-1 readings of an invocation
-- ---------------------------------------------------------------------------

-- | Is this a phrase rather than a passage?
--
-- __Tier 1__ ("Workflows.Deciders"): ordinary Haskell over the invocation, zero
-- questions and __zero paths__ — it changes the roster and not the shape.
--
-- /Source:/ @skills\/persian\/SKILL.md@ @## Important Notes@: \"if the source
-- text is very short (a single sentence or phrase), you may skip the team process
-- and translate directly using your own expertise, noting that you did so.\"
--
-- __An absent text is not short.__ It is unknown, and the default is the full
-- team (house rule WR-1): @ci\/workflows.sh@ prices every row at the empty input,
-- and a rule that read @\"\"@ as a phrase would pin the price of the cheap shape
-- and run the expensive one. Twenty-five words is the boundary, which is a
-- generous reading of \"a single sentence or phrase\".
shortSource :: Text -> Bool
shortSource t = not (T.null stripped) && length (T.words stripped) < 25
  where
    stripped = T.strip t

-- ---------------------------------------------------------------------------
-- The review team
-- ---------------------------------------------------------------------------

-- | The six reviewers, __in the order phase 4 resolves their conflicts in__.
--
-- /Source:/ @skills\/persian\/SKILL.md@ phase 3 (the six mandates) and phase 4
-- (the seven-rank conflict-resolution priority). The mandates are phase 3's; the
-- /order/ is phase 4's, and the order is what a noncommutative fold needs. See
-- the module header, item 1.
--
-- __A phrase gets one seat.__ 'shortSource' reduces the roster to the
-- back-translation, which is the only one of the six whose question still means
-- something about a phrase: a single clause has no cumulative arc to build, no
-- band of registers to sit in and no cadence to carry, and it can still say
-- something other than what the source said.
teamRoster :: Direction -> Text -> Roster
teamRoster d src
  | shortSource src = [fidelityLens d]
  | otherwise =
      [ fidelityLens d,
        terminologyLens d,
        grammarLens d,
        oralLens d,
        registerLens d,
        modernLens d
      ]

-- | Priority 1 — meaning fidelity, by back-translation.
--
-- /Source:/ phase 3 teammate 5 (@back-translator@), whose three numbered steps
-- are kept in order because the order is the method: translate back /without
-- looking at the source first/, and only then compare.
--
-- __The one seat on a different serving model.__ See the module header, item 7.
fidelityLens :: Direction -> Lens
fidelityLens d =
  Lens
    { lensName = "fidelity",
      lensOwns = "whether the translation says what the source says, tested by translating it back",
      lensParty = lateral (model "translate-back"),
      lensBrief =
        [wft|
        You are performing back-translation verification, and the order of
        these steps is the whole method.

        STEP 1. Translate the {target} draft below back into {source}. Do this
        FIRST, from the draft alone. Do not read the source text until you have
        finished: a back-translation written with the source in view is a
        paraphrase of the source, and it verifies nothing.

        STEP 2. Now compare your back-translation with the source text you were
        given.

        STEP 3. Report the divergences:

        - meanings that shifted, were lost, or were added;
        - nuances present in the source and absent from the {target};
        - ambiguities in the {target} that a reader could take the wrong way;
        - passages where the meaning is preserved exactly -- say these too,
          because a divergence report with no clean passages in it is not a
          report, it is a list.

        Grade each divergence critical, major or minor. This is the
        highest-priority review of the six: where another reviewer's suggestion
        would change the meaning, meaning wins.|]
    }
  where
    target = targetLanguage d
    source = sourceLanguage d

-- | Priority 2 — terminology, which is mandatory and non-negotiable.
--
-- /Source:/ phase 3 teammate 4 (@bwc-style@) and phase 4's rank 2, which is the
-- one rank the file marks as non-negotiable.
terminologyLens :: Direction -> Lens
terminologyLens d =
  Lens
    { lensName = "terminology",
      lensOwns = "every mandatory term, and the institutional voice of the Baha'i World Centre",
      lensParty = reasoning (model "translate-terminology"),
      lensBrief =
        [wft|
        You are a specialist in the translation conventions of the Baha'i World
        Centre. Verify that this translation follows the established style,
        terminology and conventions of official translations -- particularly
        the letters of the Universal House of Justice and of the Guardian.

        Check:

        - correct use of EVERY mandatory term in the glossary you were given.
          Not the terms that seemed relevant: every one of them that the source
          or the draft touches. A terminology violation is the highest-priority
          finding you can make and it is not a matter of taste.
        - consistency with the institutional voice of the Ridvan messages and
          similar communications;
        - transliteration conventions for names and titles;
        - the treatment of quotations from the Baha'i Writings;
        - the rendering of institutional names -- Spiritual Assemblies,
          Training Institutes, Continental Counsellors and the rest;
        - overall fidelity to the distinctive institutional voice in {target}.

        Flag terminology violations first and separately from style
        suggestions. Rate terminology compliance and style fidelity out of ten
        each, and say which specific term or passage each rating turns on.|]
    }
  where
    target = targetLanguage d

-- | Priority 3 — diction and grammar.
--
-- /Source:/ phase 3 teammate 1 (@diction-grammar@), whose dual mandate is kept
-- as two paragraphs and whose grammar checklist is language-specific — so it is
-- 'grammarSpecifics', by direction.
grammarLens :: Direction -> Lens
grammarLens d =
  Lens
    { lensName = "grammar",
      lensOwns = "every word's precise semantic weight, and syntactic correctness throughout",
      lensParty = reasoning (model "translate-grammar"),
      lensBrief =
        [wft|
        You are a {target} linguistic specialist. Your mandate is two-fold and
        both halves are yours:

        DICTION. Examine every word choice. Does each {target} word carry the
        precise semantic weight of the {source} original? Are there more
        accurate or more evocative alternatives? Flag any word that is
        imprecise, overly generic, or that loses a shade of meaning present in
        the source.

        GRAMMAR. Verify syntactic correctness throughout. {specifics}

        For each issue: the location, the current text, the suggested revision,
        and the reasoning. Rate diction and grammar out of ten each. Where a
        category is clean, say so explicitly -- an unmentioned category is
        indistinguishable from an unread one.|]
    }
  where
    target = targetLanguage d
    source = sourceLanguage d
    specifics = grammarSpecifics d

-- | The grammar checklist, by direction.
--
-- /Source:/ teammate 1's own list for @Fa@, verbatim in substance — verb
-- conjugation and tense consistency, ezafe constructions, noun-adjective
-- agreement, @را@ for definite direct objects, prepositions, word order.
--
-- For @En@ the list is the corresponding one and is __not__ the Persian list
-- translated: @persian\/SKILL.md@'s reversal clause says the reviewers \"check
-- English quality\", and English has no ezafe. Nothing here is invented beyond
-- naming the ordinary apparatus of the target language.
grammarSpecifics :: Direction -> Text
grammarSpecifics Fa =
  [wft|
  Check verb conjugation and tense consistency, ezafe constructions,
  noun-adjective agreement, the correct use of را for definite direct objects,
  preposition usage, and natural word order. Flag any grammatical error or
  awkward construction.|]
grammarSpecifics En =
  [wft|
  Check tense and aspect consistency across a long period, subject-verb
  agreement through intervening clauses, the placement of restrictive and
  non-restrictive relative clauses, parallelism in coordinated series,
  antecedent clarity for every pronoun, and the punctuation of subordination.
  Flag any grammatical error, and flag a construction that is correct but
  reads as a translation.|]
grammarSpecifics Es =
  [wft|
  Check verb tense and mood -- especially the subjunctive -- gender and number
  agreement, ser against estar, preposition usage, and natural word order.|]

-- | Priority 4 — the oral and devotional reading.
--
-- /Source:/ phase 3 teammate 6 (@oral-spiritual@), whose four named dimensions
-- are kept as four named dimensions. Phase 4 ranks it fourth, above register and
-- above aesthetics, which is a real editorial judgment and is why it is a seat
-- rather than a paragraph inside another one.
oralLens :: Direction -> Lens
oralLens _ =
  Lens
    { lensName = "oral",
      lensOwns = "what a listener experiences: fluidity aloud, cadence, breath, and cumulative force",
      lensParty = reasoning (model "translate-oral"),
      lensBrief =
        [wft|
        Read this translation ALOUD in your mind -- as though it were being
        recited at a gathering or read out in a devotional setting. Judge it
        only through what a listener would experience.

        ORAL FLUIDITY. Does the language flow when spoken? Find the stumbling
        points: consonant clusters, awkward rhythmic breaks, tongue-twisting
        phrases, sentences that force the reader to stop and restart. Sacred
        text carries a listener forward on a current of sound. Flag every place
        the mouth or the ear trips.

        CADENCE AND BREATH. Are the sentences shaped for human breath? Do
        clauses land at natural pausing points? Is there a rhythm -- not meter,
        but the dignified pulse of elevated prose? Consider the interplay of
        short and long phrases, the placement of emphasis, and the rise and
        fall of the voice.

        SPIRITUAL POTENCY. Does it move the heart? Read aloud, does the hearer
        feel uplifted and drawn closer to the divine, or is the language flat
        and merely correct? Name the passages that are technically correct and
        spiritually inert; that distinction is what this seat exists for.

        CUMULATIVE IMPACT. Read the whole passage as continuous speech. Does it
        build? Does the ending resonate, or does the passage simply stop?

        For each suggestion: location, current text, suggested revision,
        reasoning. Rate oral fluidity and spiritual potency out of ten each,
        and name the passages that are particularly moving read aloud.|]
    }

-- | Priority 5 — beauty and eloquence.
--
-- /Source:/ phase 3 teammate 2 (@beauty-eloquence@). Phase 4 ranks it fifth
-- (\"register and style\") /and/ seventh (\"aesthetic preferences … lowest
-- priority\"), which is the drift one table ends: it is fifth here, and its own
-- brief carries the seventh rank's instruction — that a purely aesthetic
-- preference yields to everything above it.
registerLens :: Direction -> Lens
registerLens d =
  Lens
    { lensName = "register",
      lensOwns = "literary quality and rhetorical power: rhythm, euphony, gravitas, and a consistent register",
      lensParty = reasoning (model "translate-register"),
      lensBrief =
        [wft|
        You are a {target} literary specialist reviewing for aesthetic and
        rhetorical quality.

        BEAUTY. Evaluate the literary quality. Does it flow with natural
        rhythm? Is there euphony in the word combinations? Does the prose have
        the dignified cadence appropriate to sacred and institutional texts?
        Suggest revisions where the text is flat, mechanical or graceless.

        ELOQUENCE. Assess the rhetorical power. Does the translation convey the
        gravitas, the persuasiveness and the spiritual depth of the original?
        Is the register consistently dignified without being archaic or
        inaccessible? {registerTarget}

        One standing constraint on your own findings, and it comes from the way
        this review is resolved: a suggestion that is ONLY an aesthetic
        preference yields to meaning fidelity, to terminology, to grammatical
        correctness and to what a listener hears. Mark each of your suggestions
        as either "carries meaning" or "aesthetic", so the synthesis can rank
        them without having to guess.

        For each suggestion: location, current text, suggested revision,
        reasoning. Rate beauty and eloquence out of ten each, and name the
        passages that are particularly well rendered.|]
    }
  where
    target = targetLanguage d
    registerTarget = registerTargetNote d

-- | The register a rung's literary seat is aiming at.
--
-- /Source:/ for @Fa@, teammate 2's own sentence — \"the elevated yet clear style
-- of the letters from the Universal House of Justice\". For @En@, the one line
-- the external @translate-en@ skill names, which is the elevated register of
-- Shoghi Effendi; see the module header's first honest note for why that is the
-- whole of what is transplanted.
registerTargetNote :: Direction -> Text
registerTargetNote Fa =
  "The tone should evoke the elevated yet clear style of the letters from the \
  \Universal House of Justice."
registerTargetNote En =
  "The tone should sit in the elevated register of Shoghi Effendi's own English \
  \renderings -- formal, cadenced and exact, and never antiquarian for its own \
  \sake."
registerTargetNote Es =
  "The tone should be literary and clear, elevated without becoming ornate."

-- | Priority 6 — modern standards.
--
-- /Source:/ phase 3 teammate 3 (@modern-standards@), including its closing note,
-- which is the sentence the whole seat turns on: \"the register should be formal
-- and dignified, but the language should be living {target}, not museum
-- {target}\".
modernLens :: Direction -> Lens
modernLens d =
  Lens
    { lensName = "modern",
      lensOwns = "whether an educated reader today reads this as living language rather than as a museum piece",
      lensParty = reasoning (model "translate-modern"),
      lensBrief =
        [wft|
        You are a contemporary {target} language specialist. Ensure the
        translation uses modern conventions and is accessible to educated
        {target} readers today. Check for:

        {specifics}

        - unnecessarily complex sentence structures that could be simplified
          without losing meaning or dignity;
        - consistency with how formal {target} is actually read and written
          now;
        - the balance of formal and colloquial register. Formal is correct for
          these texts, but it must not be so elevated as to be
          incomprehensible.

        These are Baha'i institutional texts. The register should be formal and
        dignified, and the language should be LIVING {target}, not museum
        {target}.

        For each suggestion: location, current text, suggested revision,
        reasoning. Rate modernity and accessibility out of ten, and name the
        passages where formality and accessibility are well balanced.|]
    }
  where
    target = targetLanguage d
    specifics = modernSpecifics d

-- | The archaism checklist, by direction.
--
-- /Source:/ teammate 3's own two bullets for @Fa@ — archaic vocabulary, and
-- \"overly Arabic-influenced phrasing where natural Persian alternatives
-- exist\". The @En@ pair is the corresponding one for a translation into
-- English, which is where a rendering into that register actually goes wrong.
modernSpecifics :: Direction -> Text
modernSpecifics Fa =
  [wft|
  - archaic vocabulary or constructions that would sound stilted to a modern
    reader;
  - overly Arabic-influenced phrasing where natural Persian alternatives
    exist;|]
modernSpecifics En =
  [wft|
  - archaic vocabulary or inversions that read as pastiche rather than as
    register;
  - Latinate abstraction where a plain English verb carries the same weight
    with more force;|]
modernSpecifics Es =
  [wft|
  - archaic vocabulary or peninsular constructions where a Latin-American
    reader expects otherwise;
  - calques from English that a native reader would not write;|]

-- ---------------------------------------------------------------------------
-- The glossary
-- ---------------------------------------------------------------------------

-- | The established translations of the terms the corpus fixes, as one define.
--
-- /Source:/ @agents\/persian-translator.md@'s @Established translations specific
-- terms@ list, transplanted term for term. @doc\/design.md@ §7.3 asks for exactly
-- this: \"its 50-term glossary is one define\".
--
-- __@TERMS.csv@ outranks this, and the ordering is stated rather than assumed.__
-- @skills\/persian\/SKILL.md@ makes @TERMS.csv@ authoritative over
-- @PersianTerms.txt@ and says nothing about the agent file's own list, which is a
-- third source. The rule this program states, in every prompt that carries both:
-- the @glossary@ input wins, this define is the fallback for a term the input
-- does not carry, and a conflict between them is reported rather than silently
-- resolved. Three sources with no stated precedence is how a mandatory term
-- becomes a matter of opinion.
--
-- __Twelve of these terms carry @\\8204\\&@, and it is not a typo.__ That is
-- U+200C, the zero-width non-joiner, which Persian orthography uses inside a
-- compound word — @جامعه\8204\&سازی@ is one word and not two — and which GHC's
-- lexer refuses as a literal character in a string. It is written as a numeric
-- escape with the @\\&@ separator, which is exactly the character the corpus
-- file holds. Do not \"clean\" it: dropping a non-joiner joins two letters that
-- must not join, which changes the word.
bahaiGlossary :: Text
bahaiGlossary =
  bullets
    [ ("A learning mode", "شیوۀ یادگیری"),
      ("Advent of the Divine Justice", "ظهور عدل الهی"),
      ("Animators of junior youth groups", "مشوقين گروه هاى نوجوانان"),
      ("Assistant to the Auxiliary Boards", "معاون اعضای هیئت\8204\&های معاونت"),
      ("Bahá'í International Community", "جامعۀ بین\8204\&المللی بهائی"),
      ("Center for the Study of the Texts", "مرکز مطالعۀ آثار"),
      ("Chaste", "تمسك به ذيل عفت"),
      ("Children's class", "کلاس کودکان"),
      ("Cluster reflection meeting", "جلسه تاُمل و مشورت گروهی"),
      ("Community-building", "جامعه\8204\&سازی"),
      ("Continental Bahá'í Fund", "صندوق قاره\8204\&ای بهائی"),
      ("Continental Counsellor", "مشاور قاره\8204\&ای"),
      ("Convention delegate", "نماینده انتخابی برای کانونشن ملی"),
      ("Deputization", "نمایندگی- نماینده"),
      ("Devotional gathering", "جلسات دعا"),
      ("Door-to-door", "خانه به خانه"),
      ("Freedom from prejudice", "آزادی از قیود تعصبات"),
      ("Holy Day", "ایام متبرکه"),
      ("Holy life", "تقدس در زندگی فردی"),
      ("Home visit", "ملاقات خانگی"),
      ("International Convention", "كانونشن بين المللى"),
      ("International Teaching Centre", "مرکز جهانی تبلیغ"),
      ("Junior youth group", "گروه هاى نو جوانان"),
      ("Local Spiritual Assembly", "محفل روحانى محلّى"),
      ("Meaningful conversation", "گفتگوی هدفمند"),
      ("Member of the Auxiliary Boards", "عضو هیئت\8204\&های معاونت"),
      ("National Convention", "همایش(کانونشن)ملی"),
      ("National Spiritual Assembly", "محفل روحانى ملى"),
      ("Nine Year Plan", "نقشۀ نُه ساله"),
      ("Objects of learning", "موضوعات یادگیری"),
      ("Outreach", "ارتباط\8204\&گیری / فعالیت\8204\&های گسترشی"),
      ("Parental consent", "رضایت والدین"),
      ("Partisan politics", "سیاست\8204\&های حزبی"),
      ("Processes of disintegration", "فرایندهای انحلال"),
      ("Processes of integration", "فرایندهای ادغام"),
      ("Protagonists of the Plan", "مجریان نقشه"),
      ("Rectitude of conduct", "حسن رفتار"),
      ("Reflection", "تأمل"),
      ("Society-building", "جامعه\8204\&پردازی"),
      ("Study circle", "حلقۀ مطالعه"),
      ("Study circle coordinator", "هماهنگ\8204\&کننده حلقه مطالعه"),
      ("\"Study, plan, act and reflect\"", "مطالعه، برنامه\8204\&ریزی، اقدام و تأمل"),
      ("The Shrine of 'Abdu'l-Bahá", "حرم حضرت عبدالبهاء"),
      ("The Shrine of Bahá'u'lláh", "حرم حضرت بهاءالله"),
      ("The Shrine of the Báb", "حرم حضرت باب"),
      ("Training Institute", "مؤسسه آموزش"),
      ("Tutor reflection meeting", "جلسۀ مشورتی راهنمایان"),
      ("Two-fold moral purpose", "هدف اخلاقی دوگانه"),
      ("Unit Convention", "همایش(کانونشن) واحد انتخاباتی"),
      ("Universal House of Justice", "بیت العدل اعظم")
    ]

-- ---------------------------------------------------------------------------
-- The rubrics, transplanted
-- ---------------------------------------------------------------------------

-- | The lead translator's identity and standing constraints, by direction.
--
-- /Source:/ for @Fa@, @skills\/persian\/SKILL.md@'s @## Your Role as Lead
-- Translator@ and @agents\/persian-translator.md@'s opening paragraphs, which are
-- the same five sentences written twice — one value here, which is what ends the
-- duplication. For @En@, @persian\/SKILL.md@'s reversal clause plus the register
-- the external skill names. For @Es@, @prompts\/spanish.md@'s
-- @\<instructions\>@ block, verbatim in substance.
--
-- __This is 'translateFn''s first argument__, which is why it is a function of
-- the direction and not a constant: one function, three registers, three call
-- sites.
registerBrief :: Direction -> Text
registerBrief Fa =
  [wft|
  You are a multilingual translation expert rendering English texts into
  Persian (Farsi) for the Baha'i World Centre. Maintain absolute accuracy and
  profound meaning, adhering to the commonly accepted terminology of the
  letters of Shoghi Effendi and of the Universal House of Justice.

  Strike a balance between clarity and elegance: express complex ideas
  concisely yet evocatively, and avoid embellishment or loftiness that obscures
  the intended meaning. The translation must be faithful to the original intent
  and must flow naturally in Persian, accessible to its intended audience.

  Maintain deep respect for the nuances of both languages. Each translation
  aims at a harmonious blend of accuracy, clarity and elegance.

  Produce the translation and nothing else: no commentary, no notes on your
  choices, no English gloss. What you write is the artefact this run reviews.|]
registerBrief En =
  [wft|
  You are a multilingual translation expert rendering Persian or Arabic Baha'i
  texts into English. Maintain absolute accuracy and profound meaning,
  adhering to the commonly accepted terminology of the authorised English
  translations.

  Write in the elevated register of Shoghi Effendi's own English renderings:
  formal, cadenced and exact. Do not reach for archaism as a substitute for
  dignity, and do not flatten a period into a sequence of short declaratives
  because it is easier to read that way.

  The translation must be faithful to the original intent and must read as
  English rather than as a transposition. Where the source's syntax cannot be
  carried, carry its movement.

  Produce the translation and nothing else: no commentary, no notes on your
  choices, no transliteration of the source. What you write is the artefact
  this run reviews.|]
registerBrief Es =
  [wft|
  You are a Latin-American Spanish translator, spelling corrector and
  improver. Translate the text you are given into corrected and improved
  Latin-American Spanish. Replace simplified, elementary words and sentences
  with more beautiful and elegant, upper-level Latin-American Spanish. Keep the
  meaning the same, and make it more literary and clear.

  Reply with the translation and the improvements and nothing else. Do not
  write explanations, and do not comment on what you changed.|]

-- | Phase 1 — the terminology brief, which goes to the drafter.
--
-- /Source:/ @skills\/persian\/SKILL.md@ phase 1 steps 1 and 2. See the module
-- header, item 4, for why the /reviewers/ do not get the compact version.
termsBrief :: Text
termsBrief =
  [wft|
  Prepare the terminology brief for a translation that has not been drafted
  yet. Three things, in this order:

  1. Read the source text and state its register, its audience and its
     purpose, in one line each. A translation whose register was never named is
     a translation whose register is an accident.
  2. From the glossaries below, list the term pairs that the source text
     actually touches -- the compact brief the drafter will work from. Include
     a term whose CONCEPT appears even when the exact English phrase does not,
     because that is where an established rendering is most often missed.
  3. Report any CONFLICT between the two glossaries you were given: a term the
     authoritative glossary and the standing list render differently. Do not
     resolve it silently. The authoritative glossary wins, and the conflict is
     reported so that the standing list can be corrected once rather than
     worked around every time.

  Produce the brief and the conflict report. Do not translate anything here.|]

-- | What the synthesis is told on each amending trip.
--
-- /Source:/ @skills\/persian\/SKILL.md@ phase 4, whose seven-rank
-- conflict-resolution priority is the substance of this brief — and whose ranks
-- are named here in the same order 'teamRoster' is built in, so the two cannot
-- disagree.
synthesisBrief :: Text
synthesisBrief =
  [wft|
  Synthesise the reviewers' findings into the next version of the translation.
  Produce the translation and nothing else: no commentary, no change log, no
  notes about which suggestion you took.

  When the reviewers disagree, resolve by this priority, and it is not a
  guideline:

  1. MEANING FIDELITY, from the back-translation. Highest priority. A
     suggestion that reads better and says something else is refused.
  2. TERMINOLOGY COMPLIANCE. Mandatory and non-negotiable. An established
     rendering is used even where another word would be more beautiful.
  3. GRAMMATICAL CORRECTNESS.
  4. ORAL FLUIDITY AND SPIRITUAL POTENCY. The translation must move the
     hearer; a passage that is correct and inert is a passage to work on.
  5. REGISTER AND STYLE.
  6. MODERN ACCESSIBILITY.
  7. PURELY AESTHETIC PREFERENCE. Lowest priority, and it yields to every rank
     above it. A suggestion the register reviewer marked "aesthetic" is one of
     these.

  Where you decline a suggestion that a reviewer graded critical, keep a note
  of which and why -- it is the one thing the final report is allowed to say
  about the reviews.|]

-- | The closing line every reviewer is given: the source, the reference
-- material, and the two glossaries in full.
--
-- __Tier 1__, and it is why the review seats need no dossier handle: the source
-- text, the reference letters and the authoritative glossary are all program
-- /inputs/, and 'bahaiGlossary' is a define. All four are 'Data.Text.Text' before
-- the program exists, so they are spliced here and the panel's subject is the
-- candidate alone.
reviewClosing :: Direction -> Text -> Text -> Text -> Text
reviewClosing d src glossary references =
  [wft|
  The source text, in {source}:

  {src}

  The authoritative glossary. Where it and the standing list below disagree,
  THIS one wins, and the disagreement is worth reporting:

  {glossary}

  The standing list of established renderings:

  {standing}

  Reference translations in the target style, for the standard this is held to:

  {references}

  {spec}|]
  where
    source = sourceLanguage d
    standing = bahaiGlossary
    spec = verdictSpec

-- ---------------------------------------------------------------------------
-- The provenance lines
-- ---------------------------------------------------------------------------

-- | The arm where the team approved.
approvedNote :: Direction -> Text
approvedNote d =
  "Outcome: TRANSLATED AND REVIEWED. The draft was read by the review team -- \
  \meaning fidelity by back-translation, terminology, grammar, the reading aloud, \
  \register and modern accessibility -- and the panel approved the translation \
  \below within the run's bound. Report the translation as the artefact and the \
  \target language as `"
    <> targetLanguage d
    <> "`. Two sentences on what the review changed is the right amount; the \
       \reviews themselves are not in this report's scope and are not to be \
       \reconstructed. Say what this establishes: six independent readings of one \
       \draft agreed, which is the strongest thing available here, and it is not \
       \the same as a native speaker of the target language signing it off."

-- | The arm where the trips ran out.
unresolvedNote :: Direction -> Text
unresolvedNote d =
  "Outcome: NOT AGREED. At least one reviewer still objected after every \
  \synthesis trip this run was given, so the translation below is the one the \
  \last trip produced and the final review objected to -- no trip was spent \
  \answering that last objection. Do NOT present it as a reviewed translation. \
  \Report the outstanding objection FIRST, verbatim, and name the passage it is \
  \about: because the panel folds in priority order, that objection is the \
  \highest-priority one outstanding, so a fidelity or terminology objection here \
  \is a passage a human must look at before this text is used. The target \
  \language is `"
    <> targetLanguage d
    <> "`."

-- | The arm where a reviewer declined to judge.
declinedNote :: Direction -> Text
declinedNote d =
  "Outcome: NOT REVIEWED. A reviewer declined to judge the translation at all, so \
  \the panel produced no verdict and no round could help. Report the translation \
  \as UNREVIEWED, name `"
    <> targetLanguage d
    <> "` as the target language, and say plainly that only the drafter has read \
       \it. A declining seat is most often a seat that could not read the material \
       \it was given -- the source, the glossary or the reference letters -- so \
       \name which inputs this run was given and which it was not."

-- | The arm the one-call rung reports through.
--
-- /Source:/ @prompts\/spanish.md@, whose @\<instructions\>@ say to reply with the
-- correction and nothing else. There is no review team in that file and none is
-- invented: the note says so, which is what keeps this row from looking like a
-- cheaper version of its siblings.
directNote :: Text
directNote =
  "Outcome: TRANSLATED, NOT REVIEWED, AND THAT IS THE WHOLE OF WHAT WAS ASKED. \
  \`prompts/spanish.md` is an instruction block and a task: it asks for an \
  \elevated Latin-American Spanish rendering and for nothing beside it, and it \
  \names no reviewer, no glossary and no second pass. So this row is one call of \
  \the shared translation function and one artefact, and its price says so. \
  \Report the translation. Do NOT describe it as checked, and do not compare it \
  \to what the Persian and English rungs do -- those carry a six-seat review \
  \because their sources ask for one, and this one does not."

-- ---------------------------------------------------------------------------
-- The functions
-- ---------------------------------------------------------------------------

-- | The draft, as the one function all three rungs call.
--
-- /Source:/ @doc\/design.md@ §7.4's ruling on @prompts\/spanish.md@ — \"the
-- corpus's clearest existing @{name}@ hole, and a one-argument @function@\" —
-- generalised by one parameter per hole the three rungs actually vary.
--
-- Three parameters, in the order the body reads them: the register (which is the
-- translator's identity and the direction), the terminology brief (empty at the
-- rung that has no glossary), and the source.
--
-- __Three call sites, one body.__ That is what makes @translate@, @translate-en@
-- and @translate-es@ provably share a drafting turn: @rhsAsks@ prices a call at
-- the callee's own @bodyAsks@ and @graft@ splices its node rather than adding
-- one, so the sharing costs nothing and cannot drift.
translateFn :: Fn '[ 'CodeText, 'CodeText, 'CodeText] 'CodeText
translateFn =
  function
    "translate.draft"
    ( takes @"register" Text
        . takes @"terms" Text
        . takes @"source" Text
        $ noParams
    )
    \register terms source -> W.do
      draft <- ask (reasoning (model "translate-draft")) [wf|
          {register}

          The terminology you must use, where it applies:

          {terms}

          The text to translate:

          {source}|]
      answer draft

-- | What the report is written through.
--
-- /Source:/ @skills\/persian\/SKILL.md@ @### Phase 5: Delivery@ and its
-- @## Important Notes@, which together say what the reader sees: the final
-- translation, two or three sentences of what improved, and an explanation for
-- any critical issue that was not incorporated.
translateReportBrief :: Text
translateReportBrief =
  [wft|
  Write the delivery for a translation run. The reader wanted a translation;
  give them one.

  Open with the provenance line you were given, verbatim, on its own line. It
  is the run's own account of how the translation was reviewed and it is not
  yours to soften -- in particular, if it says the translation was not
  reviewed, do not present it as reviewed.

  Then, in this order:

  - the translation itself, in full, exactly as it stands. Do not re-edit it
    here: it has been through the review it is going to get, and a change made
    at this point has been checked by nobody.
  - two or three sentences on what the review improved. Two or three. Not a
    change log.
  - any critical issue a reviewer raised that was NOT incorporated, and why.

  Two things you must not write. Do not reproduce intermediate drafts,
  individual reviews or back-translations -- you were not given them, and
  reconstructing them from the translation would be inventing them. And do not
  add a note about your own confidence in the target language: the provenance
  line already says what was checked and by how many readings.

  Then reply DONE.|]

-- | One act, four provenance lines.
--
-- Three parameters: the provenance first, for "Workflows.Report"'s reason; then
-- the translation; then the source, so the delivery can say what was translated
-- without a question being spent on saying it.
--
-- __The review verdicts are not a parameter.__ That is the module header's item
-- 5: \"do not show the user intermediate drafts, individual reviews, or
-- back-translations\" is the argument list here, not an instruction.
translateReportFn :: Fn '[ 'CodeText, 'CodeText, 'CodeText] 'CodeAck
translateReportFn =
  function
    "translate.deliver"
    ( takes @"provenance" Text
        . takes @"translation" Text
        . takes @"source" Text
        $ noParams
    )
    \provenance translation source -> W.do
      act reporter [wf|
          {writing}

          Provenance:

          {provenance}

          The source text:

          {source}

          The translation:

          {translation}|]
      done
  where
    writing = translateReportBrief

-- | The table every rung hands @'Agentic.Workflow.defining'@.
--
-- Both functions, both rungs' shapes: @defining@ checks that every @call@ names a
-- function the list declared and declared earlier, and 'translateFn' is declared
-- before 'translateReportFn' because that is the order the bodies use them in.
translateTable :: [SomeFn]
translateTable = [SomeFn translateFn, SomeFn translateReportFn]

-- ---------------------------------------------------------------------------
-- The programs
-- ---------------------------------------------------------------------------

-- | One draft, six lenses in priority order, and a bound.
--
-- Three inputs at @Fa@ and @En@. @text@ is the source; @glossary@ is
-- @TERMS.csv@ as an @--input-file@ and is authoritative; @references@ is the
-- reference letters, which are what \"the target style, standards, and language\"
-- means concretely.
--
-- One input at @Es@, and that is @prompts\/spanish.md@ being honest: it has no
-- glossary and no reference corpus, so the row does not pretend to take them.
--
-- The shape at @Fa@ and @En@, top to bottom: prepare the terminology brief and
-- report any conflict between the two glossaries; call the shared drafting
-- function; hand the draft to the six-seat panel, folded in the priority order
-- the file resolves conflicts by, with the synthesis as the amendment and a bound
-- of two; and deliver whichever way the loop ended. Three endings, three
-- provenance lines, __one__ 'translateReportFn'.
--
-- The shape at @Es@: one call, one delivery. One path, and the row's price is 2.
translateProgram :: Direction -> Parameterized
translateProgram Es =
  taking (input "text" :> noInputs) \source ->
    defining translateTable W.do
      rendered <- call translateFn (arg (registerBrief Es) :> arg noGlossary :> arg source :> noArgs)
      call_ translateReportFn (arg directNote :> arg rendered :> arg source :> noArgs)
      stop
  where
    noGlossary :: Text
    noGlossary =
      "No glossary applies to this rung. `prompts/spanish.md` fixes no \
      \terminology, and inventing a term list for it would be inventing the \
      \standard it is held to."
translateProgram d =
  taking (input "text" :> input "glossary" :> input "references" :> noInputs)
    \source glossary references ->
      -- Tier 1, three times: the roster (six seats, or one for a phrase), the
      -- register the drafting function is called with, and the closing line every
      -- seat is given -- which carries the source, both glossaries and the
      -- reference letters, all four of which are Text before the program exists.
      let roster = teamRoster d source
          register = registerBrief d
          closing = reviewClosing d source glossary references
       in defining translateTable W.do
            terms <- ask (broad (model "translate-terms")) [wf|
                {preparing}

                The authoritative glossary:

                {glossary}

                The standing list of established renderings:

                {standing}

                The source text:

                {source}|]

            draft <- call translateFn (arg register :> arg terms :> arg source :> noArgs)

            -- The loop `persian/SKILL.md` states and never bounds. The review is
            -- a PANEL, which is what makes the priority list the fold order; it
            -- is written out rather than through
            -- `Workflows.Escalation.escalating` because that function's judge is
            -- one party and this one's is six.
            settled <- revisingOn draft (atMost 2) \candidate -> W.do
              verdict <- panel (asksOver roster closing candidate)
              amend
                ( ask (reasoning (model "translate-synthesis")) [wf|
                    {synthesising}

                    The translation as it stands:

                    {candidate}

                    What the reviewers said, in priority order:

                    {verdict}|]
                )

            case settled of
              SettledOn final -> W.do
                call_ translateReportFn (arg (approvedNote d) :> arg final :> arg source :> noArgs)
                stop
              UnsettledOn final -> W.do
                call_ translateReportFn (arg (unresolvedNote d) :> arg final :> arg source :> noArgs)
                stop
              AbandonedOn final -> W.do
                call_ translateReportFn (arg (declinedNote d) :> arg final :> arg source :> noArgs)
                stop
  where
    preparing = termsBrief
    synthesising = synthesisBrief
    standing = bahaiGlossary

-- ---------------------------------------------------------------------------
-- The registry's other column
-- ---------------------------------------------------------------------------

-- | The canned replies a @--scripted@ run of a rung answers from, keyed by
-- prefix.
--
-- __The keys are the defines themselves__, so each is a prefix of the rendered
-- prompt by construction: the terminology question opens with 'termsBrief', the
-- drafting turn inside 'translateFn' with @'registerBrief' d@, each seat's with
-- its own @'Workflows.Panels.lensBrief'@ (derived from the very roster the panel
-- is built from), and the synthesis with 'synthesisBrief'.
--
-- The table is built at the empty source text, which is the invocation
-- @ci\/workflows.sh@ prices and runs — and at the empty text 'shortSource' is
-- __false__, so the roster is all six seats and these keys are the six the run
-- actually asks. A real @--input-arg text=@ shorter than twenty-five words prices
-- and runs one seat instead, whose key is in this table already.
--
-- __The seats' rows are @APPROVE@ and are written rather than defaulted__, for
-- @'Workflows.Comments.commentsScript'@'s reason: a table that relies on
-- @'Agentic.Exec.scriptedDefault'@ cannot be edited into the other two arms in one
-- line. An @OBJECTION:@ on any seat reaches @UnsettledOn@ and an empty answer
-- reaches @AbandonedOn@; all three exit 0.
--
-- __And it is the bare word.__ @Agentic.Text.approvesB@ approves only a reply
-- that /is/ an approve word and nothing else, so a row carrying the word and a
-- sentence would be read as an objection carrying that sentence — and this table
-- would rehearse the unsettled arm while claiming the approved one.
-- "Workflows.Transcribe" records the same fact at its own verdict row.
translateScript :: Direction -> [(Text, Text)]
translateScript Es =
  [(registerBrief Es, "La casa de la justicia ha escrito a los amigos.")]
translateScript d =
  [ (termsBrief, termsAnswer),
    (registerBrief d, drafted),
    (synthesisBrief, drafted)
  ]
    <> [(lensBrief l, "APPROVE") | l <- teamRoster d ""]
  where
    termsAnswer =
      "Register: institutional, formal, addressed to a national community.\n\
      \Audience: Baha'i institutions and their communities.\n\
      \Purpose: to convey guidance and to call to action.\n\
      \\n\
      \Relevant terms:\n\
      \- National Spiritual Assembly\n\
      \- Nine Year Plan\n\
      \- Training Institute\n\
      \- Study circle\n\
      \\n\
      \Conflicts between the two glossaries: none in the terms this text touches."

    drafted = draftFor d

-- | The canned draft a scripted run of a rung carries.
--
-- Two sentences in the target language, which is all a rehearsal needs: what the
-- table is proving is that every branch is reachable and every question has a
-- reply, and a longer canned translation would be a longer thing to keep true.
draftFor :: Direction -> Text
draftFor Fa = "محفل روحانى ملى به دوستان نوشته است. نقشۀ نُه ساله ادامه دارد."
draftFor En = "The National Spiritual Assembly has written to the friends. The Nine Year Plan continues."
draftFor Es = "La Asamblea Espiritual Nacional ha escrito a los amigos."
