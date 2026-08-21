-- |
-- Module      : Workflows.Expense
-- Description : Receipts to a spreadsheet, with the owner in binding position.
--
-- == The map: old Markdown -> new program
--
-- +-----------------------------------------+--------------------------------------------------------------+
-- | @~\/src\/nix\/config\/ai@               | here                                                         |
-- +=========================================+==============================================================+
-- | @commands\/expense-report.md@ Step 1    | 'receiptFiles' — the Glob tool becomes a @find@ receipt whose |
-- | (\"parse @$ARGUMENTS@\", \"use the Glob | seven extensions are program-authored argv, and the trip name |
-- | tool to expand directories\")           | is an input rather than a quoted string a model must spot     |
-- +-----------------------------------------+--------------------------------------------------------------+
-- | its Step 2 (the seven-field extraction  | 'extractBrief', 'categoryRules', 'amountRules' — verbatim in  |
-- | table, the category rules, the amount   | substance, plus one addition: the @REVIEW@ flag gets a LINE    |
-- | rules, the @REVIEW@ flag)               | of its own, which is what makes it readable                   |
-- +-----------------------------------------+--------------------------------------------------------------+
-- | its Step 3 (\"present confirmation      | the owner in __binding position__ inside                      |
-- | table\", \"Accept \/ Edit \/ Add\")     | @'Agentic.Workflow.revisingOn'@: accept settles, an edit       |
-- |                                         | amends with the correction spliced, a refusal to judge stops   |
-- +-----------------------------------------+--------------------------------------------------------------+
-- | its Step 4 (the JSON, and the           | 'expenseBuildFn' — one act that writes the payload and one     |
-- | @nix-shell@ line)                       | receipt that runs the filler, called from __exactly one__      |
-- |                                         | reachable place per arm                                       |
-- +-----------------------------------------+--------------------------------------------------------------+
-- | its Step 5 and @## Important Notes@     | 'expenseReportBrief' — the five report items, the receipt-URL  |
-- |                                         | reminder, the eight-row-per-category limit, and the           |
-- |                                         | folio-splitting rule                                          |
-- +-----------------------------------------+--------------------------------------------------------------+
--
-- The Markdown was read as __data__. Nothing in @~\/src\/nix\/config\/ai@ is
-- modified by this module, and no party in it points at that tree.
--
-- == The leveling-up, item by item
--
--   1. __The owner is a binder, not a paragraph.__ @doc\/design.md@ §7.2 row 14:
--      \"person in /binding/ position driving @revisingOn@ — accept settles, edit
--      amends with the correction spliced, abandon stops\". Step 3 of the corpus
--      is a table, a question, and three offered replies with no mechanism behind
--      any of them: the run presents, the human says something, and whatever
--      happens next is whatever the reading agent decided the human meant. Here
--      the human's answer is the loop's __verdict__, and the language reads its
--      three tags three ways. @Accept@ is an approval and the spreadsheet is
--      built; @Edit row 3@ is an objection and is spliced into the correction
--      turn; and a person who does not answer at all abandons the loop, which is
--      the one outcome an unattended run must not treat as consent.
--
--   2. __The decorative flag becomes the gate.__ The corpus's @Flag@ column is
--      set to @REVIEW@ \"if any field is uncertain\" and then nothing reads it —
--      it rides into the spreadsheet as a string. Here 'expenseUncertain' reads
--      it for __zero questions__, and it decides which of two shapes the
--      confirmation takes: an uncertain table gets the bounded revision above, a
--      confident one gets a single yes\/no. That asymmetry is the point. A table
--      with nothing uncertain in it does not need two repair trips budgeted
--      against it, and @wf cost expense@ prices both.
--
--   3. __The @&&@ and the shell are gone.__ Step 4 ends in
--      @nix-shell -p python3Packages.openpyxl --run \"python3 …\"@, whose @--run@
--      argument is a shell command assembled by string concatenation. This tree's
--      house rule is @proc@ and never @sh -c@, with no interpolation at an argv,
--      so 'expenseFill' is @nix shell … --command python3 SCRIPT PAYLOAD@: four
--      program-authored argv elements, no shell, and both paths visible in
--      @wf plan --raw@. See \"Two narrowings\" below.
--
--   4. __The filler's exit code is the report's evidence.__ Step 5 says \"after
--      the script runs, report\" and has no way to know whether it ran. Here the
--      filler is a @text@ ask, so a nonzero exit abandons the run loudly instead
--      of producing a report about a spreadsheet that does not exist — and what
--      the report quotes is the script's own output rather than a recollection of
--      it.
--
-- == Two narrowings, recorded rather than absorbed
--
-- __@find@ does not sort, and the corpus asks for sorted files.__ Step 1 says
-- \"sort files alphabetically for deterministic ordering\". A sort is a second
-- process and a pipe, which is a shell; "Agentic.Shell" runs one argv with
-- @proc@. So the receipt's order is the directory's, and the ordering the corpus
-- actually wanted — a table a human can check row against receipt — is asked for
-- in 'extractBrief' by date and then by vendor, which is a better order for the
-- one reader who matters. What is lost is byte-identical output across two runs
-- over the same directory, and the report is not told to claim it.
--
-- __The receipts are read by the answering agent, not by this program.__ Step 2
-- says \"use the __Read__ tool to view the document\", and a receipt here is
-- @'Agentic.Workflow.Words'@ — text. An agent-cat question carries text, so a PDF
-- or a photograph cannot be handed to a party by this language. What the program
-- does instead is exactly what @doc\/design.md@ §7.2 row 64 rules for
-- @transcribe@: the receipt __names and proves the files__, and the extracting
-- turn is an agent with its own file-reading tools. So an extraction that
-- invented a receipt file is caught — the file list is bytes @find@ wrote — while
-- an extraction that misread a real one is not. The report is told which of those
-- two this run can rule out.
{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QualifiedDo #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE RebindableSyntax #-}
{-# LANGUAGE TypeApplications #-}

module Workflows.Expense
  ( -- * The program
    expenseProgram,
    expenseDoc,
    expenseScript,

    -- * The free test this module owns
    expenseUncertain,

    -- * The tier-1 readings of an invocation
    receiptsDir,
    fillScript,
    payloadPath,

    -- * The rubrics, transplanted
    extractBrief,
    categoryRules,
    amountRules,
    confirmBrief,

    -- * The functions
    expenseBuildFn,
    expenseReportFn,
    expenseTable,
  )
where

import qualified Agentic.Workflow.Do as W
import Data.String (fromString)
import Data.Text (Text)
import qualified Data.Text as T
import Workflows.Prelude
import Prelude

-- ---------------------------------------------------------------------------
-- The argv
-- ---------------------------------------------------------------------------

-- $argv
--
-- These belong in "Workflows.Evidence" — that module is where the read-only rule
-- could be broken, so it is reviewable as a unit. They are grouped here, in one
-- labelled block, for @'Workflows.Git.Stack'@'s reason: the move is one cut and
-- one paste, and the exception is visible rather than scattered.
--
-- Neither of them points at @~\/src\/nix\/config\/ai@, and neither is composed
-- with a shell.

-- | @find DIR -maxdepth 1 -type f ( -iname \'*.pdf\' -o … )@ — the receipt files
-- in a directory, one path per line.
--
-- /Source:/ @commands\/expense-report.md@ Step 1, whose seven extensions
-- (@.pdf@, @.png@, @.jpg@, @.jpeg@, @.heic@, @.tiff@, @.webp@) and whose
-- \"non-recursive\" are carried exactly: seven @-iname@ tests and @-maxdepth 1@.
--
-- __The parentheses are argv elements and not shell.__ @find@ parses its own
-- expression, so @(@ and @)@ are two ordinary arguments here; a shell would have
-- needed them escaped, and there is no shell. That is the whole reason the
-- corpus's unquoted glob is not an injection surface in this tree.
--
-- __@-iname@ where the corpus writes lowercase extensions.__ A phone writes
-- @IMG_0042.JPG@, and a receipt named in capitals is a receipt. The deviation is
-- one letter and it is here rather than in a sentence asking a model to be
-- careful about case.
receiptFiles :: Text -> Party 'IsTool
receiptFiles dir =
  tool "expense-receipts"
    `running` ( "find",
                [dir, "-maxdepth", "1", "-type", "f", "("]
                  <> concat
                    [ ["-iname", "*." <> ext, "-o"]
                    | ext <- ["pdf", "png", "jpg", "jpeg", "heic", "tiff"]
                    ]
                  <> ["-iname", "*.webp", ")"]
              )

-- | @nix shell nixpkgs#python3Packages.openpyxl --command python3 SCRIPT PAYLOAD@
-- — the template filler, run with the one library it needs.
--
-- /Source:/ @commands\/expense-report.md@'s @## Template and Tools@ and Step 4,
-- which spell it
--
-- > nix-shell -p python3Packages.openpyxl --run "python3 ~/Documents/expense-report-fill.py /tmp/expenses.json"
--
-- __The @--run@ form is deliberately not carried.__ Its argument is a shell
-- command assembled by concatenating two paths into a string, which is precisely
-- what house rule 3 forbids — @proc@, never @sh -c@, and no interpolation at an
-- argv. @nix shell … --command@ takes an __argv__ instead of a shell string, so
-- the same environment is provisioned and the two paths stay two arguments. The
-- deviation is the flag; the effect is the corpus's.
--
-- Asked at @text@, which gives the failure this row wants: the script exits @0@
-- with its own summary and nonzero when the template, the payload or openpyxl is
-- missing, and a @text@ ask on a nonzero exit abandons the run — so a report
-- about a spreadsheet that was never written is not reachable.
expenseFill :: Text -> Text -> Party 'IsTool
expenseFill script payload =
  tool "expense-fill"
    `running` ( "nix",
                [ "shell",
                  "nixpkgs#python3Packages.openpyxl",
                  "--command",
                  "python3",
                  script,
                  payload
                ]
              )

-- ---------------------------------------------------------------------------
-- The one party that is this program's own
-- ---------------------------------------------------------------------------

-- | The party that writes @\/tmp\/expenses.json@.
--
-- A @tool@ with __no__ argv, for @'Workflows.Git.Commit'@'s reason: writing a
-- file is exactly the work an agent with write authority does, and an
-- @'Agentic.Workflow.act'@ at @'Agentic.Raw.CodeAck'@ is the only kind of answer
-- the ACP transport grants that authority to. There is no @cat >@ here, because
-- a redirection is a shell.
payloadWriter :: Party 'IsTool
payloadWriter = tool "expense-payload"

-- ---------------------------------------------------------------------------
-- The free test this module owns
-- ---------------------------------------------------------------------------

-- | The extraction is not sure about something.
--
-- /Source:/ @commands\/expense-report.md@ Step 2's @Flag@ row — \"set to
-- @\"REVIEW\"@ if any field is uncertain\" — and its amount rule \"if multiple
-- amounts are ambiguous, flag with @REVIEW@ and note which candidates exist\".
--
-- __The sentinel is authored here, and that is the deviation worth naming.__ In
-- the corpus @REVIEW@ is a cell in a Markdown table, and a table cell is not
-- decidable: @'Agentic.Workflow.AnyLineStartsWith'@ tests a line's prefix and
-- every row of that table begins @|@. So 'extractBrief' asks for the same fact
-- __on its own line__ — @REVIEW: \<n\> \<what is uncertain\>@, or
-- @NO REVIEW NEEDED@ — and this reads it for nothing. Same fact, one fewer
-- question, and the flag stops being decorative.
--
-- It belongs to this module rather than to "Workflows.Deciders" for
-- @'Workflows.Git.Stack.commitLost'@'s reason: one caller, one owner.
expenseUncertain :: (Decider, [Text])
expenseUncertain = (AnyLineStartsWith, ["REVIEW:"])

-- ---------------------------------------------------------------------------
-- The tier-1 readings of an invocation
-- ---------------------------------------------------------------------------

-- | The directory the receipts are found in, or a name no directory has.
--
-- __Tier 1__: ordinary Haskell over the invocation, zero questions and zero
-- paths. An absent path becomes a name no directory has, which is
-- @'Workflows.Checklist'@'s rule — @wf plan expense --raw@ prints
-- @find \<no receipt directory given\> …@, so an operator who forgot the flag
-- learns it from the plan, and a @--scripted@ run never reaches a command at all.
receiptsDir :: Text -> Text
receiptsDir d
  | T.null (T.strip d) = "<no receipt directory given>"
  | otherwise = T.strip d

-- | The filler script, or a name no file has.
--
-- __Tier 1__, and an input rather than the corpus's literal
-- @~\/Documents\/expense-report-fill.py@ for one reason: @proc@ does not expand
-- @~@, so that string is not a path any process can open. The operator's own
-- absolute path is the honest spelling, the plan prints whichever was given, and
-- an absent one is a name @python3@ will refuse.
fillScript :: Text -> Text
fillScript s
  | T.null (T.strip s) = "<no fill script given>"
  | otherwise = T.strip s

-- | @\/tmp\/expenses.json@ — the payload path, program-authored.
--
-- /Source:/ @commands\/expense-report.md@ Step 4, verbatim, and it is __not__ an
-- input: the file is written by one turn of this run and read by the next, so it
-- is an internal handoff rather than an operator's choice. Program-authored means
-- the two argv that name it cannot disagree, which is exactly what an operator's
-- flag could not guarantee.
payloadPath :: Text
payloadPath = "/tmp/expenses.json"

-- ---------------------------------------------------------------------------
-- The rubrics, transplanted
-- ---------------------------------------------------------------------------

-- | What the inventory receipt is introduced as.
inventoryBrief :: Text
inventoryBrief =
  [wft|
  The receipt files in the directory this run was given: one path per line,
  non-recursive, and only the seven document and image types a receipt comes
  in. These are bytes `find` wrote, so a file that is not in this list is a
  file this run has no evidence of.|]

-- | @commands\/expense-report.md@ Step 2, whole.
--
-- /Source:/ its seven-field extraction table, verbatim in substance. Two things
-- are added and both are named in the module header: the @REVIEW@ flag gets a
-- line of its own so that 'expenseUncertain' can read it, and the table is asked
-- for in date-then-vendor order because 'receiptFiles' cannot sort. One thing is
-- dropped, declared: the category rules' rental-agency parenthetical
-- (@Hertz, Enterprise, Avis, etc.@) — the rule stands without the examples.
extractBrief :: Text
extractBrief =
  [wft|
  You are an expense report assistant. Read each receipt file named below --
  open the actual document; do not guess from its filename -- and extract one
  row per expense.

  Seven fields per row:

  - Date: the transaction date, not the print or download date. Format
    MM/DD/YYYY.
  - Category: exactly one of Flights, Hotel, Dining, Rental Cars,
    Lyft / Uber. Infer it from the vendor and the context.
  - Vendor: the business name, as it appears ("United Airlines", "Marriott
    Downtown", "Uber").
  - Amount: the total charged, after tax and tip.
  - Payment Method: if visible -- "Corporate Card", "Personal Card", the card's
    last four digits. Otherwise leave it blank.
  - Notes: confirmation numbers, an itemized breakdown, special circumstances.
  - Source File: the path from the list below that this row came from,
    verbatim.

  Where one receipt covers several expenses -- a hotel folio with a room charge
  and parking -- write one row per line item, all naming the same source file.

  Answer with the table in this order: by date, and within a date by vendor.

  Present it as a Markdown table with those columns and a leading row number,
  then a Trip metadata block naming the trip, the destination inferred from the
  receipt locations, the date range from earliest to latest, and a blank
  traveler line for the operator to fill.

  Then, and this part is read by the program rather than by a person, one
  trailer line per uncertain row:

    REVIEW: <row number> <which field is uncertain, and what the candidates are>

  and if nothing at all is uncertain, exactly one line reading

    NO REVIEW NEEDED

  A row is uncertain when any of its seven fields is a guess: two plausible
  totals, an unreadable date, a vendor you inferred from a logo, a category
  that could be two of the five. Say so. An uncertain row silently presented as
  certain is the one failure here that reaches an accounting department.|]

-- | @commands\/expense-report.md@'s category inference rules, verbatim.
categoryRules :: Text
categoryRules =
  [wft|
  Category inference:

  - airlines, boarding passes, baggage fees, seat upgrades -> Flights
  - hotels, motels, Airbnb, lodging, resort fees -> Hotel
  - restaurants, cafes, room service, food delivery, grocery -> Dining
  - car rental companies, fuel, tolls -> Rental Cars
  - Uber, Lyft, any rideshare -> Lyft / Uber|]

-- | @commands\/expense-report.md@'s amount extraction rules, verbatim.
amountRules :: Text
amountRules =
  [wft|
  Amounts:

  - always prefer the "Total" or "Amount Charged" line over a subtotal;
  - where there is a tip, use the total including it;
  - for a multi-currency receipt, note the original currency in Notes and
    convert to USD where you can say what rate you used;
  - where several amounts are genuinely ambiguous, take the most likely one,
    say which candidates exist in Notes, and flag the row.|]

-- | What the owner is asked, in binding position, when something is uncertain.
--
-- /Source:/ @commands\/expense-report.md@ Step 3's question and its three offered
-- replies — Accept, Edit, Add — mapped onto the three verdict tags
-- @'Agentic.Workflow.revisingOn'@ reads. The mapping is the level-up and is
-- spelled out to the person, because a human answering a machine should be told
-- what each of his answers does.
--
-- __The @NOTHING AT ALL@ clause is load-bearing__ and is
-- 'Workflows.Escalation.endingSpec'\''s: a verdict decodes as declined when the
-- answer is __empty__, so an explanation of why one cannot decide is an
-- objection and buys a trip that cannot help.
confirmBrief :: Text
confirmBrief =
  [wft|
  Here is the expense table extracted from your receipts. At least one row is
  flagged: the trailer lines say which, and what was uncertain about each.

  Read the flagged rows against the receipts and answer with exactly one of
  these, on its own last line:

  - APPROVE -- the table is right as it stands. The spreadsheet is built from
    it and nothing else happens. Write that word alone: anything else on the
    line is read as a correction, and a correction buys a round.
  - OBJECTION: <one line> -- the corrections, on one line, in your own words:
    "row 3 amount is 72.50", "row 2 is Dining not Lyft / Uber", "trip name is
    Berlin Conference 2026", "drop row 5, it is a duplicate of row 4". That
    line is the ONLY thing the correcting turn is told, so put everything you
    want changed in it.

  If, and only if, you cannot judge this table at all -- it is not your trip,
  the rows do not correspond to receipts you recognise, something outside this
  run has to be fixed first -- reply with NOTHING AT ALL: an empty answer. An
  empty answer stops the run and builds no spreadsheet. An explanation of why
  you are stuck is an objection and buys a correction round that cannot help.|]

-- | What the owner is asked when the extraction flagged nothing.
--
-- /Source:/ the same Step 3, on the path where it costs one question. The corpus
-- asks the same question of a clean table and an uncertain one; here the
-- difference is the shape of the answer it will accept, and 'expenseUncertain'
-- decides which.
cleanConfirmBrief :: Text
cleanConfirmBrief =
  [wft|
  Here is the expense table extracted from your receipts. The extraction
  flagged nothing as uncertain -- every field on every row came off a receipt
  without a judgment call.

  Yes builds the spreadsheet from this table. No stops the run, changes
  nothing, and reports the table as it stands so you can say what is wrong.

  Build it?|]

-- | What the correcting turn is told.
correctBrief :: Text
correctBrief =
  [wft|
  The operator read the expense table and asked for changes. Produce the
  corrected table and nothing else -- the same shape as before, including the
  trailer lines, and no commentary about what you changed.

  Apply exactly what he asked for and nothing more. He is looking at the
  receipts and you are not: where his correction contradicts what you read, he
  is right and the row takes his value.

  Where his line asks for something you cannot do -- a category outside the
  five, a row number that does not exist -- leave that part alone and say so in
  one line at the top. Then re-derive the trailer lines: a row he corrected is
  no longer uncertain unless something else about it still is.|]

-- | What the payload act is told.
--
-- /Source:/ @commands\/expense-report.md@ Step 4's JSON structure, field for
-- field.
payloadBrief :: Text
payloadBrief =
  [wft|
  Write the confirmed table below to a JSON file, and write nothing else.

  The path is given below and is the one the filler script reads. The shape is
  exactly this:

  {{"trip": {{"name": …, "destination": …, "dates": …, "traveler": "",
  "department": "", "report_number": ""}},
  "expenses": [{{"date": "MM/DD/YYYY", "category": …, "vendor": …,
  "amount": <a number, not a string, no currency symbol>,
  "payment_method": …, "receipt_path": "<absolute path>", "notes": …,
  "flag": ""}}, …]}}

  Three things the shape does not say and the script depends on:

  - `amount` is a JSON number. "$487.30" is a string and will not sum.
  - `receipt_path` is absolute. The script turns it into a file:// hyperlink,
    and a relative path becomes a dead link in somebody else's spreadsheet.
  - `category` is one of the five, spelled exactly as in the table --
    "Lyft / Uber" has spaces around the slash.

  Leave `traveler`, `department` and `report_number` empty: they are the
  operator's to fill.

  When you are done, reply DONE with the number of expense objects you wrote.|]

-- | What the filler receipt is introduced as.
fillBrief :: Text
fillBrief =
  [wft|
  The filler script, run over the payload this run just wrote. Whatever it
  prints is the answer: it copies the template, fills only the data cells, and
  leaves every SUBTOTAL and Grand Total formula intact to recalculate in Excel.|]

-- ---------------------------------------------------------------------------
-- The provenance lines
-- ---------------------------------------------------------------------------

-- | The arm where a flagged table was approved and built.
builtFlaggedNote :: Text
builtFlaggedNote =
  [wft|
  Outcome: BUILT, AFTER REVIEW. The extraction flagged at least one row as
  uncertain, the operator read the flagged rows and approved the table --
  possibly after corrections, which are in the table below -- and the filler
  script ran. Report the flagged rows and what became of each: corrected to
  what, or approved as extracted. A row that was flagged and then approved
  unchanged is still a row somebody should look at in the spreadsheet.|]

-- | The arm where a clean table was confirmed and built.
builtCleanNote :: Text
builtCleanNote =
  [wft|
  Outcome: BUILT. The extraction flagged nothing as uncertain and the operator
  confirmed the table in one answer, so no correction round was spent. Say that
  plainly in the report: nothing here was reviewed field by field, because
  nothing asked to be.|]

-- | The arm where the corrections never settled.
unresolvedNote :: Text
unresolvedNote =
  [wft|
  Outcome: NOT CONFIRMED -- NOTHING WAS BUILT. The operator was still asking for
  changes when this run's correction budget ran out, so the table below is the
  one the last correction produced and his final answer objected to; no round
  was spent answering that last objection. No JSON was written and no
  spreadsheet exists. Report his outstanding objection first, in his own words,
  then the table beneath it, and say what the next run should be given.|]

-- | The arm where the operator declined to judge.
noAnswerNote :: Text
noAnswerNote =
  [wft|
  Outcome: STOPPED -- THE OPERATOR DID NOT JUDGE THE TABLE. The confirmation was
  answered with nothing, which in this run means: do not build this. No JSON was
  written and no spreadsheet exists. This is the arm that exists so that an
  unattended run cannot read silence as consent -- report the table, name the
  receipt directory it came from, and stop.|]

-- | The arm where a clean table was refused.
declinedNote :: Text
declinedNote =
  [wft|
  Outcome: DECLINED -- NOTHING WAS BUILT. The extraction flagged nothing and the
  operator still said no, which means something is wrong that the flags did not
  catch: a receipt that should not be in this report, a missing one, the wrong
  trip. No JSON was written. Report the table and the file list side by side, so
  the discrepancy is visible, and ask what to change.|]

-- ---------------------------------------------------------------------------
-- The functions
-- ---------------------------------------------------------------------------

-- | Write the payload, then run the filler.
--
-- Two statements and an answer, and it is called from __two__ arms — the approved
-- flagged table and the confirmed clean one. A function rather than two copies
-- for "Workflows.Report"'s reason: @rhsAsks@ prices a call at the callee's own
-- body with the arguments ignored and @graft@ splices the callee's nodes rather
-- than adding one, so the two call sites share this body at no charge and cannot
-- drift in what JSON they write.
--
-- __Why it is a function /of/ the two paths.__ Both argv elements come from the
-- invocation — the script is an input, the payload is 'payloadPath' — and an argv
-- is part of the printed program, so it cannot arrive through a parameter handle.
-- A 'Agentic.Workflow.Fn' is an ordinary Haskell value, so the paths are captured
-- here and the table below is a function of them too. That keeps the argv
-- program-authored and the body shared, which is the pair of properties this row
-- needs.
expenseBuildFn :: Text -> Text -> Fn '[ 'CodeText, 'CodeText] 'CodeText
expenseBuildFn script payload =
  function
    "expense.build"
    ( takes @"table" Text
        . takes @"trip" Text
        $ noParams
    )
    \confirmed trip -> W.do
      act payloadWriter [wf|
          {writing}

          The path to write: {payload}

          The trip this report is for: {trip}

          The confirmed table:

          {confirmed}|]

      filled <- ask (expenseFill script payload) [wf|{fill}|]
      answer filled
  where
    writing = payloadBrief
    fill = fillBrief

-- | What the report is written through.
--
-- /Source:/ @commands\/expense-report.md@ Step 5 and its @## Important Notes@ —
-- the receipt-URL reminder, the eight-rows-per-category template limit, and the
-- formula-preservation note, which is the one item there that is a fact about the
-- script rather than an instruction to anybody.
expenseReportBrief :: Text
expenseReportBrief =
  [wft|
  Write the report for an expense-report run. It is read by the operator, who
  will open the spreadsheet before submitting it.

  Open with the provenance line you were given, verbatim, on its own line. It is
  the run's own account of how it ended and it is not yours to soften: in
  particular, if it says nothing was built, do not describe a spreadsheet.

  Then, from the work below and nothing else:

  - the output file path, if one exists, taken from the filler script's own
    output rather than from what you expect it to be;
  - a count of expenses per category, and the total;
  - every row that was flagged for review and what became of it;
  - which receipt files in the file list produced no row, and which rows name a
    file that is not in the list. Both are errors and neither is visible from
    the table alone.

  Then these three, which are facts about the tooling and are worth repeating
  every time:

  - the script writes file:// hyperlinks to local receipts; replace them with
    cloud-hosted URLs before sharing the sheet with accounting;
  - the template has eight rows per category, so a category with more than
    eight expenses needs rows inserted by hand -- say so if any category is at
    or over eight;
  - open the spreadsheet and check the subtotals: the script fills data cells
    only and leaves the formulas to recalculate, which is the intended
    behaviour and not a verification.

  One thing you must not write. Do not describe an amount, a date or a vendor
  as verified against a receipt. Nothing in this run read a receipt document
  except the extracting turn, and its own uncertainty is what the flags record.|]

-- | One act, six provenance lines.
--
-- Three parameters, in the order the body reads them: the provenance first, for
-- "Workflows.Report"'s reason; then the table; then the closing evidence, which is
-- the filler's own output on the two arms that built something and the @find@
-- receipt on the four that did not.
expenseReportFn :: Fn '[ 'CodeText, 'CodeText, 'CodeText] 'CodeAck
expenseReportFn =
  function
    "expense.report"
    ( takes @"provenance" Text
        . takes @"table" Text
        . takes @"evidence" Text
        $ noParams
    )
    \provenance confirmed evidence -> W.do
      act reporter [wf|
          {reporting}

          Provenance:

          {provenance}

          The table:

          {confirmed}

          The closing evidence:

          {evidence}

          Write the report, then reply DONE.|]
      done
  where
    reporting = expenseReportBrief

-- | The table 'expenseProgram' hands @'Agentic.Workflow.defining'@.
--
-- A function of the two paths, because 'expenseBuildFn' is. @defining@ checks
-- that every call names a function the list declared, and declared earlier, so
-- the pair is the unit.
expenseTable :: Text -> Text -> [SomeFn]
expenseTable script payload =
  [SomeFn (expenseBuildFn script payload), SomeFn expenseReportFn]

-- ---------------------------------------------------------------------------
-- The program
-- ---------------------------------------------------------------------------

-- | Inventory, extract, and then hand the table to the owner in binding position.
--
-- Three inputs. @receipts@ is the directory the receipt files are in; @trip@ is
-- the trip name, which in the corpus is \"a quoted string that isn't a file path\"
-- a model has to spot in @$ARGUMENTS@ and here is its own flag; @script@ is the
-- filler's absolute path — see 'fillScript' for why it is an input.
--
-- The shape, top to bottom: @find@ the receipts; extract one table from all of
-- them; read the extraction's own uncertainty flag for nothing; and confirm the
-- table with the owner in whichever of two shapes that flag chose — a bounded
-- revision whose verdict is his, or a single yes\/no. Six endings, six provenance
-- lines, __one__ 'expenseReportFn', and exactly two of the six build anything.
--
-- __The build is behind the human on every path that reaches it.__ There is no
-- arm in which 'expenseBuildFn' runs without an approval or a yes, and that is a
-- property of the printed program rather than of Step 3's \"once the user
-- confirms\".
expenseProgram :: Parameterized
expenseProgram =
  taking (input "receipts" :> input "trip" :> input "script" :> noInputs) \receiptsArg trip scriptArg ->
    -- Tier 1, three times: which directory, which script, and which payload. All
    -- three are ordinary Haskell over the invocation and all three are in the
    -- printed argv.
    let dir = receiptsDir receiptsArg
        script = fillScript scriptArg
        payload = payloadPath
     in defining (expenseTable script payload) W.do
          -- The file list, as bytes `find` wrote. An extraction naming a file
          -- that is not here is caught by comparing the two in the report.
          files <- ask (receiptFiles dir) [wf|{inventory}|]

          table <- ask (broad (model "expense-extract")) [wf|
              {extract}

              {categoryHints}

              {amounts}

              The trip this report is for, if the operator named one: {trip}

              The receipt files:

              {files}|]

          -- The corpus's decorative flag, read for zero questions. It chooses
          -- which shape the confirmation takes, and nothing else in the run.
          flagged <- tested expenseUncertain table

          if flagged
            then W.do
              -- The owner in BINDING position: his answer is the loop's verdict,
              -- and the language reads its three tags three ways.
              --
              -- Written out rather than through `Workflows.Escalation.escalating`
              -- because that function's judge is typed `Party 'IsModel`, and the
              -- one loop in this tree whose judge is a person cannot use it. The
              -- three arms are the same three; see the module header.
              confirmed <- revisingOn table (atMost 2) \candidate -> W.do
                verdict <- ask owner [wf|
                    {asking}

                    {candidate}|]
                amend
                  ( ask (broad (model "expense-correct")) [wf|
                      {correct}

                      The table as it stands:

                      {candidate}

                      What the operator asked for:

                      {verdict}|]
                  )

              case confirmed of
                SettledOn final -> W.do
                  built <- call (expenseBuildFn script payload) (arg final :> arg trip :> noArgs)
                  call_ expenseReportFn (arg builtFlaggedNote :> arg final :> arg built :> noArgs)
                  stop
                UnsettledOn final -> W.do
                  call_ expenseReportFn (arg unresolvedNote :> arg final :> arg files :> noArgs)
                  stop
                AbandonedOn final -> W.do
                  call_ expenseReportFn (arg noAnswerNote :> arg final :> arg files :> noArgs)
                  stop
            else W.do
              -- Nothing was uncertain, so the confirmation is one question and
              -- the correction budget is not spent.
              ok <- confirm owner [wf|
                  {clean}

                  {table}|]

              if ok
                then W.do
                  built <- call (expenseBuildFn script payload) (arg table :> arg trip :> noArgs)
                  call_ expenseReportFn (arg builtCleanNote :> arg table :> arg built :> noArgs)
                  stop
                else W.do
                  call_ expenseReportFn (arg declinedNote :> arg table :> arg files :> noArgs)
                  stop
  where
    inventory = inventoryBrief
    extract = extractBrief
    categoryHints = categoryRules
    amounts = amountRules
    asking = confirmBrief
    clean = cleanConfirmBrief
    correct = correctBrief

-- ---------------------------------------------------------------------------
-- The registry's two other columns
-- ---------------------------------------------------------------------------

-- | The one line @wf list@ prints beside this row.
expenseDoc :: Text
expenseDoc =
  "expense-report.md: receipts as a `find` receipt, one extracted table, and the owner's answer as the loop's verdict"

-- | The canned replies a @--scripted@ run answers from, keyed by prefix.
--
-- __The keys are the defines themselves__, so each is a prefix of the rendered
-- prompt by construction: the inventory's question opens with 'inventoryBrief',
-- the extraction's with 'extractBrief', the confirmation's with 'confirmBrief',
-- the correction's with 'correctBrief', the payload act's with 'payloadBrief' and
-- the filler's with 'fillBrief'.
--
-- __The extraction's row is what steers the run.__ 'expenseUncertain' reads it, and
-- as written it carries a @REVIEW:@ trailer — so a scripted run takes the flagged
-- arm, walks the owner's revision loop, and builds. Change that trailer to
-- @NO REVIEW NEEDED@ and the same run takes the one-question arm instead. Both
-- build, both exit 0, and the four endings that build nothing are each one line
-- away: an @OBJECTION:@ on 'confirmBrief' reaches @UnsettledOn@, an empty answer
-- reaches @AbandonedOn@, and @(cleanConfirmBrief, \"no\")@ reaches the decline.
--
-- @'Agentic.Exec.scriptedDefault'@ answers a flag @yes@ and a receipt @DONE@, so
-- the clean confirmation and the payload act need no rows of their own; the payload
-- act has one anyway, because a table that relies on a default cannot be read as
-- the contract it is.
--
-- __The owner's row is the bare word, and that is not a stylistic choice.__
-- @Agentic.Text.approvesB@ approves only a reply that /is/ an approve word and
-- nothing else, so @\"row 3 is 72.50. APPROVE\"@ is read as an __objection
-- carrying that sentence__ — which is precisely the shape a real answer takes, and
-- is why 'confirmBrief' tells him the word stands alone and that anything beside
-- it is a correction. A table answering with the sentence would have rehearsed the
-- unsettled arm while claiming the built one.
expenseScript :: [(Text, Text)]
expenseScript =
  [ (inventoryBrief, listed),
    (extractBrief, extracted),
    (confirmBrief, "APPROVE"),
    (correctBrief, extracted),
    (payloadBrief, "DONE -- 3 expense objects written."),
    (fillBrief, "Wrote /home/johnw/Documents/expense-report-2026-03-NYC.xlsx (3 expenses, 3 categories).")
  ]
  where
    -- fixture bytes, not prose: fake `ls` stdout.
    listed =
      "/home/johnw/receipts/nyc/flight-confirmation.pdf\n\
      \/home/johnw/receipts/nyc/uber-receipt.png\n\
      \/home/johnw/receipts/nyc/dinner-receipt.jpg"

    extracted =
      [wft|
      ## Extracted Expenses

      | # | Date | Category | Vendor | Amount | Payment | Flag | Source File |
      |---|------|----------|--------|--------|---------|------|-------------|
      | 1 | 03/15/2026 | Flights | United Airlines | $487.30 | Corp Card ...1234 | | /home/johnw/receipts/nyc/flight-confirmation.pdf |
      | 2 | 03/15/2026 | Lyft / Uber | Uber | $34.50 | Personal | | /home/johnw/receipts/nyc/uber-receipt.png |
      | 3 | 03/15/2026 | Dining | Joe's Bistro | $67.82 | | REVIEW | /home/johnw/receipts/nyc/dinner-receipt.jpg |

      **Trip metadata**
      - Trip Name: NYC Summit Q3
      - Destination: New York, NY
      - Dates: 03/15 - 03/15/2026
      - Traveler:

      REVIEW: 3 the total is either 67.82 or 72.50 -- the tip line is
      handwritten and the printed total does not include it.|]
