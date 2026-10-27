# Arabic and Persian sacred-text translation

`translate-en` implements the thorough procedure developed in translate-tool. It
translates Arabic and Persian Bahá’í texts into English in the register associated
with Shoghi Effendi. Its output is a machine-assisted translation, not an
authorized translation or an assurance of spiritual or literary quality.

The authoritative inputs and their hashes are recorded in
`assets/translate-en/provenance.json`. The packaged register guidance, calibration
examples, six reviewer mandates, and 43-entry glossary come from that source.
The earlier reverse-direction sketch is not the specification for this workflow.
`translate` and `translate-es` retain their existing behavior.

## Inputs and invocation

Supply exactly one of the two workflow inputs:

- `file` is a UTF-8 `.txt` or `.md` file, or a `.docx` file. An absolute path avoids
  ambiguity when the selected execution target uses a different working directory.
- `text` is the literal Arabic/Persian passage, including paragraph breaks.

In Pi, the command tail supplies `file` and the multiline body supplies `text`:

```text
/wf wf:translate-en /absolute/path/source.docx
```

```text
/wf wf:translate-en

يا أهل العالم اسلكوا سبيل العدل.

ای دوست، در راه عدل گام بردار.
```

The normal input editor can request the other input. Leave it empty. The command
tail is not a shell command, so a path containing spaces needs no shell quotation.
The existing project trust and interactive approval requirements remain in force.

For isolated native execution, use the paired agent-cat Pi extension and map this
workflow to a persona containing the three profiles described below. Merge the
following `wf` entry into the existing trusted runner configuration rather than
discarding other runners:

```json
{"id":"wf","executable":"/absolute/path/to/wf","workflowPersonas":{"translate-en":"sacred-text"}}
```

`AGENT_CAT_RUNNERS` contains the JSON array of runner entries. Configure it or
the singular `AGENT_CAT_RUNNER`, not both. The `sacred-text` name identifies the
configured persona; it does not create profiles or select a model by itself.
Workflows without a matching `workflowPersonas` entry retain the current Agent
Deck launch behavior.

`/wf` holds the native preparation while displaying its exact policy, invocation,
and captured input hashes for approval. Declining sends no model prompt. Invalid
or unavailable routes fail rather than falling back to the source conversation.

A direct runner invocation can read a text file into the literal input:

```sh
wf run translate-en --engine acp --adapter claude --scratch "$PWD" \
  --require-pinned --input-arg file= --input-file text=source.txt
```

For DOCX, pass a path rather than asking the generic runner to decode ZIP bytes
as UTF-8:

```sh
wf run translate-en --engine acp --adapter claude --scratch "$PWD" \
  --require-pinned --input-arg file="$PWD/source.docx" --input-arg text=
```

`--scratch "$PWD"` keeps ACP artifacts in the current project. Without an explicit
scratch directory, the runner can place them in its per-run temporary directory.
The final result identifies an absolute artifact path in either case.

## Procedure and routing

Every normal source section receives the following native operations:

1. Prepare language identifications and a source-unit-specific terminology brief.
2. Produce a calibrated initial draft, preserving source-unit order.
3. Back-translate independently, then run all six specialist reviews as a named
   text panel: diction/grammar, beauty/eloquence, clarity/accessibility,
   conventions/terminology, fidelity, and oral/spiritual quality.
4. Synthesize every finding according to the fixed priority hierarchy.
5. Repeat the independent back-translation and all six reviews, including checks
   of earlier findings and their disposition.
6. Perform final synthesis and one constrained mechanical verification pass.
7. Assemble validated sections in source order and publish the final artifacts.

Meaning takes priority over terminology, then grammar, oral/spiritual quality,
register, clarity, and aesthetic preference. A satisfactory phrase is not rewritten
merely because another wording is possible. Synthesis may change only units with
accepted findings in that review round. With no accepted findings, the candidate
remains unchanged. Reviewer scores remain judgments, not mechanical thresholds.
English candidates retaining Arabic/Persian script are refused before reverse
translation or delivery, while back-translations retain their required source script.

The workflow declares three dedicated routing profiles:

| Profile | Responsibility | Calibration guidance |
| --- | --- | --- |
| `translate-en` | Preparation, drafting, reviewers, synthesis | The source experiments used `claude-opus-4-6`, with drafting temperature 0.3. |
| `translate-en-back` | Both source-hidden back-translations | Use an isolated context on the selected model. |
| `translate-en-verify` | Constrained mechanical verification | The source verifier used temperature 0.0. |

Configure these profiles through the existing agent-cat routing mechanism rather
than changing the shared `opus` profile used by unrelated workflows. Keep their
chains to the intended model unless an alternative is explicitly authorized.
The workflow authors no fallback ladder. The runner records actual routing and
recovery behavior.

A symbolic profile name does not itself set a provider, model, temperature, or
reasoning effort. The selected adapter must support the requested controls.
Unsupported settings must be reported or refused, not represented by a prose
instruction claiming deterministic sampling. Record the actual selected model
and supported settings when assessing translation quality.

Back-translation requests contain only the English candidate and language
metadata. A shared source conversation is refused unless the existing route
separation check identifies a dedicated back-translator. Prefer fresh sessions
per question. If using named Agent Deck sessions, use one selector vocabulary
throughout, because the existing route check cannot establish that a session's
name and its numeric identifier denote the same session. A dedicated session
must not already contain the source from earlier work.

## Validation, exceptions, and limits

The workflow validates input before model work where possible. It rejects empty,
missing, unsupported, unreadable, invalid-UTF-8, and nonregular file inputs. DOCX
body paragraphs and table-cell paragraphs retain document order. Content requiring
additional extraction, including drawings, notes, tracked changes, numbering,
fields, headers, and footers, is refused rather than silently omitted. Export such
a document to verified plain text first. PDF and OCR are outside this workflow.

Sections target roughly 2,000 source words and retain original paragraph identity.
A long paragraph can be divided at sentence boundaries and reassembled as one
paragraph. A span longer than 4,000 words without a natural boundary, a document
requiring more than 64 sections, or a source exceeding 16 MiB is refused before
translation. No section is silently discarded.

Only a single, conservatively short source unit that preparation explicitly
classifies as less than one sentence can bypass specialist review. A complete
sentence does not qualify merely because it is short or lacks punctuation. The
result and artifact manifest disclose the phrase exception. The normal path uses
19 model consultations per section. The phrase path uses three. The runner's
larger request count includes deterministic tools as well as model consultations.
Its published ceiling covers all 64 sections, not the likely cost of a short
passage.

Glossary checks normalize source vocalization and common Arabic/Persian letter
variants without modifying the retained source. Conditional meanings are decided
per source unit. For example, a reference to the Báb in one paragraph does not
force that rendering for an ordinary door in another. Morphological and semantic
cases beyond deterministic matching remain obligations of the conventions and
fidelity reviewers.

Mechanical verification cannot freely replace the candidate. It may select only
explicitly enumerated local pronoun edits, including supported adjacent auxiliary
forms. Already valid text remains unchanged. A remaining mechanical error or
unresolved critical finding causes verification to fail. Other grammar and meaning
concerns remain obligations of specialist review and synthesis. This bound
protects against unreviewed paraphrase.

Missing or malformed reviewer responses are failures, not approval. A valid
response explicitly reporting no issues is approval. Rejected critical findings,
unresolved mechanical errors, exhausted processing, model failures, and
cancellation prevent verified final publication. Use the runner's normal inspect,
retry, resume, or fork facilities to examine and address the failed occurrence.
Retrying a deterministic validator with the same invalid answer does not repair
the upstream model answer.

## Artifacts

The typed Pi result contains the final English translation followed by separate
quality notes and an absolute artifact path. Default delivery excludes individual
reviews, intermediate drafts, and back-translations, which remain inspectable in
the native run artifacts.

The saved bundle contains:

- `translation.txt`, containing only the translation.
- `quality-notes.txt`, including the review or phrase-exception statement.
- `manifest.json`, containing source and translation hashes, paragraph/section
  counts, ordered source-unit identifiers, and guidance provenance.

Files use mode 0600 inside a mode-0700 backing directory. The public directory
link under `.translate-en/` appears atomically after the complete bundle has been
written and synchronized. Existing destinations are never overwritten. Keep the
hidden `.data-*` backing directory, or copy the individual files when exporting
the translation. An interrupted publication can leave unpublished hidden storage,
which is not a final result. Re-publication to an existing destination is refused.

## Build, package, and verification

This workflow requires the agent-cat authoring surface that exports `amendWith`.
It exposes the existing typed right-hand-side amendment grammar and does not add
new workflow semantics. Build against the committed remote dependency pins:

```sh
nix build .#default --no-write-lock-file
./result/bin/wf help translate-en
```

The Nix package installs the deterministic helper and its assets. Its `wf` wrapper
adds the packaged helpers to PATH without changing the working directory. A bare
Cabal executable needs `tools/` on PATH when run from a source checkout.

For paired development only, an explicit local override selects the sibling
agent-cat checkout without changing the committed dependency relationship:

```sh
nix build .#default --override-input agent-cat "git+file:$PWD/../agent-cat" --no-write-lock-file
```

The local Git override excludes ignored build products and caches. Deployment
uses the reviewed remote revisions, not this development override.

Installation uses the existing package route and committed dependency pins:

```sh
nix profile install .#default --no-write-lock-file
```

Pi uses the absolute runner paths in its trusted startup configuration. If that
configuration names an immutable Nix-store path, installing another package alone
does not change the running Pi process. Update the configured `wf` runner through
the user's supported deployment mechanism and restart or reload the environment
as that mechanism requires. Do not replace or modify an existing Nix-store path.
Confirm discovery through the normal Pi workflow catalogue before a live run.

The owning offline gate compares the packaged assets with the authoritative
translate-tool checkout, runs helper and native interpreter tests, checks catalogue
facts, and verifies helper discovery with a local ACP stub:

```sh
TRANSLATE_TOOL_SOURCE=/absolute/path/translate-tool ./ci/translate-en.sh
TRANSLATE_TOOL_SOURCE=/absolute/path/translate-tool ./ci/translate-en.sh "$PWD/result/bin/wf"
```

These commands run inside the supported Nix development shell. They do not contact
a model provider. Regenerate guidance deliberately with
`python3 tools/sync-translate-en.py /absolute/path/translate-tool`, then review the
asset diff and repeat the gate. The original source files remain authoritative.

Offline fixtures establish procedure, validation, and artifact integrity. They do
not establish fidelity, register, or literary quality. Approved live file and
pasted-text runs, with inspected translations and actual routing settings, remain
necessary acceptance evidence.
