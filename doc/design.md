# `agent-workflows` — the design of record

*2026-08-19. Judged from the four inventories and three competing architectures
at `agent-cat/doc/research/ai-config-workflows/` — which §5 step 2 has since
moved to `doc/research/` in this repository, where they now are —
(`agents.md`, `commands-1.md`,
`commands-2.md`, `skills.md`; `arch-A.md`, `arch-B.md`, `arch-C.md`), the
foundation report (`foundation-report.md`), the coordinator's `pal-note.md`, and
`agent-cat/doc/research/pal-subsumption/confer-design.md`. Grounded against the
tree as it stood on disk at authoring time — `agent-cat/workflows/` (since
migrated here, §5), `agent-cat/haskell/agentic.cabal`,
`agent-cat/haskell/src/Agentic/Cli.hs` and `agent-cat/haskell/ci/workflows.sh`
(now `ci/workflows.sh` in this repository).*

This repository is **a user of agent-cat**, not part of it. agent-cat is the
language, its Lean kernel, its frozen corpus and its conformance gates, and it is
public. This is John's toolbox — his commands, agents and skills rewritten as
priced programs — and it is private, on Gitea, because the corpus it is
transcribed from is his live personal configuration.

`~/src/nix/config/ai` is **read-only, absolutely**. It was read as data. No
program in this repository has a `running` party pointed at it, and no prompt
text harvested from it is an instruction this repository obeys.

---

## 0. The judgment

Three architectures were written to the same brief with three assigned biases.
None is wrong; each is strongest exactly where its bias points, and the design of
record takes from all three. Scored on the four axes the brief names:

| | **A** — maximal reuse | **B** — operator-first | **C** — semantics-first |
|---|---|---|---|
| **Fidelity to the corpus** | **Best.** All 119 files triaged with the reference graph made explicit: `commit`'s three in-edges and zero out-edges, `resolve`'s three prose callers, `parallelize`'s seven inbound edges, the finding schema's eleven copies, the ladder paragraph's five. Names the two places drift has *already happened* (`deep-review`'s Category vocabulary; `partner-reviewer`'s enum). | Good. 122 rows, every FOLD-IN naming a host, and the clearest statement of the fold: "39 transforms collapse to 26 verbs." Weaker on the graph — it names the duplications but not the edges. | Good. 121 rows, and the only one that grades its own coverage honestly (ten KEEP-AS-MD, "small because the corpus is genuinely full of latent structure, and *not zero*"). |
| **Buildability** | **Proven.** It is the one that was built: the foundation report's module set, `wf`, the root-level tree and the two-registry/one-CLI seam are A's, and every gate went green on them. | Sound but for one decision now moot (tree under `haskell/`), and one that fights pricing: `mode=` inputs collapse rungs whose prices the owner wants side by side. | Sound. Its `ci/workflows.sh` design — `level` and `paths` by equality, `costMax` as a ratcheting ceiling — is what landed, verbatim. |
| **The leveling-up goal** | **Best, and falsifiable.** The thesis is stated as a testable claim ("if the library is right, flagship 1 is under 60 lines") with three named ways it could be wrong and the week each would be discovered. | Best on the *operator's* level-up: the pre-spend contract as an unavoidable printed line, and `--at-most N` as a refusal rather than a report. | Best on the *method*: twelve capability codes, and the rule that decides everything — "if you cannot name the capability, you do not have a workflow, you have a prompt that compiles." |
| **Honesty about what is not a workflow** | 6 KEEP, and §7's three self-falsifications is the most honest page in the three. | 7 KEEP, each argued in one sentence, including two files that are simply dead. | 10 KEEP, and the sharpest reasons — `add-uint-support` is loaded by the harness *while editing*, which is not a run to price. |

**The ruling, in one line each.** A supplies the shape and the library; C supplies
the method, the house rules and the gate; B supplies the operator's contract —
the defaults, the refusal, and the requirement that `wf` be a real binary on
`PATH`. §10 is the full ledger of what was taken and what was rejected, with
reasons.

---

## 1. The package

**1.1 Name.** The repository, the flake and the cabal package are all
`agent-workflows`. Not `workflows` — a package name is a global name, and a
toolbox that says only "workflows" says nothing about whose or against what.

**1.2 Source layout.** The package root *is* the repository root. This is the
single clearest gain of the move, and it dissolves the one deviation the
foundation had to argue for:

```
agent-workflows/
  agent-workflows.cabal        the library, the executable, one common stanza
  cabal.project                the dev loop: this package + ../agent-cat/haskell
  flake.nix  flake.lock        the pinned build (§3)
  .envrc  .gitignore
  README.md                    the toolbox card and the five house rules
  doc/
    design.md                  this file
    research/                  both what this design was decided from and what
                               is being decided next: the four inventories,
                               three proposals and foundation report moved out
                               of the public repo (§5, step 2), and alongside
                               them the designs authored here since, for work
                               this file does not yet cover
  src/
    Workflows/                 …exactly the tree agent-cat/workflows/Workflows/
      Prose.hs  Prelude.hs     held at migration time, moved unchanged
      Parties.hs  Evidence.hs
      Rubrics/{Finding,Reviewers,Fess,Discipline,Ladder}.hs
      Panels.hs  Deciders.hs  Gates.hs  Escalation.hs  Report.hs
      Review/Ladder.hs  Fix/Green.hs  Git/{Commit,Stack}.hs  Fess.hs
      Hello.hs  Registry.hs
  bin/Main.hs                  `wf`, two lines over Agentic.Cli
  emacs/
    wf.el                      the Emacs interface: the same verbs over
                               `--json` alone, and the price gate as a question
    wf-smoke.el                its batch smoke, against the real binary
  ci/workflows.sh              this repository's own gate (§9)
  ci/emacs.sh                  the Emacs gate: compile, checkdoc, smoke
```

`hs-source-dirs: src` and `hs-source-dirs: bin`. **The symlink and the
`relative-path-outside` warning both cease to exist**, because there is no longer
an outer package for the source to be outside of. The foundation's deviation #2 —
real files at the repository root, `haskell/workflows` a symlink so the cabal
field stays inside the package — was the right answer to a question this
repository does not have.

**1.3 Module namespace: `Workflows.*`, unchanged.** The alternative considered
was a shorter root (`Wf.*`) now that the tree is a package of its own. Rejected:
the rename touches every module header, every import in twenty-one files, the
cabal stanza, the gate, the README and `confer-design.md`'s citations, and buys a
saving of six characters in text nobody types. `Workflows.` also still reads
correctly from the outside — an import of `Workflows.Panels` in a foreign package
says what it is. Taste does not clear that bar.

**1.4 What the foundation built that stands as-is.** Verified by reading, not by
assumption:

| module | lines | verdict |
|---|---:|---|
| `Prose`, `Prelude` | 90, 74 | **Stands.** The mechanics `Example.Isaac` kept private, promoted. |
| `Parties` | 179 | **Stands.** The pins and the three fail-over ladders (`reasoning`/`broad`/`lateral`); `lateral`'s haddock already names the confer member. |
| `Evidence` | 317 | **Stands.** The argv library; the one module where the read-only rule could be broken, reviewable as a unit. |
| `Rubrics/{Finding,Reviewers,Fess,Discipline,Ladder}` | 151, 444, 359, 201, 101 | **Stands.** Every binding names the corpus file and section it was transcribed from. `Finding.categories` resolves the `deep-review` drift in one place, in favour of the consumer, and says so. |
| `Panels` | 257 | **Stands, with two signature generalizations owed to confer** (§8, R1/R2). |
| `Deciders`, `Gates`, `Escalation`, `Report` | 206, 197, 221, 218 | **Stands.** Including the two haddock corrections: no `mustPass` combinator (the real shape is `when ok $ W.do …`), and `AbandonedOn` unreachable under an exec review. |
| `Hello` | 117 | **Stands.** The smoke row, and the row the gate is read against. |
| `Registry` | 112 | **Stands as a shape; its row list is ahead of the gate** (§5, step 6). |
| `bin/Main.hs` | 21 | **Stands.** |
| `README.md` | 96 | **Stands, with §1.2's paragraph about the symlink deleted** — it describes a problem this repository does not have. |

**1.5 What is on disk and is NOT known to stand.** Four modules were written
after the foundation report's gates ran, by builders that were stopped mid-write:
`Review/Ladder.hs` (927), `Fix/Green.hs` (567), `Git/Commit.hs` (642),

1. **The tree does not build.** `agentic.cabal`'s `library workflows` stanza
   lists `Workflows.Git.Stack` in `exposed-modules` and there is no
   `Git/Stack.hs` on disk. Flagship 5 is the module the stop landed in.
2. **The gate does not pass.** `ci/workflows.sh` pins one row (`hello`);
   `Workflows.Registry` registers eight (`hello`, four `review-*`, three
   `green-*`). The gate fails in both directions at once — seven rows registered
   and pinned nowhere.

`Git/Commit.hs` and `Fess.hs` are written and **not registered**, so
nothing prices them. They are treated as drafts of flagships 3 and 4 in §6 and
are re-derived there against the foundation's actual signatures rather than
adopted sight-unseen.

---

## 2. The runner

**2.1 The verb: `wf`.** Two characters, typed several times a day. A and B chose
it; C chose `workflows`, which is nine characters and a noun. Brevity decides,
and the built tree already spells it: `executable wf`, `bin/Main.hs`'s haddock,
`ci/workflows.sh`, the README. Rejecting C here costs nothing and re-deciding it
would cost a sweep.

**2.2 The definition.**

```haskell
-- bin/Main.hs, in full
module Main (main) where

import Agentic.Cli (cliMain)
import Workflows.Registry (registry)

main :: IO ()
main = cliMain registry
```

That is the whole executable, and it is the point of the `Agentic.Cli`
extraction: a registry-bearing runner is one library call. `agentic-run` is the
same function at the other table.

**2.3 The registry module: `Workflows.Registry`, exporting `registry ::
Registry`.** Its naming rule, from the built module and confirmed here:

* **A row is one *shape*, never one *invocation*.** `review-quick`, `review-deep`,
  `review-sec` and `review-heavy` differ in roster, receipts and price, which is
  what a row should differ in. `code-review` and `review-github-pr`, which differ
  from `review-deep` only in what `--input-arg` is given, are **not** rows.
* **Family first, the owner's own word as the suffix**: `review-heavy`,
  `green-flaky`, `commit-bankruptcy`, `stack-rebase`. `wf list` is a browsable
  index and family-first sorts the toolbox by the thing the owner is choosing
  between. Where a family has a default rung, the bare family name is that rung:
  `commit`, `stack`, `fess`.
* **A rung is a row and not a flag**, because the four numbers `wf plan` prints
  are the pre-spend contract and `ci/workflows.sh` reads them out of the binary.
  A rung behind a flag is a rung whose level and path count no gate pins. This is
  where the design departs from B and C, which both collapse rungs into a `mode=`
  input; their arithmetic is right (an input costs zero paths) and their
  conclusion is wrong (it also costs the operator the side-by-side prices that
  are the whole reason the ladder became a program).

**2.4 `wf` must be a real binary on `PATH`.** Taken from B §5.3, and it is the
one packaging requirement the design has: every `running` party's argv executes
in the process's working directory, so a shell alias that `cd`s into the package
to `cabal run` would answer `git diff` about the wrong repository. Install it:

```sh
cabal install exe:wf --installdir=$HOME/.local/bin --overwrite-policy=always
# or, from the flake:  nix profile install .#default
```

**2.5 Two defaults `wf` does not change.** B proposed three product-level
departures from `agentic-run` — default `--scratch` to `$PWD`, default
`--require-pinned` on, always print the price before running — plus a new
`--at-most N` refusal. All four are good, and **none of them is this
repository's to make**: `Agentic.Cli` is one function in agent-cat, and a
per-registry defaults record is a change to agent-cat's API. They are recorded
in §8's roadmap as a request on agent-cat (`Registry` gains a `regDefaults`
field), not smuggled in as a fork of the CLI. Until then the owner passes
`--require-pinned` on the command line and the gate enforces it per row.

---

## 3. The flake, the dev loop, the environment

**3.1 The constraint.** agent-cat's `flake.nix` exposes a Lean devShell and
nothing else; `agent-cat/haskell/flake.nix` exposes a GHC devShell and nothing
else. **There are no Haskell package outputs anywhere in agent-cat.** So this
repository takes agent-cat as a *non-flake* input and builds the library itself.

**3.2 `flake.nix`.**

```nix
{
  description = "agent-workflows — John's commands, agents and skills as priced agent-cat programs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    # Not a flake: agent-cat's flakes expose devShells only, so what this
    # repository needs from it is the source tree and cabal2nix. Pinning it here
    # is what makes `nix build` reproducible; `cabal.project` (§3.3) is what
    # makes the inner loop fast, and §3.5 says which wins.
    agent-cat = {
      url = "github:jwiegley/agent-cat";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, agent-cat }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        # One overlay over the default package set, because `agentic` and this
        # package must see ONE GHC and one `aeson`. `agent-cat/haskell` is a
        # subdirectory of a source tree, which is exactly what callCabal2nix
        # takes.
        hs = pkgs.haskellPackages.extend (final: prev: {
          agentic = final.callCabal2nix "agentic" "${agent-cat}/haskell" { };
          agent-workflows = final.callCabal2nix "agent-workflows" ./. { };
        });
      in {
        packages.default = pkgs.haskell.lib.justStaticExecutables hs.agent-workflows;
        packages.agent-workflows = self.packages.${system}.default;

        # `cabal build`, `cabal run wf`, `./ci/workflows.sh`.
        devShells.default = hs.shellFor {
          packages = p: [ p.agent-workflows ];
          nativeBuildInputs = [ pkgs.cabal-install pkgs.haskell-language-server ];
        };
      });
}
```

**This places a hard requirement on agent-cat** and it is §4's first item:
`callCabal2nix "agentic" "${agent-cat}/haskell"` reads `agentic.cabal` in full,
so as long as that file carries a `library workflows` stanza whose
`hs-source-dirs` is a symlink out of the package, the derivation is broken by
construction. The stanzas must leave.

**3.3 `cabal.project` — the dev loop.**

```cabal
-- The inner loop. `..` is the sibling working tree, so an edit to
-- `Agentic.Cli` is visible to `cabal build` here without a commit, a push or a
-- flake bump. The flake does not read this file.
packages:
  .
  ../agent-cat/haskell
```

**3.4 `.envrc`** — the owner uses direnv:

```sh
use flake
watch_file cabal.project
watch_file agent-workflows.cabal
```

**3.5 `.gitignore`**, and the authority question the README must answer:

```
dist-newstyle/
result
result-*
.direnv/
*.hi
*.o
```

> **Which is authoritative.** The **flake** is. It pins an agent-cat revision,
> it is what `nix build`, `nix flake check` and any machine other than this one
> will use, and it is the only statement this repository makes about what it
> builds against. `cabal.project` is a development convenience: it points at
> `../agent-cat/haskell`'s *working tree*, which may be ahead of the pin, behind
> it, or dirty.
>
> When the two disagree — `cabal build` green and `nix build` red — the meaning
> is almost always **"you have agent-cat changes that are not pushed"**, and the
> fix is to push agent-cat and `nix flake update agent-cat`. The reverse — `nix
> build` green and `cabal build` red — means the sibling checkout is on another
> branch. Neither is a bug in this repository, and the README says so in these
> words so that neither is diagnosed twice.

---

## 4. The boundary with agent-cat

**4.1 A requirement on agent-cat: `Agentic.Cli` stays exposed.** This is the key
enabler and the one thing this repository cannot supply for itself. Stated as a
contract, so that a change to it is recognised as breaking:

```haskell
module Agentic.Cli ( Registry (..), Row (..), cliMain ) where
data Registry = Registry { regBinary, regNoun, regBanner :: !Text
                         , regRows :: ![(Text, Row)] }
data Row      = Row { rowExample :: !Example, rowDoc :: !Text
                    , rowScript :: ![(Text, Text)] }
cliMain :: Registry -> IO ()
```

`agent-workflows` depends on these six field names and three type names and on
nothing else in `Agentic.Cli`. agent-cat is free to change everything behind
`cliMain`; changing the record is a breaking change and should move `agentic`'s
version. In exchange, agent-cat gets what it already got: `run/Main.hs` at 27
lines, the `list` verb that fell out of making the table a value, and a second
consumer proving the extraction was an extraction.

**4.2 What leaves agent-cat.** Five things, and after they leave, agent-cat has
**zero references to `Workflows.*`** — verified: `grep -rn "Workflows\."` over
`haskell/src`, `haskell/example`, `haskell/run`, `haskell/tier1` and
`haskell/test` returns nothing today.

| leaves | to | note |
|---|---|---|
| `agent-cat/workflows/` (tree + README) | `src/Workflows/`, `bin/`, `README.md` | moved unchanged; only the README's symlink paragraph is deleted |
| `agentic.cabal`'s `library workflows` stanza | `agent-workflows.cabal`'s `library` | the `exposed-modules` list carries over, minus `Workflows.Git.Stack` until §6.5 lands |
| `agentic.cabal`'s `executable wf` stanza | `agent-workflows.cabal`'s `executable wf` | `-threaded` for the same reason `agentic-run` takes it |
| `haskell/workflows` symlink | *deleted* | §1.2 |
| `haskell/ci/workflows.sh` | `ci/workflows.sh` | adapted per §9 |

**4.3 `Example/Harden.hs` and `Example/Isaac.hs`: the modifications are
agent-cat-honest and STAY.** Decided from the files, not from the report:

* `Example.Harden` imports `Agentic.Cli (Registry (..), Row (..))` — an
  agent-cat-internal dependency — and now exports `examplesRegistry` alongside
  `examples`, `lookupExample`, `exampleNames`. It absorbed `scriptFor`,
  `guideText` and `patchText` from `run/Main.hs`.
* `Example.Isaac` imports nothing outside `Agentic.*` and `base`, and gained
  `isaacBlurb` beside the `isaacScript` it already had.
* **Neither imports `Workflows.*`, and neither is reachable from it.**

The change is self-contained and it is an improvement on its own terms: the
canned table now lives beside the programs it answers, which is where
`isaacScript` already was and for the reason `Example.Isaac` gives — a key that
*is* the prompt define is a prefix by construction. Nothing needs severing. The
one obligation is that `ci/examples.sh` still pins every field by equality and
still reads the registry out of the binary through `plan --no-such-example`; the
foundation reported it green and the migration re-runs it (§5, step 9).

**4.4 A privacy consequence, load-bearing.** The four inventories, the three
architectures and the foundation report catalogue the owner's personal
configuration in detail — file names, rubric contents, host-specific commands.
agent-cat is **public on GitHub**. Those seven documents are personal-corpus
documents and belong here, under `doc/research/`, not there. The same test
applies to anything future: *a document that names what is in
`~/src/nix/config/ai` is this repository's.* `confer-design.md` is the one
boundary case and it stays in agent-cat: it is a design about agent-cat's own
combinators and PAL parity, and it names the owner's skills only in passing.

Whether those files are already committed to a public branch is a fact only the
coordinator can establish (this design ran under a no-git rule). §5, step 2
names it as a step and not as an assumption.

**4.5 What this repository must never do.** Carried forward from
`Workflows.Registry`'s haddock, unchanged, because it is still true and is now
enforceable by the fact that this package cannot see agent-cat's test tree at
all:

1. Never import from `test/corpus` or `tier1`. The toolbox is not conformance
   and must not be able to make a corpus gate red.
2. Never write outside the directory the run was given. Every argv is in
   `Workflows.Evidence`, and none of them points at `~/src/nix/config/ai`.
3. Every rubric names its source file and section in a haddock line.

---

## 5. The migration, as ordered steps

Steps marked **(git)** are the coordinator's; every other step is a file
operation a builder performs. Steps are sequential. One `cabal build` at a time
per tree.

1. **Move the tree.** `agent-cat/workflows/Workflows/` → `agent-workflows/src/Workflows/`;
   `agent-cat/workflows/bin/Main.hs` → `agent-workflows/bin/Main.hs`;
   `agent-cat/workflows/README.md` → `agent-workflows/README.md`. No file
   content changes except deleting the README's paragraph about the symlink
   (§1.2) and repointing its `cd haskell` usage block at `cabal run wf --` from
   the repository root.

2. **Move the personal-corpus documents.** `agent-cat/doc/research/ai-config-workflows/`
   (all seven files) → `agent-workflows/doc/research/`. **(git)** The coordinator
   establishes whether they reached a public branch and, if so, whether the
   removal is a delete-forward or a history rewrite. `confer-design.md` stays in
   agent-cat (§4.4).

3. **Sever agent-cat.** Delete `library workflows` and `executable wf` from
   `haskell/agentic.cabal`; delete the `haskell/workflows` symlink; delete
   `haskell/ci/workflows.sh`. Leave `Agentic.Cli` in the library's
   `exposed-modules` and leave `run/Main.hs`, `Example/Harden.hs` and
   `Example/Isaac.hs` untouched.

4. **Write the package.** `agent-workflows.cabal`, with one `common settings`
   stanza (`-Wall`, `Haskell2010`, the dependency list narrowed to what the tree
   actually uses: `base`, `text`, `agentic`), a `library` at `hs-source-dirs:
   src` carrying the twenty-one modules of §1.2, and `executable wf` at
   `hs-source-dirs: bin` with `-threaded`. Omit `Workflows.Git.Stack` from
   `exposed-modules` until step 8 — a stanza that names a module with no file is
   the exact failure this tree arrived in.

5. **Write the build plumbing.** `flake.nix` (§3.2), `cabal.project` (§3.3),
   `.envrc` (§3.4), `.gitignore` (§3.5). **Gate:** `nix develop` enters and
   `cabal build all` completes with **zero warnings**.

6. **Reconcile the registry with the gate.** `ci/workflows.sh` (§9) is
   transcribed from `haskell/ci/workflows.sh` with three changes: the
   `nix develop path:./.` wrapper is dropped (the caller is in the devShell), the
   binary is resolved once with `cabal list-bin exe:wf` and invoked directly from
   the repository root so that `running` parties inherit the right cwd, and the
   `agentic-run` cross-check at the end is replaced by §9's `Agentic.Cli`
   contract check. Then pin the eight rows the registry already carries.
   **Gate:** `./ci/workflows.sh` green on eight rows, or the row is removed from
   the registry until it can be.

7. **Audit the four unverified flagship modules** (§1.5) against three house
   rules before trusting them: WR-1 (every roster-shaping input is total on `""`,
   because `plan` and `cost` supply `""` for an input nobody gave and `panel []`
   is an `error` on a CAF); the revision grammar (a revision body is exactly one
   verdict question and one `amend`); and the read-only rule (every argv is in
   `Workflows.Evidence`). Anything that fails is fixed here, not registered
   around.

8. **Land flagship 5** (`Workflows.Git.Stack`, §6.5), which is the module the
   stop landed in, and register flagships 3 and 4, which are written and
   unregistered. **Gate:** `resolveFn` has three call sites and `commitFn` has
   four; if either needed a variant, the library is wrong and §6 is what moves.

9. **Prove agent-cat is whole.** In `agent-cat/haskell`: `cabal build all` with
   zero warnings, then `ci/examples.sh`, `ci/tier0.sh`, `ci/tier1.sh`,
   `ci/policies.sh`, `ci/citations.sh`, `ci/acp.sh`. The examples gate must pin
   every field at the same values the foundation report recorded; a moved number
   means the severance took something with it.

10. **(git)** Two commits, two repositories, in that order: agent-cat's
    severance first (it is a deletion and cannot break this repository), then
    this repository's initial import.

---

## 6. The flagship five, and the sixth that was ruled later

Unanimous across the three proposals on four: `review`, `green`, `commit`, and
the `fess`/`audit` program. The fifth is `stack` (A and C's `restack`) over B's
`forge`, for two reasons. **The evidence:** `restack` is the best-engineered
command in the corpus and every piece of its rigour is currently *requested*
rather than *held* — record the baseline, verify each resolution, reach a
fixpoint, prove nothing was lost — and it is the only one of the five that
exercises a handle bound before a destruction and read after it. **The disk:**
`agentic.cabal` already names `Workflows.Git.Stack`, which is where the builders
were stopped. `forge` is a near-literal transplant of a workflow already written
as prose; it lands in wave 2 (§8), where pricing six phases across three models
is the demo.

**§6.6 was added after the roadmap closed** and is not a sixth flagship: it is
one row, `wiggum-duet`, ruled by the owner on 2026-08-20 and designed in full in
`doc/research/duet-design.md`. It sits here rather than in §8 because what it
demonstrates is a *language* capability the other five have no use for — a
program reading where its own questions land — and a reader comparing the six
sketches should see it beside them.

House conventions in every sketch: one import (`Workflows.Prelude`), rubric text
from `Workflows.Rubrics.*` named after its md source, and a decision's tier named
in a comment where it is not obvious. Three tiers, and the rule is **decide as
early as possible**:

| tier | mechanism | costs | when |
|---|---|---|---|
| 1 | ordinary Haskell over a `taking`/`input` `Text`, before the `Program` exists | **zero questions, zero paths** | the fact is in the invocation: which languages the diff touches, which rung, which roster |
| 2 | `decide` over a receipt | zero questions, one path | the fact exists only after the world ran something |
| 3 | an asked flag | one question, one path | the fact is a judgment |

### 6.1 `review` — the ladder *(rows: `review-quick`, `review-deep`, `review-sec`, `review-heavy`)*

**Serves** `quick-review`, `code-review`, `sec-audit`, `deep-review`,
`heavy-review`, `review-github-pr`, `alexey`, the eleven reviewer agents, and six
skill lenses (`abstraction-review`, `validated-code-review`, `alexey-review`,
`comment-audit`, `eliminate-dead-code`-as-lens, `ponytail`).

```haskell
-- src/Workflows/Review/Ladder.hs
reviewLadder :: Tier -> Parameterized
reviewLadder tier =
  taking (input "scope" (input "paths" noInputs)) \scope paths ->
    -- TIER 1. The roster and the linter set are decided in ordinary Haskell,
    -- before a question exists: `deep-review`'s nine-row extension->agent table
    -- costs zero questions AND adds no path, and `wf plan --raw` prints the
    -- panel that will run. WR-1: `paths` is "" when nobody gave it, and "" must
    -- mean THE DEFAULT ROSTER, never the empty one — `panel []` is an `error`.
    let roster = tierRoster tier (languagesIn paths)
        probes = tierDossier tier (languagesIn paths)
     in defining [SomeFn reportFn, SomeFn suggestionsFn] W.do

      -- One receipt the world authored, bound once and spliced into every
      -- member below. `heavy-review`'s "every pass examines identical code" is
      -- this handle, and not a sentence.
      snapshot <- ask (tool "scope" `running` scopeArgv scope) [wf|{snapshotBrief}|]

      -- TIER 2. The independence sentinel, in ONE spelling where three files
      -- carry three, and a terminal the compiler will not let the author drop.
      probe       <- ask noHistoryProbe [wf|{sentinelBrief}|]
      independent <- decide lastNonEmptyLineIs probe ["NO-HISTORY"]
      when independent $ W.do

        -- hlint, clippy, ruff, mypy, bandit, shellcheck, statix, deadnix,
        -- clang-tidy, cppcheck, Print Assumptions, and sec-audit's three fixed
        -- regexes. Receipts, not "if available, run X".
        facts <- dossierOver probes [wf|{factsBrief}|]

        -- The panel: one Ask per roster row, each brief carrying the sibling
        -- table DERIVED FROM THE SAME LIST and the one `findingSchema`. Each
        -- member `servedBy` its own engine; the members that must stay
        -- comparable deliberately carry no pin.
        found <- documentPanel (withEvidence roster snapshot facts) snapshot

        -- `deep-review`'s completeness gate as a free decider over the fold's
        -- own fence labels, and a total two-armed branch whose shared tail is
        -- one function both arms call.
        whole <- decide containsLine found (map fenceOpen roster)
        if whole
          then W.do call_ reportFn (arg found :> arg facts :> arg (tierName tier) :> noArgs); stop
          else W.do call_ reportFn (arg found :> arg facts :> arg incompleteLabel :> noArgs); stop
```

**What it deletes:** eleven copies of the finding schema; five copies of the
ladder paragraph; three spellings of the sentinel; `verify-model-dispatch.py` and
the whole attestation apparatus (`servedBy` + `fallingBackTo` + `--require-pinned`);
`review-github-pr`'s four shouted prohibitions, which become an absence.
**What it buys:** `wf cost review-heavy --input-arg paths="$(git diff --name-only main)"`
is a min, a max and a path count for *this* diff, before the first token.
**Its honest cost:** the rung is chosen in Haskell, so `plan` must be given the
same inputs the run will use or it prices a different program — which is what the
gate's per-row pin makes a checked fact rather than a caveat.

### 6.2 `green` — the gated fix loop *(rows: `green-ci`, `green-tree`, `green-flaky`, `green-web`)*

**Serves** `fix-ci`, `bugbot`, `bugbot-stack`, `flaky-rust`, `webfix`,
`nix-rebuild`'s gate, and the gate inside every other program.

The load-bearing fact, verified in `Agentic/Shell.hs`'s answer table: **a verdict
question put to a `running` tool approves on exit 0 and objects with the
command's own first failing line on nonzero** — and a command that is missing or
times out is a *gap*, not an answer. So check-fix-recheck is a revision whose
review clause is the exit code, and the repair reads the CI's own words rather
than a model's paraphrase of them.

```haskell
-- src/Workflows/Fix/Green.hs
greenProgram :: Rung -> Parameterized
greenProgram rung = taking (input "pr" (input "check" noInputs)) \pr checkName ->
  defining [SomeFn botSweepFn, SomeFn commitFn] W.do

    -- The ledger, bound ONCE: bytes this program did not author. Every later
    -- phase reads THIS handle, so a comment arriving mid-run has no way in —
    -- `bugbot` phase 5's scoping invariant, made structural.
    inventory <- ask (tool "threads" `running` ghGraphqlThreads pr) [wf|{inventoryBrief}|]
    call_ botSweepFn (arg inventory :> arg (exclusionsFor rung) :> noArgs)

    gated <- revising inventory (atMost (rungTrips rung)) \state -> W.do
        checks <- ask (tool "checks" `running` rungCheck rung pr checkName) [wf|{checksBrief}|]
        amend (ask (model "repair" `servedBy` "opus") [wf|
            {repairBrief}
            {codeRule}       -- Rubrics.Discipline
            {noDeferral}     -- fix-all
            {state}
            {checks}|])

    case gated of
      Settled state -> W.do call_ commitFn (arg state :> arg ciScope :> noArgs); stop
      -- The arm `fix-ci` does not have: the run ends naming the check still red,
      -- and the tree keeps every edit the repairs made.
      Unsettled state -> W.do ask_ (tool "report") [wf|{stillRedBrief}{state}|]; stop
```

* **`green-flaky`** replaces the check party with `drawing n` over the suite —
  *n* independent draws are *n* questions, priced apart — and inserts a tier-2
  decider over the collected receipts that separates **flaky from broken before
  any model is consulted**. That distinction is the entire task and
  `flaky-rust.md` cannot make it.
* **`green-web`** replaces it with the Playwright runner: "resolve the issues"
  becomes a reproduction that stopped reproducing. This is the REWORK `webfix`
  needed, discharged by the shape rather than by a rewrite.
* **`revising` and not `revisingOn`**: with an exec review, `AbandonedOn` is
  unreachable — the shell table yields approve-or-object and never refuse.
  `revisingOn` is right where the review is a model whose refusal must end the
  run, which is `botSweepFn`'s per-item shape.

### 6.3 `commit` — the commit-discipline pipeline *(rows: `commit`, `commit-push`, `commit-recommit`, `commit-bankruptcy`)*

**Serves** `commit`, `push`, `recommit`, `bankruptcy`; **called by** `green`,
`stack`, `issue`, `account`, `wiggum`. The most-referenced node in the corpus's
A–L half: three in-edges, zero out-edges, and the end of `bankruptcy`'s hedge
over whether it means "the `commit` skill or `$command-commit`".

```haskell
-- src/Workflows/Git/Commit.hs
commitFn :: Fn '[ 'CodeText, 'CodeText] 'CodeAck
commitFn = function "commit.series"
    (takes @"scope" Text . takes @"style" Text $ noParams) \scope style -> W.do
      series <- ask (reasoning (model "decompose")) [wf|
          {commitPrinciples}      -- three decomposition principles
          {categoryOrdering}      -- six change categories, in dependency order
          {messageFormat}         -- 50/72, and the trailer
          {style}
          {scope}|]
      act (tool "stage" `running` gitAddPatch) [wf|{stagingStrategy}{series}|]
      done

commitProgram :: CommitRung -> Parameterized
commitProgram rung = taking (input "scope" noInputs) \scope ->
  defining [SomeFn commitFn] W.do

    -- `bankruptcy`'s postcondition, which it states and never checks: a handle
    -- bound BEFORE the destructive middle.
    before <- ask (tool "tree" `running` gitRevParseTree) [wf|{treeBrief}|]

    call_ commitFn (arg scope :> arg (rungStyle rung) :> noArgs)

    -- `commit.md`'s own per-commit checklist item — "does the code compile and
    -- pass tests at this point?" — as a receipt rather than a question to
    -- oneself. This IS `recommit`'s entire content, priced at
    -- commit + n .. commit + 3n over n paths.
    gated <- gate makeTest repairBrief (model "repair") before (atMost (rungTrips rung))

    case gated of
      Settled tree -> W.do
        after <- ask (tool "tree" `running` gitRevParseTree) [wf|{treeBrief}{before}|]
        same  <- decide containsLine after [unchangedMarker]
        when same $ when (rungPushes rung) $ W.do
          act (tool "push" `running` gitPushLease) [wf|{pushBrief}|]
          act (tool "pr"   `running` ghPrCreate)   [wf|{prBrief}|]
      -- The file's own advice — "prefer a slightly larger commit over a broken
      -- repository" — as the language's exhaustion semantics rather than as
      -- advice. The most satisfying single correspondence in the corpus.
      Unsettled tree -> W.do ask_ (tool "report") [wf|{largerCommitBrief}{tree}|]
```

### 6.4 `fess` — the audit *(row: `fess`)*

**Serves** `commands/fess.md` and `agents/fess-auditor.md`, which `catalog.nix`
aliases to one file — two catalog entries over one rubric, which is one program
reachable by two names here. **Called by** `wiggum`, `green`, `issue`,
`dead-code`, which is what `fix-all` and `wiggum` ask for by name.

The file's most agent-cat-shaped paragraph is its independence protocol, and it
is **a gate whose failure downgrades rather than aborts**: *"If that attestation
is absent, run the audit but report that its independence was not verified."*
Because a branch is terminal, both arms must be written — and the shared tail is
one function both arms call, one argument apart.

```haskell
-- src/Workflows/Fess.hs
fessAudit :: Parameterized
fessAudit = taking (input "change" noInputs) \change ->
  defining [SomeFn fessReportFn] W.do

    -- Evidence FIRST, because the md ends by demanding "quote the command and
    -- the relevant output" of an agent with no structural guarantee it ran
    -- anything. Here the world runs the argv and the receipt is not the
    -- answering model's to write.
    evidence <- dossierOver fessProbes [wf|{evidenceBrief}{change}|]

    -- Ten sins, ten stances, ten engines, one fenced document — where the md
    -- asks all ten in one turn and one weak category disappears into the
    -- paragraph. The anti-manufacturing guards ride in the roster's preamble:
    -- do not resolve uncertainty by claiming none, and do not resolve it by
    -- manufacturing a sin.
    findings <- documentPanel (withEvidence fessRoster changeV evidence) changeV

    attested <- decide lastNonEmptyLineIs evidence ["NO-HISTORY"]
    if attested
      then W.do call_ fessReportFn (arg findings :> arg evidence :> arg verifiedIndependence   :> noArgs); stop
      else W.do call_ fessReportFn (arg findings :> arg evidence :> arg unverifiedIndependence :> noArgs); stop
```

`unverifiedIndependence` already exists at `Rubrics/Discipline.hs:169`, and its
whole shape is the one this program needs: **a report that did not establish
something does not get to imply it.**

> **[Amendment, 2026-08-19 — the count was wrong.]** "Ten sins, ten stances, ten
> engines" above is **eleven** of each. `agents/fess-auditor.md`'s `## Audit
> Rubric` carries eleven bold sections, and the first transplant of
> `Rubrics.Fess.sins` shipped ten: the missing one is **Loose ends**, the file's
> last section — debug prints, hardcoded paths and credentials, dead code from
> incomplete refactors, unused imports, files that should have been deleted,
> unjustified dependencies, undocumented breaking changes, commented-out code,
> unreachable branches, speculative config knobs, and the rule *"Delete or
> commit — don't leave purgatory."* The landing verification caught it and it is
> restored in the file's own position (eleventh, after *verification gap*).
>
> The sketch above is left as it was written rather than quietly corrected,
> because how the count was lost is the more useful record: a compressed reading
> of a rubric loses the section with no single dramatic failure in it, which is
> precisely the section the source file puts last. The consequence a reader
> should carry forward is that the `fess` row's ceiling in `ci/workflows.sh` is
> **16**, not the 15 this design priced.

### 6.5 `stack` — restack and the git family *(rows: `stack`, `stack-rebase`, `stack-rebase-fix`, `stack-cleanup`)*

**Serves** `restack`, `rebase`, `rebase-and-fix`, `cleanup`, and `resolve` as a
`Fn` with three callers. **This is the module the builders were stopped in, and
it is what step 8 lands.**

```haskell
-- src/Workflows/Git/Stack.hs
resolveFn :: Fn '[ 'CodeText] 'CodeText
resolveFn = function "git.resolve" (takes @"agents" Text $ noParams) \agents -> W.do
    merged <- ask (reasoning (model "resolve")) [wf|
        {resolveBrief}     -- preserve the incoming semantics AND the current intent
        {orthogonalRule}   -- step 4: when both sides added something orthogonal,
                           --         combine them; do not pick one
        {agents}|]
    answer merged

stackProgram :: StackRung -> Parameterized
stackProgram rung = taking (input "trunk" (input "agents" noInputs)) \trunk agents ->
  defining [SomeFn resolveFn, SomeFn commitFn] W.do

    -- STEP 1. The baseline: a receipt bound at depth 0 and LIVE FOR THE WHOLE
    -- RUN. "Record the starting state so the report can prove nothing was lost"
    -- is, in Markdown, a request to remember.
    baseline <- ask (tool "tips" `running` gtLsWithTips) [wf|{baselineBrief}|]

    -- STEP 7 is a fixpoint: main moved, so go back to step 2. Steps 4-6 live in
    -- the amendment's single question, because a revision body holds exactly one
    -- review and one `amend` — stated here rather than discovered.
    settled <- revising baseline (atMost 3) \state -> W.do
        current <- ask (tool "current" `running` gtLsStack) [wf|{currentBrief}|]
        amend (ask (reasoning (model "restack")) [wf|
            {restackBrief}
            {rerereNote}
            {state}
            {current}
            {agents}|])

    case settled of
      Settled state -> W.do
        -- STEP 5, properly: each resolution verified by a real build, with the
        -- build's own failing line as the objection.
        built <- gate nixFlakeCheck repairBrief (model "repair") state (atMost 3)
        case built of
          Settled tree -> W.do
            -- STEP 9. The proof: a `git range-diff` receipt read against the
            -- step-1 handle by a decider that costs nothing.
            proof  <- ask (tool "range" `running` gitRangeDiff) [wf|{proofBrief}{baseline}{tree}|]
            intact <- decide containsLine proof ["=  "]
            when intact $ when (rungSubmits rung) $
              act (tool "submit" `running` gtSubmitStack) [wf|{submitBrief}{proof}|]
          Unsettled tree  -> W.do ask_ (tool "report") [wf|{stillRedBrief}{tree}|]
      Unsettled state -> W.do ask_ (tool "report") [wf|{fixpointNotReachedBrief}{state}{baseline}|]
```

**What this proves that the other four do not:** a live baseline handle across an
entire branching program, a nested gate inside a fixpoint loop, an `Fn` with
three callers, and a mechanical proof-of-no-loss. It is also the one that shows
the grammar's charge honestly: step 5 wants *verify-then-proceed* inside each
trip, and a revision body holds one review and one amendment, so the
verification lives in the amendment's prompt and the real build gate stands
outside the loop. That is written above, not hidden.

### 6.6 `wiggum-duet` — the loop across two panes *(row: `wiggum-duet`)*

**Serves** the owner's ruling of 2026-08-20, which is not a corpus file: two
`agent-deck` sessions he primes himself, one `wf run` that starts a work loop in
the first and a partner review in the second, and no ownership of either.
**Calls** `commitFn`, `cleanupRoundFn`, `resolveFn` and `fessReportFn`, exactly as
`wiggum` does, plus `wiggum`'s own three bodies with one pin moved in each.
**Added after the five**, because it is the first row whose shape is a fact about
the *invocation* and not about a Markdown file.

The load-bearing paragraph is a gate, and it is the sharpest one in the tree:
*the judge must be reachable in a conversation no work-side question touches.*
`wiggum` could only ever refuse that outright — its judge and its round account
are one serving model, so no route table can separate them — and under a
two-pane split the refusal became wrong. What settles it is a **fourth run
fact**, `run.routes`: the route table as the runner resolved it, one line per
answerer, in the backend's own spelling. Read with `run.engine` it is decidable,
in ordinary Haskell, before the `Program` exists.

```haskell
-- src/Workflows/Deciders.hs — one predicate, two callers, so they cannot drift
judgeIsElsewhere :: Text -> Text -> Text -> [Text] -> Bool
judgeIsElsewhere routes engine judgePin workPins =
  not (sharesOneSession engine) || (judge `notElem` works && judge /= dflt)
  where judge = routedBackend routes judgePin
        works = map (routedBackend routes) workPins
        dflt  = routedBackend routes routeDefaultLabel

-- src/Workflows/WiggumDuet.hs — the pins, and the bind that is the whole row
duetWorkPins :: [Text]   -- every pin the WORK reaches: the roster less the
duetWorkPins =           -- judge's own, so a rung cannot be routed at the judge
  filter (/= partnerPin) routablePins

duetRoster :: Roster   -- review-heavy's four lenses, re-pinned; `servedBy`
duetRoster =           -- replaces the chain, so the ladder is dropped with it
  [l {lensParty = onPartner (lensParty l)} | l <- [alexeyLens, …]]

case judgeIsElsewhere routes engine partnerPin duetWorkPins of
  False -> defining duetRefusalTable  W.do …stop     -- one function, one act
  True  -> defining (duetTable …) W.do
    …
    first  <- call (duetRoundFn trunk) (arg goal :> arg orchestration :> noArgs)
    …
    review <- call (duetReviewFn dir)  (arg first :> noArgs)   -- THE DUET
    second <- call (duetRoundFn trunk) (arg goal :> arg review  :> noArgs)
```

**What this proves that the other five do not:** that a program can assert
something about *where its own questions land* — which is a property of the
command line and was previously invisible to every program in the tree — and
refuse before spending on it. Three consequences are worth stating plainly. The
second conjunct is not belt-and-braces: this row's reach is only its own asks,
every borrowed callee takes the **default**, and a judge sitting on the default
read the commit decomposition, the conflict resolution and the cleanup review —
so the *inverted* split is refused as firmly as the shared one, and it is the
inversion an operator will actually type. The fourth argument is a **list** for
the same reason one step further out: a borrowed callee arrives on the ladder's
own name, so `--route opus=deck:<judge>` beside `--route partner=deck:<judge>`
puts those same three questions in the judging pane with the judge on neither the
default nor `worker`, and a gate comparing two names accepts it. The list is
static because the gate runs before the `Program` exists; `ci/workflows.sh` holds
it against `list --json`'s `pins`, which is `Agentic.Chains.servedChains` over the
built program, so the one part that could rot silently does not. What the check
*cannot* see is that `agent-deck` takes `<id|title>` for every verb, so one pane
under two selectors is two texts here — recorded in the predicate's haddock and in
the guide as a rule for the operator, not as machinery. And neither pin takes a
`fallingBackTo`: a ladder relabels the model axis on the next rung, so a dead
partner pane would move the judgment to whatever answers the next rung, which
resolves through the default, which is the work's pane. A dead pane is a dead
question. The price is `minFold 2, maxFold 50, over 34 paths` — `wiggum`'s shape
to the digit but for the four-seat review, which is bought once and only on the
two-round arm.

---

## 7. The triage

Classes: **T** = its own program · **R** = a program, but the md needs
rethinking first (the rethink is named) · **K** = keep as Markdown, honestly ·
**F** = folds into a named host. Every **F** names its host; every **K** names
why. Where the three proposals disagreed, the ruling and the loser are named in
the cell.

### 7.1 Commands, A–L (31)

| # | Command | | Host / design |
|---:|---|:-:|---|
| 1 | `alexey` | F | `review`, rung `alexey`: one lens from `alexeyGears`, principles composed *before* stance (the file's own Conflict rule as composition order); the two 290-line references are `--input-file`, not prompt bulk |
| 2 | `assess` | F | `pr-threads`, mode `assess`: the read-only arm; its and/or across three `-pro` agents becomes tier-1 roster selection |
| 3 | `bankruptcy` | F | `commit-bankruptcy`: `gitRevParseTree` before and after, `decide containsLine`, `call_ commitFn`; the postcondition it states and never checks becomes the gate |
| 4 | `breakdown` | F | `org-tasks`, rung `breakdown`; `[ATOMIC]`, `[AMBIGUOUS]` and no-expertise are three deciders and three arms |
| 5 | `bugbot-stack` | F | `green`, scope `stack`: `gtLs` receipt enumerates, `call_ botSweepFn` per PR with the exclusion policy as an *argument* rather than a quoted paragraph; an exhausted sweep yields the partial tally |
| 6 | `bugbot` | F | `green` (`botSweepFn`). The `gh api graphql` inventory is bound once, so a mid-run comment structurally cannot enter; per item `revisingOn (atMost 2)` settling on an `isResolved: true` receipt |
| 7 | `capture` | K | Three lines onto `~/org/wiki/CLAUDE.md`; the interesting logic is outside the corpus. Unanimous |
| 8 | `cleanup` | F | `stack-cleanup`: four obligations, four `Gates.gate`s per branch; the `nix develop --command` hedge disappears because the argv is program-authored |
| 9 | `code-review` | F | `review`, rung `repo` (a dozen concerns = twelve roster rows). Its *mutating* half — it writes tests and docs — is authority confusion and leaves the review: `productize`, or `green` behind `confirm (person "owner")` |
| 10 | `commit` | **T** | **Flagship 3** |
| 11 | `deep-review` | F | `review-deep`. Flagship 1 is written from this file |
| 12 | `discover-bundles` | T | `bundles`: six reject conditions as deciders that fire *before* any paid scoring; seven weighted criteria as a panel; candidates as `--input-file`; read-only structural, which matters most on a program reading adversarial text |
| 13 | `eliminate-dead-code` | F | `dead-code` (the command is an honest thin adapter; the machinery is the skill's) |
| 14 | `expense-report` | T | `expense`: person in *binding* position driving `revisingOn` — accept settles, edit amends with the correction spliced, abandon stops; the decorative `REVIEW` flag becomes a decider gating that loop |
| 15 | `fix-alert` | **R**→F | `nix`, rung `alert`. *Rework:* naming `caveman` beside a diagnostic skill compresses the very alert text whose details decide the diagnosis. Drop it from the diagnostic path, or make compression an earlier question with its own handle. Then the labels route by `anyLineStartsWith` at zero cost |
| 16 | `fix-ci` | F | `green-ci`. Flagship 2's shape; its silent copy of `bugbot`'s protocol becomes `call_ botSweepFn` |
| 17 | `fix-github-issue` | F | `issue`, rung `worktree`; "leave it uncommitted" stops being an instruction and becomes a `git status --porcelain` receipt read by a decider |
| 18 | `fix-integration` | F | `nix`, rung `integration`; the hardcoded error string becomes a second input whose sample carries today's text, so it generalises without losing its default. (B said keep-as-md; A and C carry it, and the input is one line) |
| 19 | `fix-transcript` | F | `prose`, mode `transcript`. The injection guard is structural: the transcript is a `{hole}` — data with three meanings, never fusing with the literal beside it |
| 20 | `fix` | T | `issue`: three cheap gates decide whether *any* expensive work happens, each feeding an `if` whose false arm is `stop`; then `call_ commitFn`, `call_ botSweepFn` |
| 21 | `flaky-rust` | F | `green-flaky`: `drawing n`, then a decider over the collected receipts separating flaky from broken *before* a model is consulted. Generalised past Rust — the argv is an input |
| 22 | `forge` | F | `effort`, rung `forge`. The command is a pure entry point and its no-drift clause is exactly right: as a row over the skill's program there is nowhere to restate |
| 23 | `gravity` | K | A stance prompt is a stance prompt; machinery adds cost and subtracts candour. **Its second half is harvested**, compressed and reworded, into the challenge rubric *every* seat of the family stands under — all three `confer` seats through `underChallenge`, and `second-opinion`'s single party — and its "pull it back to reality" is what the `against` seat's stance is doing (§8). That is the home A was looking for when it folded it into `teams` |
| 24 | `halt` | F | `account`, kind `halt`: `call_ commitFn`, `call_ journalFn`, the report panel, one act writing to `~/dl`. Its emitted `fess` instruction is a define spliced by one hole — a program authoring a prompt, where the boundary is a hole rather than a hope |
| 25 | `heavy-review` | F | `review-heavy`. Its four load-bearing guarantees become: one snapshot handle, the sentinel terminal, `servedBy` attestation, a total `case` for completeness |
| 26 | `heavy` | F | `effort`, rung `heavy`. Its one branch is `anyPathMatches ["*/positron/*","*/pos/*"]` at tier 1 — zero questions where the md spends a turn asking where it is |
| 27 | `infer-tasks` | F | `org-tasks`, rung `infer`. The thirteen-item self-grading checklist *splits*: the mechanical eleven become deciders at zero questions, the two judgments go to a differently-`servedBy` party — a second party checks the first |
| 28 | `initialize` | **R**→F | `claude-md`. *Rework:* the "if one already exists" clause silently changes the output *kind* (a file vs. a critique). Split it into two named outcomes first; then it is one decider and two `Fn`s with two terminals, and the mandatory prefix is a `lit` that cannot be paraphrased |
| 29 | `install-service` | F | `service`, op `install`: ten obligations as ten calls; both capital-letter pleas become `ask_ (person "owner")` terminals the run structurally cannot pass; item 10's "test it works" becomes `systemctl`/`curl` receipts |
| 30 | `journal` | K | Its value is editorial taste, and its one mechanical rule (append-only) is better enforced by the filesystem. Worth being `journalFn`, called from `account`; not worth a program |
| 31 | `lefthook` | F | `productize` (`lefthookFn`, two entry points): slicing a section out of a sibling command by prose reference is exactly the coupling that rots |

### 7.2 Commands, M–Z (36)

| # | Command | | Host / design |
|---:|---|:-:|---|
| 32 | `markdown` | F | `Workflows.Report.suggestionsFn`, the tail of every review rung. Being forced to name its input is the fix — today it depends on conversational antecedent |
| 33 | `medium` | F | `effort`, rung `medium`: same shape, smaller `atMost`, cheaper pin. The tier stops being which text was pasted and becomes a price |
| 34 | `meeting-notes` | T | `notes`: ten sections as ten `documentPanel` members with the section names as fence labels; the five quality checkpoints as a **separate** panel on a different `servedBy` — a fact-only discipline audited by the same model is not audited |
| 35 | `narrative` | **R**→F | `account`, kind `narrative`. *Rework:* evidence-gathering and writing are one undifferentiated ask, so the model deciding what is true decides what reads well. Split into a receipt dossier and a writer over it; "distinguish fact from inference" becomes a sourcing gate on another engine |
| 36 | `nix-rebuild` | F | `nix`, rung `rebuild`: the archetypal receipt — `("./build",["system"])` produces bytes that are then the *subject* of the diagnosis. The rework B named (the failure text is missing) is discharged by the receipt |
| 37 | `partner-cleanup` | F | `partner`, role `cleanup`: the drain loop is `revisingOn` settled by an `ls` receipt read by a decider — zero questions per trip. "The sub-agent must not commit" becomes `CodeText`, which has no write authority |
| 38 | `partner-collaborator` | T | `partner` (`ideas=on`): two panels over one commit — the defect panel with a different engine per member, and the idea panel as `drawing 3` on one lateral party, which is what "three wild ideas" *means* |
| 39 | `partner-reviewer` | F | `partner` (`ideas=off`). Ends an ~85 % duplication that has **already drifted** — a differing Category enum, a typo on one side |
| 40 | `prepare-with` | F | `claude-md`, rung `advise`: the `$ARGUMENTS` roster becomes a Haskell table; the eight negative rules become a `fess`-style auditor over the draft rather than eight rules nothing checks |
| 41 | `process-checklist` | T | `checklist`: outer `revisingOn` whose settle test is `decide containsLine ["- [ ] "]` inverted — **zero questions per trip** where the prose spends a full re-read. Ten md lines with the highest structure-to-prose ratio in the corpus; the wave-1 warm-up |
| 42 | `productize` | T | Twenty-one deliverables as a roster priced at 21 before it starts; each a receipt; the five "use web search" cells become one search question **per language present**, not per deliverable |
| 43 | `proofread` | F | `prose`, strength `strict`: the five prohibitions become a second-model diff auditor; the per-file count is the receipt, not a claim |
| 44 | `push` | F | `commit-push`: `call_ commitFn` then two acts. It costs exactly `commit` + 2 — a number, where today it is a sentence |
| 45 | `qanda` | T | One `ask (person "operator")` per decision **in binding position**, each answer live for the questions after it; the roster from `--input-file`. `ship-feature-lite`'s `steer`, already proven. (A called this a rework for having no named input; `taking (input "decisions")` *is* the rework) |
| 46 | `query-builder` | T | `query`: the schema reader answers `CodeText` and therefore cannot act; the data is never in scope to leak because no question puts it there. Three repetitions of "never reveal data" collapse into one type |
| 47 | `quick-review` | F | `review-quick`. Its ladder paragraph comes from `Rubrics.Ladder`, ending the five-file copy-paste |
| 48 | `rebase-and-fix` | F | `stack-rebase-fix`: four `call_`s (`resolveFn`, the restack body, `green`, `botSweepFn`); its unchecked branch↔commit invariant becomes a `gitRangeDiff` receipt |
| 49 | `rebase` | F | `stack-rebase` — `stack-rebase-fix` with the CI/bot tail off. Two commands, one program, two rows, two prices |
| 50 | `recommit` | F | `commit-recommit`: "each commit passes CI standalone" becomes a per-commit `Gates.gate`; cost is `commit` + n .. `commit` + 3n over n paths |
| 51 | `remove-service` | F | `service`, op `remove`. Its generate-a-script-do-not-run-it inversion becomes the named exemplar of structural read-only: every discovery question is `CodeText`, and the script is one `act` |
| 52 | `report` | F | `account`, kind `report`: seven categories as panel members so none can be silently dropped; the estimate is a separate question on a separate engine over the *fold* |
| 53 | `resolve` | F | `Workflows.Git.Stack.resolveFn`, plus one thin row. Already a function in everything but syntax: three prose callers, one parameter, one job, a crisp postcondition (`git diff --check` read by a pure decider) |
| 54 | `respond` | T | `pr-threads`: the comment roster is a `gh pr view --json` receipt; never-posting is an **absence**, not a rule — no party in the program carries a write verb |
| 55 | `restack` | **T** | **Flagship 5** |
| 56 | `retest-categorical` | F | `retest`, tier `categorical`: nine override rows as nine arguments. **Phase numbering ceases to exist**, so the documented off-by-one is unrepresentable |
| 57 | `retest` | T | The parameterized battery: the 674-line spec is `--input-file`, the five-value verdict taxonomy is a total `case`, and `costSummary` prices an eight-model FPGA run **before an FPGA is touched** |
| 58 | `review-github-pr` | F | `review`, rung `pr`: the head-OID gate is two receipts compared in the argv (a decider's needles are literal program text), with `unless … stop`. Its four shouted prohibitions become zero lines — a prompt naming the four commands it forbids contains its own attack |
| 59 | `run-orchestrator` | **R**→F | `wiggum`. *Rework:* steps 5–6 describe a dependency graph the md cannot express. Written as a Haskell `[(Text,[Text])]` and topologically sorted at build time, "identify parallelizable tasks" is a pure computation, not a question |
| 60 | `sec-audit` | F | `review-sec`: three fixed-regex greps as three receipts, plus one `security-reviewer` ask. The deterministic/probabilistic split, on the one command where a fabricated "no secrets found" costs the most |
| 61 | `sitrep` | F | `account`, kind `sitrep`: eight sections over a receipt-backed dossier, so `Measurements` cannot invent a number no command produced; the filename scheme is computed in Haskell from receipts |
| 62 | `smooth` | F | `prose`, strength `light`. "Do not change it overmuch" gets a measure: a restraint gate on another engine asking whether any sentence changed meaning, `revisingOn` amending toward a lighter touch. `smooth` and `proofread` are two settings of one dial |
| 63 | `teams` | T | The most literal panel in the corpus: eleven roster rows, `documentPanel`, a synthesis whose refusal roster derives from the same table — and the devil's advocate correctly a **second tier** over the fold, which a bullet list cannot say. `cost` says 13 before the run |
| 64 | `transcribe-image` | T | `transcribe`: already the right shape and the only command reaching for a second model by default; `revisingOn (atMost 2)` gives "re-review" the stopping rule it lacks. Honest limit: inputs are `Text`, so the image *paths* are the input and a receipt reads them. (A said keep; B and C carry it, and the stopping rule is the level-up) |
| 65 | `tron-debug` | T | `tron`: three `<command>` blocks are argv waiting to be receipts, so the differential's diagnosis cannot rest on a run that did not happen — this command's most exposed failure mode |
| 66 | `webfix` | **R**→F | `green-web`. *Rework:* it has a real oracle (Playwright) and spends none of its four lines using it as one. Then before/after receipts and a settle on the reproduction that stopped reproducing |
| 67 | `wiggum` | F | `wiggum` (the skill's program, §7.4 #1). The command is the entry point |

### 7.3 Agents (25)

| Group | | Host / design |
|---|:-:|---|
| **The eleven reviewers** — `security`, `perf`, `haskell`, `rust`, `cpp`, `python`, `typescript`, `nix`, `bash`, `elisp`, `coq` | F | `Rubrics.Reviewers` rows, host `review`. Each row carries its severity-tiered sections, **its file globs** (which makes `deep-review`'s extension→agent table free), **its tool argv** (which turns seven "if available, run X" wishes into receipts) and its pin. The eleven copies of the finding schema become one define; the four reviewers with no tool block get one — `catalog.nix` already grants all eleven `run-commands`. Two never filter out: `security` and `perf`. Three rows are nearly free: `elisp`'s CRITICAL-1 is one `anyLineStartsWith` over line 1, `rust`'s `// SAFETY:` rule is one more, and `coq`'s `Print Assumptions` is a receipt that is a soundness obligation |
| **The nine `-pro`** — `haskell`, `typescript`, `emacs-lisp`, `nix`, `rocq`, `cpp`, `python`, `rust`, `sql` | F | `Workflows.Parties` (+ `Rubrics.Lang` for the four encyclopedias, sliced by section so a question about laziness splices one paragraph and not 28 KB). Parties, not programs: none contains control flow, a gate, a loop or an output contract. **One exception:** `nix-pro`'s five-step Search Strategy ends in "never assume an option exists without verification", which is a `revisingOn` over a verification verdict — a small `Fn` inside `nix`. `rocq-pro` is orphaned and duplicative of `coq-reviewer`; it stays a name until something calls it |
| `fess-auditor` | **T** | **Flagship 4** |
| `task-breakdown` | F | `org-tasks`: a real analysis→decompose→format pipeline with a completeness gate and three named degenerate cases that are three arms |
| `prd-architect` | **R**→2×T | *Rework:* two agents in one file — a generator and a critic — selected by an unstated condition. Split at the mode boundary into `prd-draft` and `prd-critique` **before** writing either. Unanimous |
| `persian-translator` | F | `translate`: the cleanest `revising` in the corpus — candidate = translation, review = back-translation compared against the source, `atMost n`. Its 50-term glossary is one define; today the loop is stated and unbounded |
| `prompt-engineer` | K | No rubric worth moving, superseded in its own directory by the eleven reviewers, and orphaned. Its one strong idea — the mandatory output contract — survives as a decider, not a plea. Unanimous |

### 7.4 Skills (25), the two prompts, and the external edge

| # | Skill | | Host / design |
|---:|---|:-:|---|
| 1 | `wiggum` | T | `wiggum`, **built last**: it calls almost everything. Its DoD is a `revisingOn` verdict set; "an exhausted revising yields its candidate" is *literally* its "report where you are, what you tried, what you need". Its durable-state section **dissolves** — a program *is* the durable plan, priced before it runs. Structurally it is K unrolled rounds, each a `call_ roundFn` behind a decider over the previous round's receipt: **not** a five-`call_` revision body, because a revision body holds exactly one review and one `amend` |
| 2 | `parallelize` | F | `Panels` + `Gates`, and ~90 % **dissolves**: the ten-bullet list of shared state a subagent must not touch is a hand-written type system for an untyped harness, and no `ask` writes anything here. What survives: the sentinel as one gate in one spelling, and the fan-out cap as panel arity **priced** rather than guessed at 3–5. Seven inbound edges — the most-depended-upon skill in the corpus — one implementation |
| 3 | `fix-all` | F | `Rubrics.Discipline`, spliced into every fixer. Two of its six DoD conjuncts are pure deciders: `wg-*` orphans (`anyPathMatches`) and a green suite (`lastNonEmptyLineIs`) |
| 4 | `validated-code-review` | F | `review`, rung `validated`. Its **entire** attestation apparatus — the `listmodels` preflight, `metadata.model_used` verification, the abort-on-substitution rule, the twelve-row Common-Mistakes table and `verify-model-dispatch.py` — exists because the harness cannot promise which model answered. `servedBy` + `fallingBackTo` + `--require-pinned` make that a type, and delete the script |
| 5 | `abstraction-review` | F | `review`, rung `abstraction` + `Rubrics.Evasion` (the seven patterns) + a five-tag `revisingOn`. "Write the null diff **before** reading the diff" is a sequenced bind, enforced by `W.do` rather than by self-discipline |
| 6 | `denotational-design` | T | `denote`: ten phases each with questions, an artifact and an exit test = ten `documentPanel`/`confirm`/`revisingOn` triples; the "when NOT to use" admission test is a `confirm` before the body; 1,921 reference lines are `--input-file`, not prompt bulk |
| 7 | `alexey-review` | F | `Rubrics.alexeyGears`: twelve review moves as the rubric, four severity gates as four tags, and the explicit precedence ("engineering-principles dictates WHAT, stance dictates HOW") as two defines composed in a fixed order |
| 8 | `caveman` | F | `Prose.compressFn` — the purest define in the corpus, and a transform *on other prompts*, which makes it the first genuinely reusable prompt combinator. Its "output ONLY the compressed text" is a decider at zero cost |
| 9 | `ponytail` *(external, ×6)* | F | `Rubrics.ponytailSlot` + `review` rung `ponytail`. **Transplant the edge, not the text:** a slot the owner fills, or a pin to a model given the external skill. `ponytail-debt` is `anyLineStartsWith ["ponytail:"]` at zero questions |
| 10 | `forge` | T | `effort`, rung `forge`: already a workflow written as prose with an explicit phase/model table. Consensus rounds are panels, the approval pause is `ask_ (person "owner")`, remediation is `revisingOn` back to phase 3, and "never skip phases" becomes unstatable-otherwise. **Pricing forge before running it is the demo** |
| 11 | `anvil` | K | An empty directory: no `SKILL.md`, no catalog entry, no inbound reference. Nothing to port. A greenfield slot to be **elicited**, and inventing one would be the exact species of manufacture `fess-auditor` exists to catch. Unanimous |
| 12 | `comment-audit` | T | `comments`: the extractor is a textbook receipt party (`inventory`, `pending --limit`, `show <id>`, `update --id`); seven verdicts as a `revisingOn` set; the 10–15-per-batch loop is a context-budget workaround an actual cost bound replaces |
| 13 | `eliminate-dead-code` | T | `dead-code`: four non-interleavable phases as four `W.do` segments, the three-advocate debate as a three-member panel folded to one verdict, `cap=N` literally `atMost`, and "markers never escape" as `containsLine "DCE-BEGIN"` at zero questions |
| 14 | `toolkit` | F | `Rubrics.Discipline` + `effort`. A define and nothing more — but it declares the owner's own unpriced cost model, `medium ⊂ heavy ⊂ forge`, which becomes one shape at three `costSummary`s |
| 15 | `it-voice` | F | `Rubrics.Voice.itVoice`; its self-check-before-finishing is a `confirm` gate over the draft. `narrative`, `smooth` and `proofread` all write in this register and none names it |
| 16 | `johnw` | **R**→F | `Rubrics.Voice`, **split**. *Rework:* the largest rubric in the corpus is two things fused — a generation rubric and a critique function (two NEVER lists, a self-review checklist, paired slop examples). **Splitting them is the level-up**: `johnwGenerate` is a define and `johnwCritique` is an `Fn` on a *different* `servedBy`, because the model that wrote the draft is a bad judge of whether it opened with a forbidden opening. Unanimous. The 487 lines and two references are inputs |
| 17 | `persian` | T | `translate`: five phases, phase 3 an explicit review *team* = a panel; `TERMS.csv` authoritative over the lossy `PersianTerms.txt` is a real input with a real ordering; the opus-at-max pin is `servedBy` |
| 18 | `fix-transcript` | F | `prose`, mode `transcript`; the substance is a numbered rule-priority list and the two references are lookup corpora → inputs |
| 19 | `retest` | T | See §7.2 #57. Its `MODELS` set derived from the branch diff by four signals is a receipt feeding downstream phases; its "claim discipline" paragraph — report `PASS`/`SKIPPED`/`QUARANTINED`/`DIVERGE`/`NO-COVERAGE` as distinct states, never collapsed — is a demand for a sum type, hand-written in prose |
| 20 | `skill-creator` | K | Shadowed and dead: `catalog.nix` sources it from the resources flake, so the local copy is unused and its `__pycache__` is stale. Its successor is this repository. Do not port. Unanimous |
| 21 | `swiftui` | F | One `review` roster row keyed on `*.swift` plus a party; its three-branch decision tree is tier-1 Haskell. **The eleven references stay where they are** — third-party, lightly owned, and a domain corpus rather than a rubric (C's reservation, honoured inside A and B's fold) |
| 22 | `node-red` | T | `nodered`: four Python scripts as four `proc` parties. Its "supported admin boundary" and "things to avoid offering" ride on the question and the argv, not in prompt text. Deeply host-specific — **port last**. Unanimous |
| 23 | `docstring` | F | `Rubrics.Docstring` — a pure format rubric with a `confirm` tail; consumed by `prose` and `review` |
| 24 | `add-uint-support` | K | **C's ruling, taken over A's and B's.** It is a mechanical seven-step transformation the harness loads *while editing a file*, which is not a run to price; a workflow would ask a model to do what the skill in context already does. Recorded for the day it changes: its step 1 is a decider, and its hand-off to `at-dispatch-v2` is the corpus's **only true skill-calls-skill pair** — the cleanest existing `call_`, available whenever the owner wants it priced |
| 25 | `at-dispatch-v2` | K | The same, as the callee |
| 26 | `nixos` | F | `Rubrics.Discipline` + `Workflows.Evidence`. Five bullets, three of them hard prohibitions (never decrypt SOPS, never seize the `.nixos-build` lock, `--max-jobs 1 --cores 1` on the VPS). **Permission and safety policy, not procedure:** it rides on the argv and on the question's addressee, never in prompt text |
| — | `git-surgeon` *(external)* | F | `Workflows.Evidence` — hunk-level staging argv, as parties |
| — | `translate-en` *(external)* | F | `translate`, mode `en`: sibling of `persian`; one program, two directions, one glossary discipline |
| — | `prompts/emacs.md` | F | `Rubrics.Personas.emacsPersona`, host `issue`. The corpus's only pure "you are an expert who…", and its persona-stacking is precisely the bulk `compressFn` exists to compress — a latent `call_` the corpus never makes |
| — | `prompts/spanish.md` | F | `Prose.translateFn`: `<instructions>`/`<task>` with a literal `$ARGUMENTS` — the corpus's clearest existing `{name}` hole, and a one-argument `function` |

### 7.5 The tally, and what it means

| | Commands (67) | Agents (25) | Skills + prompts (27) | **Total (119)** |
|---|---:|---:|---:|---:|
| **T** — its own program | 16 | 1 | 8 | **25** |
| **R** — rework first, then T or F | 5 | 1 | 1 | **7** |
| **F** — folds into a named host | 43 | 22 | 14 | **79** |
| **K** — honestly Markdown | 3 | 1 | 4 | **8** |

Behind the owner's 119 files sit **roughly thirty-five programs** — about sixty
registry rows once the rungs are counted apart — and behind those sits **one**
library. That ratio is the design. Eight files stay Markdown and each
names a reason that is not "we ran out of time": two are dead (`anvil` is empty,
`skill-creator` is shadowed by the resources flake), two are thin adapters onto
logic that lives elsewhere (`capture`, `journal`), two are a pair the harness
loads while editing (`add-uint-support`, `at-dispatch-v2`), one is a stance
prompt machinery would only make more expensive (`gravity` — whose text is
harvested anyway), and one has no rubric worth moving (`prompt-engineer`).

---

## 8. The roadmap

Waves are sequential; rows inside a wave are independent. Each wave ends with a
gate that is a fact, not a feeling.

**Wave 0 — the move.** §5, steps 1–6. *Gate:* `nix develop` enters,
`cabal build all` is warning-free, `./ci/workflows.sh` is green on the rows the
registry carries, and agent-cat's eight gates are green after the severance.

**Wave 1 — the flagships, finished.** §5, steps 7–8: audit the four unverified
modules, land `Workflows.Git.Stack`, register `commit` and `fess`. Then the
warm-up that costs a page and proves the library — `checklist` (ten md lines,
`revising` plus a free settle test end to end). *Gate:* `resolveFn` has three
call sites and `commitFn` has four; the finding schema exists once; every rung of
`review` prices differently and the four numbers sit side by side in `wf list`.

**Wave 2 — `confer`, and the panel family.** **`confer` is landed** (below;
`Workflows.Confer` and `Workflows.Rubrics.Stances`, four rows, `ci/workflows.sh`
at 21 pinned and 0 failed). Then `teams` and
`notes`, which are the corpus's two most literal panels and fall out in a page
each without a line of new library. If either needs `Lens` widened, the roster
type is too general and §10's first risk has fired. Then `effort`
(medium/heavy/forge), whose three prices are the owner's own unpriced cost model
finally stated.

**Wave 3 — the daily drivers.** `pr-threads` (respond, assess, bugbot),
`issue` (fix, fix-github-issue), `account` (halt, sitrep, report, narrative, +
`journalFn`), `partner` (three commands, one program, two flags), `org-tasks`,
`claude-md`, `prose` (proofread, smooth, fix-transcript, + `compressFn`). These
mostly `call_` waves 1–2.

**Wave 4 — the audits and the specialists.** `dead-code`, `comments`, `bundles`,
`productize` (+ `lefthookFn`), `nix` (rebuild, alert, integration),
`service` (install, remove), `query`, `expense`, `qanda`, `transcribe`, `tron`.

**Wave 5 — the long ones and the top of the loop.** `retest` (+ categorical),
`denote`, `translate` (persian + spanish + translate-en + the glossary),
`prd-draft` / `prd-critique`, `nodered`, and finally **`wiggum`**
(+ `run-orchestrator`), which wants every callee above. *Gate:* `wf cost wiggum`
reports a finite worst case — the one number an autonomous loop must have before
it starts, and does not have today.

**Amendment, 2026-08-20 — wave 5 is complete, and so is the roadmap, save one
recorded deferral.** §6.2 names a fourth green row, `green-web` (§7.2 row 66's
`webfix` rework, "use the oracle"); it was not built in any wave: no
Playwright argv is carried in `Workflows.Evidence`, and no row prices it. It
is deferred, not dropped — a browser-driving gate is a real `running` party
the day it is wanted, and `Fix/Green.hs`'s header now records the deferral
where a reader of the family will find it. Everything else in §8 landed:
`Workflows.Wiggum` is the table's last row, and the wave's gate is paid:

```
wf cost wiggum
  minFold 2, maxFold 44, over 34 paths
```

`ci/workflows.sh` pins it at `branch, 34 paths, ceiling 44` and reports **72
workflows pinned, 0 failed**; every earlier row's numbers are unmoved. Five things
about that row are amendments to what this section and §7.2/§7.4 predicted, and
each is recorded rather than absorbed:

1. **44 is the second widest ceiling in the table**, past `retest-categorical`'s
   37 and displaced only by §6.6's `wiggum-duet` at 50, which is this same loop
   across two panes. That
   is §7.4 row 1's "it calls almost everything" showing up as arithmetic: five of
   the row's seven declared callees are other rows' functions (`commitFn`,
   `resolveFn`, `cleanupRoundFn`, `fessReportFn`, and the eleven `fess` stances by
   way of `Rubrics.Fess`), so what the top of the loop costs is what the toolbox
   under it costs. The `minFold` of 2 is the refusal to start.
2. **§7.4 row 1's structure was right and its `revisingOn` sits in one place.** The
   row is K unrolled rounds (K = 2), each `call_ roundFn`, the second entered
   behind `decide saysComplete` over the first round's own last line — exactly as
   that cell says, and *not* a five-`call_` revision body. What the bounded
   `revisingOn` turned out to bound is the **done-criteria verdict** over the
   handoff, at `atMost 2`, with `Workflows.Escalation`'s three arms as the three
   endings. The work itself cannot live in an amendment: `Step (Loop c s) ('Body
   r s)` is a `TypeError` and `ifThenElse` exists only at `'Open s`, so a round's
   pipeline is unrolled at the program level and the amendment revises the
   *handoff* rather than the tree. The module header says so plainly. The
   unroll count itself — two — is a design decision rather than a
   construction, and the gate records it in its own words: "a third round
   would be a design decision and would show here."
3. **§7.2 row 59's rework is `stageWaves`.** `run-orchestrator`'s steps 5 and 6
   are a layered topological sort over a `[(Text, [Text])]`, done before the
   `Program` exists — zero questions, zero paths — and its widest wave *is* the
   round's fan-out, which is `skills/parallelize`'s guessed "3–5" computed. The
   remaining six steps are the table's rows; the two that were questions are the
   sort.
4. **One deviation from §7.2 row 67 and `references/fess-audit.md`, deliberate:
   the audit runs once per run and not once per commit.** That reference file
   carves the fix commits and `partner-cleanup`'s own commit out of the per-commit
   rule and then states the obligation this row keeps — "before declaring the work
   done, run one final audit over the last work commit". One eleven-stance fan-out
   immediately before the verdict is that sentence; K of them would be K fan-outs
   for a Definition-of-Done clause stated once, and the per-commit audit is a row
   that already exists (`wf run fess`).
5. **What could not be a program is in the module header, named.** Six items: the
   refresh-after-compaction re-read (a compaction is invisible to a program; what
   it demands — the baseline verification — is the flag at the top of the run),
   the durable *files*, the working policies (`CARGO_TARGET_DIR`, `~/Products`,
   `direnv exec .`, `git-surgeon` — unexpressible, since `Agentic.Shell` runs an
   argv with `proc` and never a shell), "do not enter this mode on your own", the
   four-hour clock, and conferring through PAL. The prohibition that *did* become
   structural is the important one: there is no push argv anywhere in
   `Workflows.Wiggum`, so "do NOT submit or push the stack" is a command that does
   not exist.

**Do the seven REWORKs before wave 3.** They are rethinks, not transcriptions,
and each is one decision answerable in a sitting: `fix-alert` (drop `caveman`
from the diagnostic path), `initialize` (split the two output kinds), `narrative`
(split evidence from prose), `run-orchestrator` (write the dependency graph as a
table), `webfix` (use the oracle), `johnw` (split the generator from the critic),
`prd-architect` (split at the mode boundary). Each one unblocks a program that
would otherwise transcribe a defect.

**Three things to decide before wave 1, not during it.** Taken from C §7, and
all three are the owner's, not a builder's: (1) the **Category vocabulary** —
`deep-review`'s consumer adds `Simplification` and `Dead Code`, no agent file
carries them, and `Rubrics.Finding` has already picked the consumer and said so
in haddock; confirm or overrule it. (2) The **confidence floor** — every finding
carries a self-reported `Confidence: 0-100` and `deep-review` filters on it,
which is a test the model being tested chooses; either it becomes a decider over
a *different* party's judgment, or it is dropped as theatre. (3) What **`anvil`**
means; until it is elicited the slot stays empty.

### 8.1 `confer` — the workflow-native counterpart of PAL's `consensus`

The coordinator's `pal-note.md` makes this a requirement of the design, and
`confer-design.md` is its full specification. Four decisions the architecture
phase owes it, made here.

**Where it lives.** `src/Workflows/Confer.hs` for the program and the roster;
`src/Workflows/Rubrics/Stances.hs` for the four stance defines, the challenge
rubric, the two briefs and the provenance. Stances are rubrics and rubrics live
in `Rubrics/`; the pattern is `Rubrics.Fess`'s, which is ten stances in exactly
the same shape.

**The registry rows: four.** `confer` (three seats, synthesised), `confer-bare`
(the blocks, unreconciled — `review-lite`'s argument that six independent
opinions are worth more unreconciled than one reconciled one), `debate` (the pair
**and the synthesis** — the same `conferOver` at a roster derived by *filtering*
the standing one, so a stance edited once reaches both seats and the fold that
reads them; what it drops is the middle seat and not the synthesis, which is why
it prices 4 and not 3), and `second-opinion` (one lateral party under the
challenge rubric — PAL's `challenge` and `chat` in one program, and the shape the
owner reaches for most often, which is why it is a row and not a flag). **The
confer-shaped gate is not a row**: §5.4 of `confer-design.md` sketches one —
three seats folded to a verdict — and it is a sketch and nothing else; if it is
ever built it belongs with the gates, and it is the one place `panel` is right
because a gate wants a verdict and not a document.

**The two requirements on the foundation, accepted.** Both are one-line signature
generalizations in `Workflows.Panels`, and taking them is what keeps confer from
being a second implementation of a fan-out that already exists:

* **R1** — `asksOver :: (Says a s) => Roster -> Text -> a -> [Ask s]`, widening
  the subject from a live handle to anything a hole may name. Confer's subject is
  an *input*, and an input is a define supplied at run time. `Says` has exactly
  the three instances a hole may resolve to, so this widens the subject to
  precisely the set the prompt could already have spliced, and every existing
  caller resolves through `Says (V h c) s` unchanged.
* **R2** — `documentPanelWith :: (Says a s) => Text -> Roster -> a -> Rhs s 'CodeText`,
  with today's `documentPanel = documentPanelWith reportClosing`. "Report your
  findings and nothing else" is right for a review roster and wrong for a stance
  roster: a party arguing a case is not reporting findings.

**The write is `ask_ reporter`, not a `Fn`** — for now. `confer-design.md` shows
both spellings at identical prices (`askNodes 5` either way) and makes it a
question about whether another rung will ever produce a confer-shaped artefact.
None will in waves 2–5. If `account` later wants one, `conferFn` joins the report
family and the program loses one line.

**The single-backend caveat is in the artefact, not in a footnote.** An unrouted
run binds every addressee to one backend, so three blocks produced by three fresh
ACP sessions of one model are independence *of context*, which is real, and not
independence *of judgement*, which they are not — and a run sent to a live
agent-deck session is not even that, because one durable session serves the whole
run and the later seats have read the earlier blocks. `conferProvenance` says
both, in the program, derived from the roster and conditioned on the run's
header. `acat-engine-party-routing-hcx` has since landed and **the roster did not
move**: routing keys on the serving model, the roster's `servedBy` pins *are*
those keys, and the only thing that changes is the run's header — at which point
the same derived sentence stops disclaiming what is no longer true. The three
seats are pinned to three
distinct primaries (`opus`, `gemini-3.1-pro-preview`, `fable`) for exactly this
reason: two seats on one model are two seats on one backend however the run is
routed.

**And confer does not mirror PAL's tool names.** `thinkdeep`, `debug`,
`codereview`, `analyze`, `planner`, `precommit` and `refactor` are step-numbered
*forms*; the corpus's own commands already cover those shapes and §7 owns them.
Confer is the one PAL tool that is a *shape* — a roster, a fan-out, a fold, a
synthesis — which is why it is the one that gets a workflow. PAL's `challenge` is
a one-line anti-sycophancy rubric and is a shared define, not a program. PAL MCP
stays configured; confer is an alternative offered, not a replacement mandated.

> **[Amendment, 2026-08-19 — `confer` landed, and one requirement went unpaid.]**
> `Workflows.Rubrics.Stances` and `Workflows.Confer` are in, with the four rows
> this section ruled on — `confer`, `confer-bare`, `debate`, `second-opinion` —
> and the §5.4 gate sketch is not among them, as ruled; it remains a sketch in
> `confer-design.md` and is defined nowhere here. The numbers are **observed and
> not derived**: `confer` `pipeline`, `size 6`, `askNodes 5`,
> `codes text, text, text, text, receipt`, `minFold 5, maxFold 5, over 1 path`;
> `confer-bare` and `debate` `size 5 / askNodes 4 / 4, 1 path`;
> `second-opinion` `size 3 / askNodes 2 / 2, 1 path`. Every one matches
> `confer-design.md` §5's table exactly. `wf plan … --require-pinned` passes for
> all four, `--scripted` exits 0 for all four at `billFresh = billMemo`, and the
> three seats receive **three different** canned answers — which is the assertion
> that proves the shared rubric comes *after* each seat's stance.
>
> **R1 was not taken, and confer carries the debt instead.** `asksOver` still
> reads `(KnownIx h s) => Roster -> Text -> V h 'CodeText -> [Ask s]`, and
> confer's subject is an input, which is a define. `Workflows.Panels` is another
> track's module and a signature change to a shared fan-out is not a confer
> builder's to land unilaterally, so `Workflows.Confer.stanceAsks` writes the
> four chunks out — the same four, in the same order, importing `memberNote`
> rather than re-deriving it — under a haddock that names R1, names the two
> worse alternatives, and says the function is deleted the day R1 lands. **This
> is the one open item of wave 2's confer row.** R2 costs nothing: the fold is
> inlined as `confer-design.md` §1.5 writes it, which is what `documentPanelWith`
> would have spelled.
>
> **Two departures from `confer-design.md`, both repairs, neither priced.**
> (1) §1.4's provenance table is `bullets [(lensName l, lensOwns l) | l <- r]`
> and its next sentence reads *"Those are the models the program pins"* — which
> names something the table does not carry and **cannot**: `Agentic.Workflow`
> exports no accessor for a party's pin, so no caller can print a roster as its
> serving models. The sentence now names the seats and describes the pins.
> (2) §1.5's artefact prompt splices the blocks and the recommendation but not
> the subject, so the written confer would not say what decision it was about;
> §5.1's and §5.3's write prompts both splice theirs. The subject is spliced in
> all three. A splice costs nothing a bill counts, so `askNodes` is unmoved.
>
> **The routing statement is in the module header**, in `§0.1`'s own words: the
> **three panel seats** are pinned to three distinct primaries, and it is those
> three *pins* a `--route` table splits — a route names a serving model and
> never a party, so what makes the roster splittable is the distinctness of the
> primaries and nothing about the seat names; the synthesis rides the `for`
> seat's backend because both are `reasoning`, whose primary is `opus`, and no
> route table keyed on the serving model can separate them. That is written on
> the module rather than left in a design document, so a reader routing this
> program is not surprised.

---

## 9. This repository's gates

**These are explicitly not agent-cat's conformance gates.** `tier0`, `tier1`,
`bisim`, `ci/examples.sh`, `ci/policies.sh`, `ci/citations.sh`, `ci/acp.sh` and
`ci/deck.sh` stay in agent-cat and answer questions about *the language*. This
repository can no longer make any of them red, and that is a property of the
split rather than a rule anyone must remember: the package cannot see agent-cat's
test tree.

`ci/workflows.sh` — one script, run from the repository root inside the devShell:

1. **Build.** `cabal build all`, and **zero warnings** is part of the gate. A
   warning nobody can fix is a warning everybody learns to scroll past.
2. **The registry is read out of the binary**, never transcribed. A row the
   pinned table does not carry is a failure; a pinned name that is registered
   nowhere is a failure. **A workflow cannot be registered without being priced.**
3. **Per row, three pins and one run:**
   * `wf plan NAME` → **`level` by equality.** A program that gained a rung
     gained a design decision.
   * `wf plan NAME` → **`paths` by equality.** A new branch is a design decision
     and the owner should have to acknowledge it.
   * `wf cost NAME` → **`costMax` as a ceiling that only ratchets down.** A
     budget is a promise about the worst case; it may fall freely and rises only
     by editing one number in the table, which is exactly the friction that
     belongs on "this review now costs 40 questions instead of 24".
   * `wf run NAME --scripted < /dev/null` → **exit 0.** Every branch a scripted
     default takes is reachable, every text question has a canned reply, and the
     `/dev/null` is what makes "asks nobody" a fact rather than a hope.
4. **`size`, `askNodes` and both bills are deliberately not pinned.** They are
   exactly the fields a reworded rubric or an added lens moves, and pinning them
   would buy nothing `paths` and the ceiling do not already catch. This is the
   whole difference from `ci/examples.sh`, which pins all of them by equality
   because those seven numbers are evidence about the language: **the examples
   gate holds numbers still; this gate holds a budget.**
5. **Every row is priced with no inputs.** `plan` and `cost` supply `""` for an
   input nobody gave, so a roster-shaping input must read `""` as *the default
   roster*, never as *no members* — `panel []` is an `error` on a CAF. This is
   why `Row` needs no `rowSample` field, and it is a house rule with a gate
   behind it rather than a convention.
6. **`wf list` is non-empty and every row's one line is non-empty.** `wf list` is
   what the operator browses, and a blank line is a row nobody can choose.
7. **The `Agentic.Cli` contract check**, replacing the old script's
   `agentic-run` cross-check, which is no longer reachable from here: the gate
   asserts that `wf plan --no-such-workflow` refuses **in this registry's own
   noun** ("no workflow named …"), which is the outside evidence that `regNoun`
   and `regBinary` are still doing their job and that this binary is not
   accidentally serving somebody else's table.

The script must **resolve the binary once** (`cabal list-bin exe:wf`) and invoke
it directly from the repository root rather than through `cabal run`, because
`cabal run` may move the working directory that every `running` party inherits —
the same reason `wf` must be a real binary on `PATH` (§2.4).

`nix flake check` and `nix build .#default` are the second gate and belong in
whatever CI this repository eventually gets. They are what catches the divergence
§3.5 describes: green under `cabal.project` and red under the flake means
agent-cat has unpushed changes.

---

## 10. The ledger: what was taken, and what was rejected

### Taken

| from | what | why |
|---|---|---|
| **A** | The whole shared foundation: eleven modules, `Rubrics.*` as the corpus's prose in one binding each, `Panels`' `Lens`/`Roster`, `Evidence` as the argv library, `Gates`' check-fix-recheck, `Escalation`'s three endings, `Report`'s output contract | It is the design that was built and that went green, and its thesis is falsifiable: a thin flagship over a thick library, with a stated line count and a stated week the claim would fail |
| **A** | Registry-as-value + one shared `Agentic.Cli`; two registries, two gates | Unanimous across all three, and the strongest argument in any of them: `ci/examples.sh` fails on any field that moves, which is right for seven fixtures and wrong for a toolbox edited on a Tuesday |
| **A** | The binary name `wf`, the module namespace `Workflows.`, the root-level tree | Brevity for a daily verb; and the root-level tree becomes free in the new repository |
| **A** | The three-tier "decide as early as possible" rule | Tier 1 — deciding in Haskell over an input, before the `Program` exists — is the one thing nothing in the corpus can reach, and it costs zero questions *and* zero paths |
| **A** | Flagship 5 = `stack`, over B's `forge` | It is the only one that exercises a handle bound before a destruction and read after it, and it is the module the builders were stopped in |
| **A** | §7's self-falsification discipline, carried into §10's risks | A design that names how it would be discovered wrong is worth more than one that argues it is right |
| **C** | The gate design: `level` and `paths` by equality, `costMax` as a ratcheting ceiling, `size`/`askNodes`/bills unpinned | The only proposal that argued *which* folds a churning toolbox can honestly hold still |
| **C** | **WR-1** — a roster-shaping input must be total on `""` | A load-bearing finding, not a preference: `plan`/`cost` bind `""` for an unsupplied input and `panel []` is an `error` on a CAF. It is also the reason A's `rowSample` field was rightly dropped |
| **C** | **WR-2** and its corollary — an input costs zero paths, a decider one path, an asked flag one of each; and a fan-out derived from an *input* is dynamic *and* priced | This is the sharpest technical content in any of the three, and it is what makes `deep-review`'s extension→agent table free |
| **C** | **WR-3** — what a person chooses is an input; what the world knows is a receipt | It is the rule that keeps the flag list small and keeps a receipt from being something the operator can get wrong |
| **C** | The capability test — "if you cannot name the capability, you do not have a workflow, you have a prompt that compiles" | It is what makes eight KEEP-AS-MD honest rather than lazy, and it settled `add-uint-support` against the other two proposals |
| **C** | The KEEP ruling on `add-uint-support` / `at-dispatch-v2`, and the reservation on `swiftui`'s references | The strongest single argument in the honesty column: a skill the harness loads *while editing* is not a run to price |
| **B** | `wf` as a real binary on `PATH`, never a `cabal run` alias | The cwd every `running` party inherits is the whole ballgame; this is the one packaging requirement the design has, and it now shapes the gate too |
| **B** | The three run defaults and `--at-most N` | All four are right — and all four are requests on agent-cat's `Registry`, recorded in §2.5 rather than forked into a second CLI |
| **B** | The invocation story and the three-transports framing (`--scripted` the rehearsal, `--engine acp` the unattended run, `--session` the watched run, which is where a `person` belongs) | The clearest operator-facing writing in the three, and it goes into the README verbatim in spirit |
| **B** | `gravity`, `journal`, `capture` as KEEP-AS-MD | Two-to-one over A on each, and each reason survives inspection |
| **coordinator** | `confer` as a required workflow, single-backend today, roster unchanged when routing lands | §8.1 |

### Rejected, with why

| from | what | why |
|---|---|---|
| **B**, **C** | The tree under `haskell/` | Moot in a repository of its own, where the package root *is* the repository root — which also retires the foundation's symlink |
| **C** | `workflows` as the binary name | Nine characters and a noun, typed several times a day. `wf` is a verb-shaped handle and it is already spelled everywhere in the built tree |
| **C** | No `--scripted` in the gate; one stub-adapter smoke row instead | Wrong, and the foundation was right to overrule it. A scripted run reaches nothing, spends nothing, needs no adapter and no network, and exercises every branch's plumbing — it is what makes the gate hermetic and free. The claim that "a canned table proves nothing about a program whose gates are `running` parties" is true of the *gates* and false of the *plumbing*, which is what this gate tests |
| **B**, **C** | Rungs collapsed into a `mode=`/`tier=` input, one row per family | Their arithmetic is right and their conclusion is not: the four prices of the review ladder side by side in `wf list` are the entire reason the ladder became a program, and a rung behind a flag is a rung no gate pins |
| **B** | `wf prices --write` / `--check` — regenerate a committed `PRICES.md` and diff | Genuinely better ergonomics than a hand-edited table, and rejected for one reason: it makes the *program* the author of its own pin, so a change that moved a price and a change that moved the pin are one commit. The friction of editing a ceiling by hand is the feature. Reconsider if the hand-edited table is ever re-pinned by reflex — that is the signal that B was right |
| **A** | `Row`'s `rowSample` and `rowCeiling` fields | Already dropped by the foundation, and C's WR-1 is the reason that was sound: a row that must be priceable with no inputs needs no sample, and the ceiling belongs to the gate that promises it, not to the program |
| **A** | A `mustPass` combinator | It does not typecheck: `unless` takes a body and `stop` is a `Term`. The real shape is `when ok $ W.do …`, whose failing arm the compiler supplies. `Workflows.Gates`' haddock says so rather than shipping a broken helper |
| **A** | `gravity` folded into `teams`; `fix-integration` as keep-as-md (B) | Two-to-one each way, and in `gravity`'s case the fold found a better home: its stance is what confer's `against` seat argues, and its challenge sentences are the rubric all three seats and `second-opinion` stand under |
| **B** | `forge` as the fifth flagship | A near-literal transplant of a workflow already written as prose: lowest risk, and therefore the least it teaches. It lands in wave 2, where pricing six phases across three models is the demo |
| **A**, **B** | `add-uint-support` / `at-dispatch-v2` as programs | See above; C's argument is better |
| — | Mirroring PAL's seven guided investigations as workflows | `pal-note.md` forbids it and gives the reason: they are forms the calling agent fills in, the corpus's own commands already cover those shapes, and a workflow whose *shape* is a form is a prompt that compiles |

### Three ways this design could be wrong, and when you would know

1. **`Lens` may be too general.** It is asked to serve eleven reviewers, ten
   sins, three confer stances, eleven team roles and twenty-one build
   deliverables. If `productize`'s rows need fields no reviewer wants, the answer
   is two types, not one with `Maybe`s. **You would know in wave 2**, when
   `teams` and `notes` land, and in wave 4 when `productize` does.
2. **Rungs may hide differences that matter.** Folding six review commands into
   one builder is the boldest claim here. If `heavy-review`'s attestation
   contract or `review-github-pr`'s head-OID gate cannot be a rung's extra
   statement without contorting the others, they should be separate programs
   sharing the roster and the `Fn`s — which costs nothing, because the reuse
   lives in the library. **You would know in wave 1**, from the audit in §5 step 7.
3. **Tier-1 deciding may be too clever.** Choosing the roster in Haskell from
   `--input-arg paths=` is free and visible in `plan`, but the program text then
   differs per invocation and the owner must supply the paths. If he will not,
   the honest fallback is tier 2 — `anyPathMatches` deciders that cost zero
   questions and multiply paths — and `costSummary` will say exactly what that
   costs. **You would know the first week he uses it.**



