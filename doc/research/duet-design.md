# The duet: two panes, one `wf`

*A design for `run.routes`, a finer independence gate, and the row that uses
both — one work session, one partner session, driven by a single invocation
that owns neither.*

---

## 0. The ruling, and what this answers

The owner's ruling, 2026-08-20 (US-Pacific; 2026-08-21 UTC), verbatim:

> 1. I start two sessions in agent-deck, one codex session, one claude session.
>    I get them primed and ready. 2. I run a single wf which starts up a wiggum
>    loop in the codex session based on the goal I passed as an argument, and a
>    partner-reviewer loop in the claude session. If wiggum needs to 'drive'
>    either or both of these sessions, it can do so, but I still retain the
>    freedom to read and interact with both of them myself, also. In this way wf
>    is the driver, but it's not the governor or controller. I don't want to use
>    ACP here, because I don't want wf 'owning' the session, which might continue
>    on long after the wiggum loop has completed its initial work.

Three things follow, and only the third is new work.

**The transport already does what the ruling asks.** `--session <id>` sends into
a live `agent-deck` pane somebody else started; `Agentic.AgentDeck` holds no
connection, spawns no process, and cannot end a session
(`haskell/src/Agentic/AgentDeck.hs:27-45` — three commands, `send`, `show`,
`output`, and nothing else). A run that finishes leaves both panes exactly as it
found them, still attached, still the owner's. That is the ruling's "driver, not
governor" and it is the existing deck engine's own shape.

**Routing to two panes already parses and already dispatches.**
`--route NAME=deck:<id>` is in the grammar (`Agentic/Route.hs:180-234`), the
header prints the table (`Agentic/Cli.hs:1327-1385`), and `routedWorld`
dispatches on the question's model axis (`Agentic/Route.hs:340-341`). Nothing in
the transport layer needs to be built.

**What is missing is the program's ability to know.** A workflow that must
assert "the judge is somewhere the work is not" has exactly one runner-supplied
fact to read — `run.engine` — and that fact says *how many conversations there
are*, never *which question lands in which*. So `wiggum` takes the only sound
reading available to it and refuses every deck run flat
(`src/Workflows/Wiggum.hs:1371-1379`). Under a two-pane split that refusal is
now wrong: the judge's pane genuinely has not read the work's questions, and the
program has no way to say so.

This design adds the fact, refines the gate over it, and writes the row that
needs both.

---

## 1. `run.routes` — the fourth reserved input

### 1.1 What it is

**The run's route table, as the runner resolved it, in the words the header
prints.** One line per answerer: the label, ` = `, and the backend's own
spelling.

```
(default) = deck:0f3a91c2-codex
partner = deck:7b2e40aa-claude
```

It is a run fact for the same reason the other three are: it is a property of
the command line, known before the first question is put, and no command line
may bind it. It joins `run.backends`, `run.engine` and `run.sentinel` under
`Agentic.Workflow.runFacts`.

### 1.2 What it is not, and why the division is clean

`run.backends` already names the distinct backends this run reaches
(`Cli.hs:1532-1547`). `run.routes` says *which pin reaches which* — the mapping,
not the roster. The two are not redundant: `run.backends` is deduplicated and
carries no names, and no arithmetic over it can answer "does the judge share a
conversation with the worker".

`run.engine` says whether an answerer opens a new conversation per question
(`Cli.hs:1553-1573`, `Workflow.sessionPolicy`). `run.routes` cannot say that and
must not try: two pins routed to one `acp:` adapter share a *process* and not a
*conversation*, because `acpFreshPerQuestion` is `True`
(`Agentic/Acp.hs:415`, `:1345`). So:

> **`run.routes` says where a question goes. `run.engine` says whether going
> there means sharing.** A gate needs both, and neither derives the other.

### 1.3 The exact spelling

**Left-hand side.** The label. Either `routeDefaultLabel` — the literal
`(default)` — or a serving-model name exactly as `--route` named it. Parentheses
because a route NAME is a serving model and a bare `default` could in principle
collide with one; `(default)` cannot be produced by any `--route` the CLI would
accept for a program that does not pin a model literally called `(default)`, and
it reads as a label rather than a name.

**Separator.** ` = `. Read back by splitting on the **first** `=` and trimming
both halves — the same rule `parseRoute` uses (`Route.hs:227-234`), because a
backend value may contain `=` (a path) and a label never does.

**Right-hand side.** `Agentic.Route.backendSpelling` and nothing else. That
function is documented as the printed inverse of `parseBackend`
(`Route.hs:203-215`), so the fact round-trips: a gate that reads it is reading
the operator's own word, not a second rendering of it.

**Order.** The default first, then `routeNamed` in the order the operator typed
— identical to `routeBackends`' order (`Route.hs:308-309`) and to
`sayManyBackends`' (`Cli.hs:1328-1332`), so an operator can read the fact
against the header against their own command line.

**When it is empty.** Exactly when there is no table: `--scripted`, and the two
static verbs, which bind no run fact at all.

> **One departure from the brief, stated.** The brief specified "empty on
> unrouted runs". This design does not: a run with `--session A` and no `--route`
> still has a default answerer, and `(default) = deck:A` is the single line that
> makes §2's gate decidable for the case it most needs to refuse (decision-table
> row 4 — an unrouted deck run, where judge and worker both fall to the default).
> Omit the default line and that row becomes indistinguishable from row 6, the
> owner's own split. Empty means *no table*, not *no `--route`*.

### 1.4 The agent-cat change list

**`haskell/src/Agentic/Workflow.hs`**

| where | change |
|---|---|
| `:2086-2087` | `runFacts = [runFactBackends, runFactEngine, runFactRoutes, runFactSentinel]` |
| new, beside `:2097` | `runFactRoutes :: Text; runFactRoutes = "run.routes"` |
| `:2052-2060` | a fourth bullet in the haddock, saying what §1.2 says |
| new, beside `oneSessionPhrase` (`:2127-2128`) | `routeDefaultLabel :: Text; routeDefaultLabel = "(default)"` |
| new, beside `sharesOneSession` (`:2150-2151`) | `routedBackend :: Text -> Text -> Text` |

`routedBackend` is the fact's one machine-readable question, and it lives here
for `sharesOneSession`'s reason, stated at `:2104-2109`: **three readers, one
spelling** — the runner that prints the fact, the header that announces the same
table, and the program that gates on it must be reading one sentence. A
workflow that wrote its own line-splitter would be a gate that stopped agreeing
with the header the moment the separator was reworded.

```haskell
-- | __The backend a pin reaches__, from a @run.routes@ value: the line that
-- names it, else the default line, else the empty text when the table is empty.
--
-- The empty answer is the honest one and not a failure: @plan@, @cost@ and
-- @--scripted@ have no table, and a gate over an unbound fact must decide the
-- shape a run with an unknown table would take.
routedBackend :: Text -> Text -> Text
routedBackend table name =
  case lookup name rows of
    Just b -> b
    Nothing -> maybe "" id (lookup routeDefaultLabel rows)
  where
    rows = [(T.strip l, T.strip (T.drop 1 r)) | ln <- T.lines table,
                                                let (l, r) = T.breakOn "=" ln,
                                                not (T.null r)]
```

**`haskell/src/Agentic/Cli.hs`**

| where | change |
|---|---|
| `:1523-1530` `runFactsOf` | a fourth pair, `(runFactRoutes, routesFact)` |
| new, in `runFactsOf`'s `where` | `routesFact`, below |
| `:1500` | "All three are properties of the command line" → four |
| `:1508-1514` | a sentence on what `run.routes` is worth to a prompt |
| `:76-83` | the three-name list in the module haddock → four |
| **`:1905-1907`** | **the only hard-coded count the binary prints**: `"There are three"` / `"— run.backends, run.engine and run.sentinel —"` |
| `:120-133` | the `--json` object sketch: add the `pins` key (§1.5) |

```haskell
    -- Derived from the very table the header prints, and from nothing else:
    -- the same `routeDefault`-then-`routeNamed` order, and `backendSpelling`
    -- for every right-hand side, so the fact round-trips through `parseBackend`
    -- and an operator can read it against their own command line.
    routesFact = case target of
      Scripted -> ""
      Routed rr ->
        T.unlines
          [ label <> " = " <> backendSpelling b
          | (label, b) <-
              (routeDefaultLabel, routeDefault (rrRoutes rr))
                : routeNamed (rrRoutes rr)
          ]
```

Note what `routesFact` does **not** do: it does not deduplicate. `routeBackends`
deduplicates because a header that counted route lines would overstate how many
agents a run started (`Route.hs:296-301`); this fact is the *mapping*, and two
pins on one backend is precisely the thing §2's gate must be able to see.

**The refusal list needs no edit.** Both refusals build their wording from
`runFacts` itself — `input` at `Workflow.hs:2024-2031` and `runFactRefusal` at
`:2161-2172` — so a fourth name appears in both sentences the moment the CAF
grows. `reservedInput` is a prefix test (`:2040-2041`) and is already total over
`run.*`. The one place a count is written out in words is `Cli.hs:1905-1907`,
above.

**Docs in agent-cat**: `haskell/ci/policies.sh:74-75` (the "thirty-four checks"
prose), and any `doc/research/pal-subsumption/*.md` that enumerates the three
facts.

### 1.5 One more additive key, for the Emacs front end

`plan --json` today emits `runFacts` — the facts a program *declares* — but
nothing about the models it *pins*, so a front end cannot know that a row is
routable, let alone under which names. Add:

```
,"pins":["worker","partner"]     the `served by` primaries and their spares
```

from `Agentic.Chains.servedChains`, sorted, `[]` on an ill-defined table (the
run is about to refuse it in its own words — `Cli.hs:518-520`). Adding a key is
explicitly not a breaking change (`Cli.hs:113-115`), and it is the one fact
`wf.el` needs to offer per-pin pane selection (§5.2).

### 1.6 Predicted gate movements

| gate | today | after | why |
|---|---|---|---|
| `haskell/ci/policies.sh` prose, `:74-75` | "Thirty-four checks" | ~forty | one new `pureProbe` group in `test/PolicyProbe.hs` for `routedBackend` / `routeDefaultLabel` |
| `haskell/ci/policies.sh:95-112` | one shell check, `run.engine` refused | two | the same check at `--input-arg run.routes=`, asserting `"is a run fact: the runner binds it"` |
| `haskell/test/PolicyProbe.hs` | 20 probe groups | 21 | round-trip: `routedBackend (routesFact t) n == backendSpelling b` for every `(n,b)` in `t`, plus the default fall-through, plus `""` on the empty table |
| `haskell/ci/deck.sh` | 7 scenarios | 8 | §6.1 |
| `haskell/ci/examples.sh` | unchanged | unchanged | no example declares a run fact |
| `haskell/ci/tier0.sh`, `tier1.sh` | unchanged | unchanged | run facts are inputs; no static fold reads a prompt (`Workflow.hs:2070-2075`), so no corpus number moves |
| agent-workflows `README.md:163-172` | "Three input names are the runner's… Twelve rows declare one or more" | four names, thirteen rows | one new row, plus `wiggum` gaining `run.routes` (§2.4) |
| `ci/workflows.sh` | 71 `pin` lines | 72 | §3.6 |

**No count is machine-asserted anywhere.** Every "three" and every "71" in both
repositories is prose, and prose is what the fess and comment audits check, not
the shell gates. That is exactly the failure mode `haskell/ci/policies.sh:55-63`
warns about for `oneSessionPhrase`, and the same care applies here: the numbers
must be swept by hand, and this table is the sweep list.

---

## 2. The finer gate

### 2.1 Why the blanket refusal is now wrong

`wiggum`'s first gate is one line:

```haskell
case sharesOneSession engine of
  True  -> defining wiggumRefusalTable W.do …   -- Wiggum.hs:1372-1379
  False -> defining (wiggumTable …) W.do …
```

and `sharesOneSession` is an `isInfixOf` over the whole engine fact
(`Workflow.hs:2150-2151`), deliberately reading a *mixed* run as `True`: "one of
the answerers this run reaches has read everything else it was asked, and a
program that needs a separate evaluator cannot tell which of them it got"
(`:2137-2141`).

That last clause is the sentence that expires. With `run.routes` bound, a
program *can* tell which of them it got. The refusal is still right for every
command line it was written for; it is wrong for exactly one new one, and that
one is the owner's.

### 2.2 The predicate

Tier 1 throughout: ordinary Haskell over two `Text` inputs, taken before the
`Program` exists, so it costs zero questions and zero paths and selects between
two programs rather than two paths (the argument at `Wiggum.hs:1303-1311`,
unchanged).

```haskell
-- | __Is the judge reachable in a conversation no work-side question touches?__
--
-- Two clauses, and the first is the one that has always been there.
--
--   (a) No answerer this run reaches shares one conversation with the rest of
--       it. Under `--engine acp` every question opens a `session/new`, so the
--       judge has read nothing whatever the routes say — and an unbound fact
--       reads as `False` here, which is what lets `plan`, `cost` and
--       `--scripted` price and rehearse the loop rather than the refusal.
--
--   (b) The judge's backend is not the work's, and is not the default. The
--       second conjunct is not a belt-and-braces: this row pins its own asks,
--       but it *calls* functions whose pins belong to other rows (§3.3), and an
--       unpinned-by-this-row question takes the default (`Route.hs:284-289`).
--       A judge sitting on the default is a judge that read the commit
--       decomposition, the conflict resolution and the cleanup review.
judgeIsElsewhere :: Text -> Text -> Text -> Text -> Bool
judgeIsElsewhere routes engine judgePin workPin =
  not (sharesOneSession engine)
    || (judge /= work && judge /= dflt)
  where
    judge = routedBackend routes judgePin
    work  = routedBackend routes workPin
    dflt  = routedBackend routes routeDefaultLabel
```

It lives in `src/Workflows/Deciders.hs` (or a new `Workflows.Routing`), exported,
and **both** `wiggum` and the duet call it — for `sessionPolicy`'s reason again:
two gates spelled twice are two gates that stop agreeing.

### 2.3 The decision table

`J`, `W`, `D` are `routedBackend` at the judge pin, the work pin and
`(default)`. `S` is `sharesOneSession engine`.

| # | invocation | `run.routes` | `run.engine` | `S` | J / W / D | verdict |
|---|---|---|---|---|---|---|
| 1 | `wf plan`, `wf cost` | *(unbound)* `""` | *(unbound)* `""` | `False` | `""` / `""` / `""` | **accept** — (a). Prices the loop, which is the shape that keeps every check |
| 2 | `run --scripted` | `""` | `scripted: a canned table, no process and no session` | `False` | `""` / `""` / `""` | **accept** — (a) |
| 3 | `run --engine acp --adapter claude` | `(default) = acp:claude` | `acp: a new session per question` | `False` | all `acp:claude` | **accept** — (a). *The unrouted acp run stays sound* |
| 4 | `run --session PANE` | `(default) = deck:PANE` | `deck: one session for the run` | `True` | all `deck:PANE` | **refuse** — (a) fails, `J == W`. *Today's behaviour, preserved* |
| 5 | `run --session PANE --route partner=deck:PANE` | two lines, one id | `deck: one session for the run` | `True` | all `deck:PANE` | **refuse** — the judge routed back onto the work's own pane |
| 6 | **the owner's split**: `run --session CODEX --route partner=deck:CLAUDE` | `(default) = deck:CODEX` / `partner = deck:CLAUDE` | `deck: one session for the run` | `True` | `deck:CLAUDE` / `deck:CODEX` / `deck:CODEX` | **accept** — (b) |
| 7 | inverted: `run --session CLAUDE --route worker=deck:CODEX` | `(default) = deck:CLAUDE` / `worker = deck:CODEX` | `deck: one session for the run` | `True` | `deck:CLAUDE` / `deck:CODEX` / `deck:CLAUDE` | **refuse** — `J == D`: every borrowed callee would have landed in the judge's pane |
| 8 | mixed: `run --engine acp --adapter claude --route worker=deck:CODEX --route partner=deck:CLAUDE` | three lines | `acp: a new session per question; deck: one session for the run` | `True` | `deck:CLAUDE` / `deck:CODEX` / `acp:claude` | **accept** — (b); three backends, all distinct |
| 9 | `run --engine acp --route partner=acp:codex` | `(default) = acp:claude` / `partner = acp:codex` | `acp: a new session per question` | `False` | `acp:codex` / `acp:claude` / `acp:claude` | **accept** — (a) |
| 10 | `run --session CODEX --route worker=deck:CODEX --route partner=deck:CLAUDE` | three lines | `deck: one session for the run` | `True` | `deck:CLAUDE` / `deck:CODEX` / `deck:CODEX` | **accept** — (b); the explicit spelling of row 6 |

Row 7 is the row that earns the second conjunct, and it is the row an operator
will actually type by accident: it *looks* like the split, it puts the worker
somewhere of its own, and it quietly leaves the commit decomposition, the
conflict resolution and the cleanup review in the pane that is about to judge
them. Refusing it is the whole reason (b) is a conjunction.

### 2.4 What this does to `wiggum`: nothing, and that is the proof

`wiggum`'s judge is `reasoning (model "done-criteria")` (`Wiggum.hs:1425`,
`:1464`) and its round account is `reasoning (model "round-account")`
(`:1101`) — the *same serving model*, `opus` (`Parties.hs:123`). So for
`wiggum`, `judgePin == workPin == "opus"`, hence `J == W` under every table
there is, hence the predicate reduces to `not (sharesOneSession engine)` — which
is `case sharesOneSession engine of True -> refuse`, word for word what
`Wiggum.hs:1371` does today.

> **The finer gate is a conservative generalization.** On the row it replaces it
> computes the same answer for every command line, because that row's judge and
> workers are pinned to one serving model and no route table can separate them.
> What changes is that a row which *does* separate them can now say so.

Consequence for `wiggum`: it declares `input "run.routes"` and calls
`judgeIsElsewhere routes engine opus opus` in place of the bare
`sharesOneSession`. Its `minFold`, `maxFold` and `paths` are unchanged — a run
fact a program only holes moves no fold (`Workflow.hs:2070-2075`), and this one
is not even holed, it is branched on in Haskell. `ci/workflows.sh:722`
(`pin wiggum branch 34 44`) does not move.

The cheaper alternative — leave `wiggum` on the blanket refusal and give only
the duet the finer gate — is rejected for `oneSessionPhrase`'s reason: two
spellings of one policy is a policy that drifts, and the drift would be silent
because both spellings pass their own tests.

### 2.5 Two constraints the gate inherits, stated so nobody has to rediscover them

**Clause (a) rests on `acpFreshPerQuestion`.** `Route.hs:302-307` already says
it: backend deduplication is safe only because two pins sharing an adapter never
share a conversation, and "any future flag exposing `acpFreshPerQuestion = False`
must either disable this or key sessions by pin". Clause (a) is the second
consumer of that promise. If the flag is ever exposed, `run.engine` will say so
(it is `sessionPolicy acpFreshPerQuestion`, `Cli.hs:1484-1485`) and `S` will
flip to `True`, at which point clause (b) carries the whole gate — which it can,
because two `acp:` routes are two distinct `Backend` values. The gate degrades
correctly on its own; it is the *deduplication* that would need fixing.

**Clause (b) rests on there being no backend-level fail-over.** `Route.hs:51-62`:
a route is a total, deterministic function of the pin, fixed for the run, and "a
route whose backend is dead is a dead question, not a question that silently
tries elsewhere". Without that, a judge whose pane died could be answered by the
worker's pane and the gate would have accepted a run that then violated it.

---

## 3. The duet row

### 3.1 The name: `wiggum-duet`, and why not evolving `wiggum`

**Recommendation: a new row, named `wiggum-duet`.** Three reasons, in
increasing order of force.

*A row is one shape, never one invocation* (`README.md:708-710`,
`Registry.hs:26-31`, `:192-212`). The duet is a different shape and not a
different flag: the partner's observations feed round two **inside the term**,
which is a bind `wiggum` does not have, at a price `wiggum` does not pay. If it
were only "the same program under two `--session` flags" it would be an
invocation and the house rule would forbid a row.

*The churn is asymmetric.* `wiggum`'s numbers are pinned by equality on paths and
by ceiling on cost (`ci/workflows.sh:722`, the reasoning at `:702-722`), its
34 paths are enumerated in that comment, its 44 is called "the widest ceiling in
this table" in three files, and its blanket refusal is described in
`README.md`, `doc/design.md` and the guide. A new row moves one number in each of
those places and leaves `wiggum` as the loop the guide already documents; an
evolved `wiggum` moves all of them and leaves nothing behind for the operator
who wants the single-pane loop.

*The decisive one: the duet cannot re-pin what it borrows.* See §3.3.

### 3.2 The two pins, and why neither has a fall-back

```haskell
-- | The two serving models this row exists to have routed. They are names and
-- not models: nothing validates a serving model against a provider, and the ACP
-- and deck transports both carry the model axis as one prose line in `renderQ`'s
-- header (`AgentDeck.hs:408-424`) rather than as a protocol call. So an
-- unrouted duet run states `model: worker` to whatever adapter answers, which
-- is true and harmless, and a routed one dispatches on it, which is the point.
workerPin, partnerPin :: Text
workerPin = "worker"
partnerPin = "partner"

onWorker, onPartner :: Party 'IsModel -> Party 'IsModel
onWorker p = p `servedBy` workerPin
onPartner p = p `servedBy` partnerPin
```

**Neither takes `fallingBackTo`, and that is a decision.** A ladder relabels the
question's model axis on the next rung (`Route.hs:23-29`), so a `worker` pin
falling back to `opus` would, on a dead worker pane, re-route the *work* to
whatever answers `opus` — which under the owner's invocation is the default,
which is the worker pane, but under row 8 of the decision table is the acp
adapter, and under a mistyped table could be the judge's pane. A duet whose
worker pane died must fail, not silently move the work into the pane that is
about to judge it. `Route.hs:60-62` states the doctrine — a route whose backend
is dead is a dead question — and this row takes it deliberately rather than by
omission.

The borrowed callees keep their own ladders. They are on the default, they are
work, and the default is the worker pane.

### 3.3 What may be re-pinned, and what may not

`wiggumRoundFn` calls `commitFn` (`Git/Commit.hs`), the checkpoint calls
`cleanupRoundFn` (`Partner.hs`), `resolveFn` (`Git/Stack.hs`), `fessReportFn`
and the eleven fess stances (`Rubrics/Fess.hs`). Every one of those carries a
pin — `reasoning (model "decompose")`, `reasoning (model "resolve")`,
`reasoning (model "cleanup-review")`, the three-rung fess split at
`Rubrics/Fess.hs:354-357` — and every one of them is **shared with the rows that
own it**. Re-pinning `commitFn` to `worker` would re-pin it for the whole commit
family.

So the duet's reach is exactly its own asks, and the rule that falls out is the
one the invocation must honour:

> **The default backend is the worker's pane.** Everything the duet does not pin
> itself — every borrowed callee, every tool, every person, every unrouted
> receipt — is work, and work belongs in the work's pane. Only the judge and the
> partner seats are routed away.

That is why decision-table row 7 is a refusal and why clause (b) compares the
judge against the default as well as against the work pin.

The same constraint shapes the partner seats. `tierRoster Heavy`'s seven lenses
(`Review/Ladder.hs:221-229`) carry their own rung pins and are shared with the
four `review-*` rows, so the duet cannot reuse the roster values. It declares its
**own** four-seat roster over the same rubric text from
`Workflows.Rubrics.Reviewers`, pinned `onPartner`. Four and not seven because the
review runs inside the loop rather than beside it, and because seven seats would
put this row's ceiling past 60 (§3.5).

### 3.4 The skeleton

```haskell
-- src/Workflows/Duet.hs
-- One import, per §6: `Workflows.Prelude`.

-- | The partner's four seats, this row's own so that the pins can be `onPartner`
-- without moving `review-*`'s. The rubric text is `Rubrics.Reviewers`', named
-- after its md source; only the parties are new.
duetRoster :: Roster
duetRoster =
  [ lens "alexey"      (onPartner (model "alexey"))      alexeyRubric,
    lens "abstraction" (onPartner (model "abstraction")) abstractionRubric,
    lens "validated"   (onPartner (model "validated"))   validatedRubric,
    lens "ponytail"    (onPartner (model "ponytail"))    ponytailRubric
  ]

-- | The partner's round: four seats over what the work round produced, published
-- as observation files, and the listing handed back. Six consultations, no
-- branch — deliberately no `tested` over the listing, because a decider here
-- would double this program's path count for a fact round two's brief can carry
-- as text ("these observations, if any").
duetReviewFn :: Text -> Fn '[ 'CodeText] 'CodeText
duetReviewFn dir =
  function
    "duet.review"
    (takes @"round" Text $ noParams)
    \round -> W.do
      findings <- panelText (zip (lensNames duetRoster) (asksOver duetRoster defectClosing round))

      act (tool "observations") [wf|
          {publishBrief}

          {observationContract False}

          The observations directory:

          {dir}

          The round these findings are about:

          {round}

          The passes:

          {findings}|]

      listing <- ask (mdFilesIn dir) [wf|{publishedBrief}|]
      answer listing

duetTable :: Text -> Text -> Roster -> Text -> [SomeFn]
duetTable trunk dir roster provenance =
  [ SomeFn commitFn,
    SomeFn cleanupRoundFn,
    SomeFn fessReportFn,
    SomeFn resolveFn,
    SomeFn (duetReviewFn dir),
    SomeFn (duetRoundFn trunk),
    SomeFn (duetCheckpointFn trunk dir roster provenance),
    SomeFn duetReportFn
  ]

duetRefusalTable :: [SomeFn]
duetRefusalTable = [SomeFn duetReportFn]

duetProgram :: Parameterized
duetProgram =
  taking
    ( input "goal"
        :> input "base"
        :> input "observations"
        :> input "parity"
        :> input "run.backends"
        :> input "run.engine"
        :> input "run.routes"
        :> input "run.sentinel"
        :> noInputs
    )
    \goal base obs parity backends engine routes sentinel ->
      -- Tier 1, all of it: the trunk, the directory, the audit roster with the
      -- goal folded in, the last conjunct of the definition of done, the probe's
      -- prompt at this run's own sentinel, and the provenance every ending
      -- carries. Ordinary Haskell, before the `Program` exists.
      let trunk = trunkOf base
          dir = observationsDir obs
          roster = requesting goal fessRoster
          criteria = doneCriteriaBrief goal (parityClause parity)
          doctrine = rungSpecialists Restack ""
          attestation = independenceAttestation sentinel
          onThisRun = duetProvenance backends engine routes
          provenance = verifiedIndependence engine
       in -- THE FIRST GATE, AND IT ASKS NOBODY. Tier 1 over two run facts, so
          -- the refusing arm is a different *program* and not a path with a
          -- price. §2.3 is the whole of its behaviour.
          --
          -- A `case` and not an `if`, for `Wiggum.hs:1367-1370`'s reason: under
          -- `RebindableSyntax` an `if` here is `Agentic.Workflow.ifThenElse` over
          -- a flag bound in a program, and there is no program yet.
          case judgeIsElsewhere routes engine partnerPin workerPin of
            False -> defining duetRefusalTable W.do
              call_
                duetReportFn
                ( arg (onThisRun sameSessionNote)
                    :> arg (sameSessionState engine routes)
                    :> noArgs
                )
              stop
            True -> defining (duetTable trunk dir roster provenance) W.do
              -- The second precondition, over the residual the two facts cannot
              -- see: an adapter that resumed a conversation behind the client's
              -- back. `Wiggum.hs:1381-1387`, unchanged.
              probe <- ask (broad (model "independence")) [wf|{attestation}|]
              attested <- tested historyAbsent probe

              if attested
                then W.do
                  ready <- passes nixFlakeCheck [wf|{baselineBrief}|]

                  if ready
                    then W.do
                      -- Round one, in the worker's pane: every ask inside
                      -- `duetRoundFn` is `onWorker`, and everything it calls is
                      -- on the default, which §3.3 requires to be the same pane.
                      first <- call (duetRoundFn trunk) (arg goal :> arg orchestration :> noArgs)

                      complete <- tested saysComplete first

                      if complete
                        then W.do
                          -- One round was enough, so no review is bought: the
                          -- checkpoint's own audit is the judgment, and a review
                          -- whose findings nothing could consume is spend with
                          -- no consumer.
                          act restacker [wf|
                              {currencyBrief}

                              {first}|]

                          resolved <- call resolveFn (arg doctrine :> noArgs)
                          clean <- passes gitDiffCheck [wf|{markersBrief}|]

                          if clean
                            then W.do
                              handoff <- call (duetCheckpointFn trunk dir roster provenance) (arg first :> noArgs)

                              judged <-
                                escalating
                                  (onPartner (model "done-criteria"))
                                  criteria
                                  (onWorker (model "continuation"))
                                  continuationBrief
                                  handoff
                                  verdictTrips

                              case judged of
                                SettledOn final -> W.do
                                  call_ duetReportFn (arg (onThisRun doneNote) :> arg final :> noArgs)
                                  stop
                                UnsettledOn final -> W.do
                                  call_ duetReportFn (arg (onThisRun stillRemainsNote) :> arg final :> noArgs)
                                  stop
                                AbandonedOn final -> W.do
                                  call_ duetReportFn (arg (onThisRun cannotJudgeNote) :> arg final :> noArgs)
                                  stop
                            else W.do
                              call_ duetReportFn (arg (onThisRun conflictNote) :> arg resolved :> noArgs)
                              stop
                        else W.do
                          -- THE DUET, IN ONE BIND. The partner reviews round one
                          -- in its own pane, publishes one file per finding, and
                          -- the listing it answers with is round two's standing
                          -- context. This is the interleaving the old guide did
                          -- by hand across two invocations, priced.
                          review <- call (duetReviewFn dir) (arg first :> noArgs)

                          second <- call (duetRoundFn trunk) (arg goal :> arg review :> noArgs)

                          act restacker [wf|
                              {currencyBrief}

                              {second}|]

                          resolved <- call resolveFn (arg doctrine :> noArgs)
                          clean <- passes gitDiffCheck [wf|{markersBrief}|]

                          if clean
                            then W.do
                              handoff <- call (duetCheckpointFn trunk dir roster provenance) (arg second :> noArgs)

                              judged <-
                                escalating
                                  (onPartner (model "done-criteria"))
                                  criteria
                                  (onWorker (model "continuation"))
                                  continuationBrief
                                  handoff
                                  verdictTrips

                              case judged of
                                SettledOn final -> W.do
                                  call_ duetReportFn (arg (onThisRun doneNote) :> arg final :> noArgs)
                                  stop
                                UnsettledOn final -> W.do
                                  call_ duetReportFn (arg (onThisRun stillRemainsNote) :> arg final :> noArgs)
                                  stop
                                AbandonedOn final -> W.do
                                  call_ duetReportFn (arg (onThisRun cannotJudgeNote) :> arg final :> noArgs)
                                  stop
                            else W.do
                              call_ duetReportFn (arg (onThisRun conflictNote) :> arg resolved :> noArgs)
                              stop
                    else W.do
                      call_ duetReportFn (arg (onThisRun brokenBaseNote) :> arg probe :> noArgs)
                      stop
                else W.do
                  call_ duetReportFn (arg (onThisRun notIndependentNote) :> arg probe :> noArgs)
                  stop
```

`duetRoundFn` is `wiggumRoundFn` with one pin changed — `onWorker (model
"round-account")` where wiggum writes `reasoning (model "round-account")` — and
`duetCheckpointFn` is `wiggumCheckpointFn` with `onPartner (model "handoff")`:
the handoff is a *judgment about* the work and belongs in the judge's pane. The
eleven fess stances inside the checkpoint keep their own three-rung pins and go
to the default, which is the worker's pane. That is a real and deliberate
asymmetry — the audit reads the work in the pane that did it — and the honest
reading is that the fess audit is evidence-gathering, while the done-criteria
verdict is the judgment the definition of done turns on. Only the second one
must be elsewhere, and only the second one is pinned there.

**Party pins, in full:**

| party | pin | pane, under the owner's invocation |
|---|---|---|
| `model "round-account"` (in `duetRoundFn`) | `onWorker` | worker |
| `tool "wiggum-work"`, `tool "wiggum-restack"` | *(none — a tool)* | default = worker |
| `model "independence"` (the probe) | `broad` → `fable` | default = worker |
| the four `duetRoster` seats | `onPartner` | partner |
| `tool "observations"` | *(none — a tool)* | default = worker |
| `model "handoff"` (in `duetCheckpointFn`) | `onPartner` | partner |
| `model "done-criteria"` (the judge) | `onPartner` | partner |
| `model "continuation"` (the amender) | `onWorker` | worker |
| the eleven fess stances | `broad`/`reasoning`/`lateral` | default = worker |
| every borrowed callee's asks | its own row's rung | default = worker |

### 3.5 The predicted price shape

**Paths: 34, unchanged from `wiggum`.** The duet adds one `call` and no branch —
a call is consultations, not paths — and `duetReviewFn`'s body is a panel, an act
and a receipt, none of which branch. `ci/workflows.sh:702-722` derives wiggum's
34 as two early terminals plus, per round-count arm, one conflict terminal plus
`Escalation`'s `2n+1` replication at `atMost 2` over three report arms: `2 + 2 ×
(1 + 15) = 34`. Every term is untouched.

**`minFold`: 2**, unchanged — the two cheapest terminals are the probe and the
baseline, and the refusal arm asks nobody at all.

**`maxFold`: 50.** Wiggum's 44 plus `duetReviewFn`'s six — four seats, one
publish act, one listing receipt — bought once, on the two-round arm only, which
is the arm the maximum lives on. The one-round arm prices exactly as wiggum's
does.

```
wf cost wiggum-duet
  minFold 2, maxFold 50, over 34 paths
```

Pinned as `pin wiggum-duet branch 34 50`.

**This displaces 44 as the widest ceiling in the table**, which is a claim
written in three places (`ci/workflows.sh:709`, `README.md:393-395`,
`doc/design.md:986`) and must be swept.

**If the four seats are argued up to seven**, the ceiling is 53 and the case for
a smaller in-loop roster gets harder, not easier: a review that runs *inside* a
bounded loop is a different economic object from `partner-reviewer`, which runs
once beside it. Four is the recommendation; seven is a decision the owner may
take with the number in hand, which is what pricing is for.

### 3.6 The change list, agent-workflows side

| file | change |
|---|---|
| `src/Workflows/Duet.hs` | new: the program, `duetDoc`, `duetScript` |
| `src/Workflows/Deciders.hs` | `judgeIsElsewhere`, exported |
| `src/Workflows/Parties.hs` | `workerPin`, `partnerPin`, `onWorker`, `onPartner` |
| `src/Workflows/Wiggum.hs` | `input "run.routes"`; `judgeIsElsewhere routes engine opus opus` at `:1371`; the haddock at `:1294-1295` ("three the runner gives" → four) |
| `agent-workflows.cabal` | one `other-modules` entry |
| `src/Workflows/Registry.hs` | one import, one `regRows` entry after `wiggum` |
| `ci/workflows.sh` | one `inputsFor` arm (`goal= base= observations= parity=`); one `pin wiggum-duet branch 34 50`; the "TWENTY of the seventy-one" prose at `:250-257`; the widest-ceiling note at `:709` |
| `README.md` | `:170` twelve rows → thirteen; `:179`, `:184`, `:274`, `:624` 71 → 72; `:393-395` the ceiling |
| `doc/design.md` | `:981` "71 workflows pinned"; a §6.6 entry for the duet in the house five-part shape |
| `doc/wiggum-two-sessions.md` | rewritten — §7 |

`duetScript` follows `wiggumScript`'s discipline: this row's own keys first, then
`commitScript Commit <> stackScript Restack <> partnerScript Cleanup <>
fessScript` spliced rather than transcribed. The default table must steer down
the two-round arm (so the review is exercised) — `roundAccountBrief` answering
`WORK REMAINS` on its last line, exactly as `wiggumScript` does — and the four
`duetRoster` seats need one canned reply each, keyed on their rubric prefixes.

**The refusal arm is not reachable from a canned table**, for
`Wiggum.hs:1537-1544`'s reason and now doubly so: it is chosen in Haskell from
two run facts, and `--scripted` binds `run.routes` to the empty text and
`run.engine` to a value with no session policy in it, so a scripted run always
takes the loop. What reaches the refusal is a command line, and §6 is how it is
proved.

---

## 4. The human in the pane, honestly

### 4.1 What the transport does today

One turn of `Agentic.AgentDeck` is three commands (`AgentDeck.hs:490-549`): read
the current reply's `timestamp` **before** sending; send; then poll
`session show` every `deckPollMs` until the status is not `running`, and accept
the reply only once its `timestamp` differs from the one recorded before the
send. The whole turn is bounded by `deckTimeoutMs`, default 600 000.

There are three ways an owner typing into the pane meets that loop, and they are
not equally benign.

**Benign — typing between two `wf` turns.** `currentStamp` is taken fresh at the
top of every `sayDeck` (`:502`), so an owner turn that completes before the next
question goes out simply becomes the new `before`. The guard absorbs it exactly.
This is the common case and it costs nothing.

**Benign — typing while `wf`'s send is queued.** `sendMessage` runs no liveness
check on purpose, because `agent-deck session send` waits for the agent to be
ready before it types (`:564-566`). So an owner message already in flight is
answered first, `wf`'s question is typed after it, and `wf`'s `before` stamp
predates both — the reply it eventually accepts is its own. Correct by
construction.

**The hazard — submitting while `wf`'s own question is being answered.** The
agent finishes `wf`'s answer and, if the owner's message is already waiting,
picks it up immediately. If that happens before `wf`'s next poll observes
`Idle`, the loop sees `running` again, keeps waiting, and then reads *the owner's
answer* as the answer to its question — because the freshness test is
`replyStamp r /= before` (`:545-546`), a comparison against **one** stamp taken
before the send, which cannot tell two new replies apart. The result is a
silently misattributed answer: not an error, not a timeout, just the wrong text
decoded into the run.

The window is the gap between the agent going idle and `wf`'s next poll —
`deckPollMs`, one second by default. It is narrow, it is real, and nothing in the
transport reports it.

A fourth outcome sits underneath all three: **every owner turn spends `wf`'s
turn budget.** The deadline is wall-clock from the top of `sayDeck` (`:492`,
`deadlineIn`), so a long human interleave produces `DeckTimedOut` — a named
failure quoting the last status seen (`:294-301`), classified as
`GapTransportRefusal` and handed to the recovery walk (`:457-466`). Loud, and
therefore fine.

### 4.2 What the guide must tell the owner

Four sentences, and the third is the one that matters:

1. Read either pane at any time; reading is invisible to the transport.
2. Type into either pane freely **between** `wf`'s questions — the staleness
   guard is re-armed before every question and absorbs your turn exactly.
3. **Do not submit a message while `wf` is waiting on that pane.** If your reply
   lands before `wf` reads its own, `wf` will read yours instead, and nothing
   will say so. Watch the run's narration: it prints one line per consultation,
   and the pane is `wf`'s between "put text to model X" and the answer.
4. For a duet run, pass `--poll 250`. It shrinks the misattribution window
   fourfold at the cost of one `agent-deck session show` subprocess every quarter
   second, and it is the only mitigation available today that requires no code.

### 4.3 Hardening: not now, and here is the ledger

**Recommendation: no transport change in this piece of work.** The reasoning,
so the deferral is a decision and not an omission.

The change that would actually close it is a **tagged reply**: `renderQ` appends
a per-question nonce to the answer-format line, and a reply lacking it is a
transport gap that re-asks. It would work — the format line is already
"adapter behaviour and not language semantics" (`AgentDeck.hs:74-81`), and
`answerSpec` is exactly the precedent. Its costs are three, and together they
outweigh a one-second race:

- `renderQ` is `Exec.renderQ` **verbatim** (`AgentDeck.hs:392`, cited as
  `Exec.lean:853`), and `haskell/ci/citations.sh` gates that every such citation
  resolves. Appending a nonce makes the function no longer that function, and the
  citation has to be renegotiated rather than edited.
- It changes what is on the wire for **every** deck run, existing ones included,
  and would perturb all seven `ci/deck.sh` scenarios and `test/stub-deck.sh`'s
  `answer_for`.
- A model that forgets the tag burns a re-ask. `defaultRetries` absorbs the first
  one; a model that reliably forgets turns every question into two.

Two cheaper ideas were considered and rejected. Reading `session output` on every
poll rather than only at `Idle` would catch a *second* new stamp, but not the
case that actually bites — where the owner's reply is the first new stamp — and
it doubles the subprocess count. A `DeckInterleaved` error raised on any
ambiguity has the same blind spot.

**The order that makes sense**: land `run.routes` and the finer gate, prove the
two-pane split with §6's scripted gate, run the duet against two real panes, and
then decide whether the window was ever hit. File the tagged-reply hardening in
`obr` now, with this paragraph as its body, so the decision is recorded rather
than forgotten. Meanwhile the guide says the true thing, which is the minimum a
design that knows about a silent failure owes its operator.

---

## 5. The invocation

### 5.1 As the owner will type it

```sh
# Two panes, primed and ready, in the same repository.
agent-deck launch ~/src/my-project -c codex     # pane W — the work
agent-deck launch ~/src/my-project -c claude    # pane R — the partner
agent-deck list                                 # note the two ids

# Price it first. Nothing below spends a token you have not seen.
wf cost wiggum-duet
#   minFold 2, maxFold 50, over 34 paths

# One command. wf drives both panes and owns neither.
wf run wiggum-duet \
   --session      "$PANE_W" \
   --route        "partner=deck:$PANE_R" \
   --poll         250 \
   --require-pinned \
   --input-arg    goal='Bring the token-refresh path under test and close the two known races.' \
   --input-arg    base=main \
   --input-arg    observations= \
   --input-arg    parity=
```

`--input-file goal=doc/GOAL.md` where the goal is longer than a shell line.

Read the flags against the decision table: `--session "$PANE_W"` makes
`deck:$PANE_W` the **default**, so every borrowed callee, every tool and every
person lands in the work's pane; `--route partner=deck:$PANE_R` moves the four
review seats, the handoff and the done-criteria judge to the other. That is row
6 — `J = deck:$PANE_R`, `W = D = deck:$PANE_W`, accepted. Writing it the other
way round is row 7 and is refused, in the gate's own words, before anything is
spent.

`--require-pinned` is not required but is recommended: it refuses a model ask
that left out its `served by` before a plan is printed, which for this row means
it refuses any ask that would have silently taken the default when it meant to
name a pane.

The header will print, before the first question:

```
running wiggum-duet against 2 backends:
  (default)  agent-deck session 0f3a91c2-codex
             — every unpinned ask, every tool and every person
  partner    agent-deck session 7b2e40aa-claude
             — its working directory is its own; this run's tools run in .
  worker, …  the default (no --route names them)
  polling every 250ms, 600000ms to a turn, one session for the run
```

and `run.routes` will carry the first two of those lines, in that order, to every
prompt that holes it.

### 5.2 As `M-x wf-run` will offer it

`emacs/wf.el`'s transport picker is today a three-way choice emitting exactly one
backend (`wf.el:341-350`): `("--scripted")`, `("--engine" "acp" "--adapter" A),
or `("--session" ID)`. It contains no `--route` anywhere.

**§6 requirement on `wf.el`, in one sentence:** `wf--read-transport` must, for a
row whose `wf plan <row> --json` reports a non-empty `pins` array (§1.5), offer
one `agent-deck` session completion per declared pin name after the default
transport has been chosen — reusing `wf--read-session` for each — and emit the
resulting `--route NAME=deck:ID` flags alongside the default `--session`,
skipping any pin the operator leaves blank so that a partially-routed run is
expressible.

### 5.3 What the operator keeps

Everything the ruling asked for. `wf` never issues `session start`, `session
stop` or `session kill` — the stub gate is what proves it, because
`test/stub-deck.sh:177-179` fails loudly on any fourth verb. When the run ends,
both panes are still attached, still holding their history, still the owner's,
and the next `wf run wiggum-duet` picks them up where they are.

---

## 6. The verification story

### 6.1 agent-cat: `ci/deck.sh`, an eighth scenario, two stub panes

**Which repo's gate: agent-cat's.** The claim under test is a *transport* claim
— one run, two live deck sessions, each question answered in the pane its pin
names — and the transport, the stub and the seven scenarios that already exercise
it all live there. `ci/deck.sh` is also the only gate in either repository that
runs the deck engine at all; `ci/acp.sh` scenario 13 already proves the same
claim for two `acp:` backends (`ci/acp.sh:278-330`) and this is its deck twin.

**One small fixture change is needed first.** `test/stub-deck.sh` keys every
state file off `$DECK_STUB_STATE` alone and uses the session id only as an echoed
JSON field (`:53-57`, `:153-161`), so two `deck:` routes today would share one
`reply`, one `seq` and one `sends` counter and would answer each other's
questions. The fix does not touch the stub: install as `agent-deck` a four-line
shim that derives the state directory from the session id and `exec`s it.

```sh
# $work/two-panes/bin/agent-deck
#!/bin/sh
# $3 is the session id in every command this stub implements.
DECK_STUB_STATE="$STUB_ROOT/$3" exec "$STUB_ROOT/stub-deck.sh" "$@"
```

**The scenario.** `agentic-run`'s own `harden` example already pins `deep`, which
is what `ci/acp.sh:311-312` routes; the same pin routes to a second pane here.

```sh
play two-panes happy run harden \
  --session pane-a --route 'deep=deck:pane-b' --poll 20 --timeout 30000
want_code 0
# Routing changes no bill: no field of an EventKey names a backend.
want_line "billFresh   7"
want_line "billMemo    7"
want_line "running harden against 2 backends:"
```

**What it asserts, and how.** Two independent witnesses, and the design wants
both.

*From the run's own narration* — the scope record. `announcingWorld` prints one
line per consultation naming the addressee and the question's code, and the trace
records the model axis of whoever answered, which `Route.hs:36-43` calls out as
the reason routing needs no new field: *route table + trace* says which backend
answered every event, totally and after the fact. So the header's `deep` line
plus the narration's `put to model author` / `put to model deep` lines are the
attribution, exactly as `ci/acp.sh:314-318` asserts it.

*From the two panes' own transcripts* — the stronger witness, because it is
outside the process. The shim gives each session its own `prompts` file, and the
assertion is a partition:

```sh
grep -q 'question for model deep'   "$work/two-panes/pane-b/prompts" || bad "…"
grep -q  'question for model author' "$work/two-panes/pane-a/prompts" || bad "…"
grep -q 'question for model deep'   "$work/two-panes/pane-a/prompts" && bad "the work pane saw the judge's question"
grep -q 'question for model author' "$work/two-panes/pane-b/prompts" && bad "the judge's pane saw the work's question"
# The two send counts must sum to the 7 of scenario 1 and neither may be 0.
# Pin the actual split once measured — `harden` puts the author's asks to `deep`
# and everything else to the default, so it is a fact about the example and not
# something this design should predict.
want_sends_split pane-a pane-b 7
```

The two negative greps are the whole gate. Everything else could be true of a run
that sent both questions to both panes.

`ci/deck.sh:184`'s closing line moves from `7 scenarios` to `8`.

### 6.2 agent-workflows: `ci/workflows.sh`, one pin and one scripted run

The row-level gate proves the *shape* and the *price*, not the panes: `pin
wiggum-duet branch 34 50` holds `level` and `paths` by equality and `costMax` as
a ceiling, and the `--scripted` run walks the two-round arm through
`duetReviewFn` and exits 0. That is the same contract every other row has and it
is deliberately not extended: a workflow gate that stood up two stub panes would
be re-proving agent-cat's transport in the repository that consumes it.

**One thing the workflow gate can prove that the transport gate cannot**: that
the *refusal* arm is reachable and says what it should. `--scripted` cannot reach
it (§3.6), so the check is a plain usage assertion — run the row under a command
line that trips decision-table row 4 or row 7, assert exit 0 and the refusal's
own wording — with no adapter and no session needed, because the gate fires
before the first question. Row 7 is the one worth pinning, since it is the one an
operator will type.

---

## 7. The guide rewrite: `doc/wiggum-two-sessions.md`

The current guide teaches the *hand-interleaved* pattern — run `wiggum` under
`--engine acp` in one pane, run `partner-reviewer` under `--session` in another,
and carry the report across by hand as the next invocation's `observations`
input (`:120-133`). That is now the fallback, not the lesson.

**New outline, in the same voice:**

1. **Title and premise.** "Two panes, one command" — the ruling's shape stated
   as the thing the page teaches.
2. **The cast, one paragraph each.** agent-deck, agent-cat, agent-workflows —
   unchanged except that the toolbox count moves 71 → 72.
3. **Zeroth step: read the price.** `wf cost wiggum-duet` → `minFold 2, maxFold
   50, over 34 paths`. Keep the existing sentence about a ceiling being a promise.
4. **Standing up the two panes.** As `:44-51`, with the two `-c` flags named:
   codex for the work, claude for the partner. Note that priming them is the
   owner's business and `wf` will not do it.
5. **The one command.** §5.1 verbatim, with the header it prints, and the
   decision-table reading of the flags: `--session` sets the default and the
   default is the work; `--route partner=` moves the judge.
6. **Why the flags cannot be written the other way.** Show the row-7 refusal in
   the gate's own words. This replaces the current "Why not `wf run wiggum
   --session <pane-W>`?" box at `:81-93`, which stays true and becomes a
   subsection about `wiggum`, not `wiggum-duet`.
7. **Reading and typing while it runs.** §4.2's four sentences, with the
   `--poll 250` recommendation and the misattribution hazard stated plainly. This
   section is new and is the one the old guide had no need for.
8. **What flows between the panes.** The partner's observation files, published
   into `observations=` and consumed by round two *inside the term*. Contrast
   with the old across-invocation loop in one sentence: the coupling is now a
   bind and not a copy-paste, and it is priced.
9. **When you have no panes.** The demoted section: `--engine acp` for `wiggum`,
   `--engine acp` or a second pane for `partner-reviewer`, and the hand-carried
   `observations` loop as `:120-133` has it today. Everything in the current
   guide survives here.
10. **What is guaranteed, and what stays with you.** As `:135-147`, plus one new
    guarantee — the judge's pane is not the work's pane, checked before anything
    is spent — and one new caveat, the interleaving window.
11. **The same pattern, other rows.** As `:149-155`.

**Two live defects to fix while rewriting**: `:107-109` shows `wf run
partner-reviewer --input-arg scope='…'`, and that row has no `scope` input — its
inputs are `commit`, `observations`, `paths` (`Partner.hs:840-846`), so the
command as printed is refused twice over. And `:20`'s "71 programs" moves.

---

## 8. What it deletes, what it buys, its honest cost

**What it deletes.** The hand-carried loop between two invocations
(`doc/wiggum-two-sessions.md:120-133`) — three commands and a copy-paste become
one command and a bind. The prose caveat "run it somewhere other than the work"
(`Partner.hs:97-124`), which is advice a program cannot check, becomes a refusal
a program computes. And the sentence in `sharesOneSession`'s haddock that a
program "cannot tell which of them it got" (`Workflow.hs:2137-2141`), which was
true only because the fact that would tell it did not exist.

**What it buys.** A judge that is provably not the worker under a transport that
shares one conversation — which is the combination the old gate had to refuse
outright, and the only combination the owner's two-pane workflow can be. Plus the
route table as a fact any program may read, which is the general capability;
this row is its first consumer and not its justification.

**Its honest cost.** A fourth reserved input, which is a fourth thing in a closed
set that was argued closed (`Workflow.hs:2063-2068`) — the argument survives,
because `run.routes` is a property of the command line known before the first
question, which is the membership test that paragraph states, but the set is one
larger and the next one will be argued against a longer list. Six consultations
on the two-round arm, and a ceiling that displaces 44 as the widest in the table.
A silent misattribution window of one poll interval that this design names,
mitigates with a flag, and does not close. And a fixture shim in `ci/deck.sh`,
because the stub was written for one pane.

---

## Appendix: open questions for the builder

1. **`Roster` re-pinning.** §3.3 assumes the duet must declare its own four-seat
   roster because `tierRoster Heavy`'s lenses carry pins shared with `review-*`.
   If `Lens` exposes its party settably, a `repinned partnerPin (tierRoster
   Heavy)` helper is strictly better and makes the seat count an argument rather
   than a decision. Check `Review/Ladder.hs`'s `Lens` constructor first.
2. **`judgeIsElsewhere`'s home.** `Workflows.Deciders` is the recommendation;
   `Workflows.Gates` is the alternative and is arguably the better name, but its
   haddock is currently about the revision grammar and would grow a second
   subject.
3. **Whether `wiggum` should take `run.routes` at all.** §2.4 recommends yes, for
   one-spelling; the cost is one input line, one README count and one haddock
   sentence, and the benefit is that the two rows cannot drift. If the sweep
   proves larger than that, the fallback is to leave `wiggum` on
   `sharesOneSession` and add a comment at `Wiggum.hs:1371` naming
   `judgeIsElsewhere` as the general form — worse, but honest.
4. **`--poll` is per-run, not per-route** (`Cli.hs:1465-1473`,
   `RunRoutes`'s haddock at `:420-435`). A duet under `--poll 250` polls the
   partner's pane as hard as the worker's, for no gain, because the partner is
   idle for most of a round. Not worth a per-route knob today — the doctrine at
   `:423-429` is that a per-route knob is a wrapper script — but it is the first
   case where the doctrine costs something real.
