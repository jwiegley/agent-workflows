-- |
-- Module      : Workflows.Query
-- Description : An SQL query built from a schema, by parties that cannot reach
--               the data.
--
-- == The map: old Markdown -> new program
--
-- +-----------------------------------------+--------------------------------------------------------------+
-- | @~\/src\/nix\/config\/ai@               | here                                                         |
-- +=========================================+==============================================================+
-- | @commands\/query-builder.md@ line 7     | 'queryProgram' — the whole row: one schema receipt, one      |
-- | (\"I want an SQL query that can answer  | draft, and a bounded audit that must approve before the      |
-- | the following\")                        | query is reported                                            |
-- +-----------------------------------------+--------------------------------------------------------------+
-- | its lines 1–5 (three sentences          | an __absence__. See \"The prohibition is a type\" below:     |
-- | forbidding data disclosure)             | there is no database argv in this tree, so no question in     |
-- |                                         | this program has the data in scope to reveal                  |
-- +-----------------------------------------+--------------------------------------------------------------+
-- | its \"use the sql-pro\"                 | @'Workflows.Parties.sqlPro'@ — an addressee, pinned, and      |
-- |                                         | @--require-pinned@ refuses a run that left the pin out        |
-- +-----------------------------------------+--------------------------------------------------------------+
-- | its \"and the mssql MCP\"               | __narrowed, and named:__ 'dialectOf', whose default carries   |
-- |                                         | that MCP's dialect, over a schema the operator names. See     |
-- |                                         | \"One narrowing\" below                                       |
-- +-----------------------------------------+--------------------------------------------------------------+
-- | @agents\/sql-pro.md@                    | "Workflows.Parties"' @sqlPro@; what it /knows/ is reference   |
-- |                                         | material and stays where it is (§7.3, the nine @-pro@)       |
-- +-----------------------------------------+--------------------------------------------------------------+
--
-- The Markdown was read as __data__. Nothing in @~\/src\/nix\/config\/ai@ is
-- modified by this module, and no party in it points at that tree.
--
-- == The prohibition is a type
--
-- @doc\/design.md@ §7.2 row 46: \"the schema reader answers @CodeText@ and
-- therefore cannot act; the data is never in scope to leak because no question
-- puts it there. Three repetitions of \'never reveal data\' collapse into one
-- type.\"
--
-- That is the whole of this row, and it is worth being exact about /which/
-- mechanism does it, because there are two and they are different:
--
--   1. __No party in this program can read the database.__ There is no @sqlcmd@,
--      no @psql@, no connection string and no MCP client anywhere in
--      "Workflows.Evidence" or in the argv block below. The only world-authored
--      input is @cat \<schema\>@. So \"treat all of the data in the database as
--      if it were highly secret\" is not an instruction a tired run skips: the
--      data is not reachable from here at all.
--   2. __The drafting and auditing questions are asked at @text@__, and
--      @Agentic.Acp.permissionByCode@ grants write authority only to an
--      @'Agentic.Workflow.act'@ at @'Agentic.Raw.CodeAck'@ — and this program
--      contains no @act@. So no node in it can run the query it wrote, which is
--      the corpus's \"build me an SQL query that I can run myself\" made
--      structural rather than requested.
--
-- What survives in prompt text is one sentence, in 'draftBrief', and it is there
-- for a reason the two mechanisms above do not cover: the /answer/ could still
-- carry invented sample rows. That is a thing an answer does, not a thing an
-- authority permits, so it is asked for — once — and then audited by somebody
-- else.
--
-- == The leveling-up, item by item
--
--   1. __A mutating statement is caught for nothing.__ The command asks for a
--      query \"that I can run myself\", which means the owner runs whatever comes
--      back. An answer opening a line with @DELETE @, @UPDATE @, @DROP @ or
--      @TRUNCATE @ is therefore the single most expensive way this row can be
--      wrong, and it is decidable: 'mutatingStatement' is one
--      @'Agentic.Workflow.AnyLineStartsWith'@ over the draft, at zero questions
--      and one path, and its arm reports and stops without asking anybody
--      anything. The corpus has no such check and could not have one.
--
--   2. __The audit is not the author.__ The draft is @sqlPro@'s and the audit is
--      a differently-@'Agentic.Workflow.servedBy'@ party's
--      ('Workflows.Parties.lateral'), because a query checked for correctness and
--      for disclosure by the model that wrote it is not checked. This is the same
--      arrangement @notes@ uses for its five checkpoints and @comments@ for its
--      false-positive guard.
--
--   3. __\"Re-check it\" gets a stopping rule.__ The command's implied loop — draft,
--      look at it, fix it — is
--      @'Workflows.Escalation.escalating' … ('Agentic.Workflow.atMost' 2)@, so the
--      three ways it can end are three arms the compiler makes be written: the
--      audit approved, the bound ran out with an objection outstanding, or the
--      audit declined to judge. @wf cost query@ prices all three before a token
--      moves.
--
--   4. __The schema is a receipt, not a recollection.__ @cat \<schema\>@ is bytes
--      the answering model did not write, bound once and spliced into the draft
--      and into every audit trip — so the query and the audit cannot be reading
--      two different schemas, which is exactly what happens when a schema is
--      pasted into a conversation and then partly re-described.
--
-- == One narrowing, recorded rather than absorbed
--
-- __The mssql MCP is not carried, and cannot be.__ The corpus's first sentence
-- names two tools: @sql-pro@, which is an addressee and is carried, and \"the
-- mssql MCP\", which is a live connection to the database. Two things stand
-- against carrying it, and the second is the stronger:
--
--   * every argv in this tree is program-authored and reviewable as a unit, and
--     an MCP client is not an argv;
--   * __a program that can reach the data is a program whose read-only claim is a
--     promise rather than a type__, which is the one thing §7.2 row 46 says this
--     row exists to make structural.
--
-- So the schema arrives as a file the operator names — a dump, a @\\d@ paste, a
-- DDL export — and 'dialectOf' carries that MCP's own dialect as the default, so
-- the row generalises to another engine without losing the one it was written
-- for. That is @fix-integration@'s arrangement (§7.2 row 18) applied to a
-- dialect instead of an error string.
--
-- __What is lost by it, stated plainly:__ a schema the operator has not exported
-- is a schema this row cannot see, and an out-of-date export produces a query
-- against a table shape that no longer exists. The receipt makes the /file/
-- visible in the report; it cannot make the file current. The report is told to
-- say so.
{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QualifiedDo #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE RebindableSyntax #-}
{-# LANGUAGE TypeApplications #-}

module Workflows.Query
  ( -- * The program
    queryProgram,
    queryDoc,
    queryScript,

    -- * The free test this module owns
    mutatingStatement,

    -- * The tier-1 readings of an invocation
    schemaPath,
    dialectOf,

    -- * The rubrics, transplanted
    draftBrief,
    auditBrief,

    -- * The function
    queryReportFn,
    queryTable,
  )
where

import qualified Agentic.Workflow.Do as W
import Data.String (fromString)
import Data.Text (Text)
import qualified Data.Text as T
import Workflows.Prelude
import Prelude

-- ---------------------------------------------------------------------------
-- The free test this module owns
-- ---------------------------------------------------------------------------

-- | A statement that would change the database, in an answer that was asked for
-- a query the owner will run himself.
--
-- /Source:/ @commands\/query-builder.md@ line 3, \"build me an SQL query that I
-- can run myself to obtain the actual data\". The owner runs what comes back, so
-- the answer's /verb/ is the load-bearing word in it.
--
-- __Why this pair lives here and not in "Workflows.Deciders".__ It is this row's
-- own test and has exactly one call site, which is @'Workflows.Git.Stack.commitLost'@'s
-- arrangement: a decider with one caller is that caller's, and the shared module
-- is for the tests several programs read. If a second row ever wants it, the move
-- is one cut.
--
-- __The needles are exact and the reason is 'Agentic.Text.dlines'.__ A line is
-- ASCII-lowercased and @'Agentic.Text.bare'@d — leading backticks, asterisks,
-- underscores, spaces and dots are dropped from both ends — so the first line
-- inside a @```sql@ fence is tested at @delete from …@ and matches. A needle is
-- lowercased and __not__ trimmed, so the trailing space is significant and is
-- what keeps @deleted_at@ from matching @delete @. A SQL comment (@-- delete the
-- old rows@) does not match either, because the needle is a prefix test and the
-- line begins @--@.
mutatingStatement :: (Decider, [Text])
mutatingStatement =
  ( AnyLineStartsWith,
    [ "insert ",
      "update ",
      "delete ",
      "drop ",
      "truncate ",
      "alter ",
      "merge ",
      "grant ",
      "revoke ",
      "create ",
      "exec ",
      "execute "
    ]
  )

-- ---------------------------------------------------------------------------
-- The tier-1 readings of an invocation
-- ---------------------------------------------------------------------------

-- | The schema file the run reads, or a name no file has.
--
-- __Tier 1__ ("Workflows.Deciders"): ordinary Haskell over the invocation, zero
-- questions and zero paths. An absent path becomes a name no file has, which is
-- @'Workflows.Checklist'@'s and @'Workflows.Notes'@' rule and
-- 'Workflows.Git.Commit.treeNeedle'\''s: @wf plan query --raw@ prints
-- @cat \<no schema given\>@, so an operator who forgot the flag learns it from
-- the plan rather than from a query written against nothing.
schemaPath :: Text -> Text
schemaPath p
  | T.null (T.strip p) = "<no schema given>"
  | otherwise = T.strip p

-- | Which SQL the query is written in.
--
-- __Tier 1__, and the default is the corpus's own: @query-builder.md@ names the
-- @mssql@ MCP, so an invocation that says nothing gets T-SQL. That is
-- @commands\/fix-integration.md@'s arrangement — @doc\/design.md@ §7.2 row 18,
-- \"the hardcoded error string becomes a second input whose sample carries
-- today's text, so it generalises without losing its default\" — applied to a
-- dialect.
--
-- The value is spliced into the drafting brief and into the audit's, so the two
-- cannot disagree about which engine they are talking about; and it costs nothing,
-- because it is decided before the 'Agentic.Builder.Program' exists.
dialectOf :: Text -> Text
dialectOf d
  | T.null (T.strip d) = "Microsoft SQL Server (T-SQL)"
  | otherwise = T.strip d

-- ---------------------------------------------------------------------------
-- The rubrics, transplanted
-- ---------------------------------------------------------------------------

-- | What the schema receipt is introduced as.
--
-- The words go to @cat@'s standard input, which @cat@ reading a named file does
-- not consult; they are here because they are the scripted table's key and
-- because @wf plan --raw@ prints them, so a reader of the plan can see what the
-- receipt is for. That is "Workflows.Gates"' and
-- @'Workflows.Git.Commit.seriesBrief'@'s reason.
schemaBrief :: Text
schemaBrief =
  [wft|
  The database schema, as the operator exported it. This is the only thing
  this run knows about the database: no party in this program can connect to
  it, and nothing below reads a row.|]

-- | What the drafting question asks.
--
-- /Source:/ @commands\/query-builder.md@ lines 2–3 and 7 — \"only reference the
-- schema in order to build me an SQL query that I can run myself to obtain the
-- actual data\" and \"I want an SQL query that can answer the following\".
--
-- The file's three sentences forbidding disclosure are __not__ transcribed; see
-- the module header. The one sentence below that is about disclosure is about the
-- /answer/, which is the one surface the two structural mechanisms do not cover.
draftBrief :: Text
draftBrief =
  [wft|
  Write one SQL query that answers the question below, against the schema
  below and nothing else.

  Answer with the query and nothing else: no sample rows, no invented values,
  no example result set, no "the output would look like this". You have not
  seen this database's data and neither has anything else in this run, so any
  row-shaped text in your answer would be fabricated -- and a fabricated row
  in a query's documentation is read as a real one.

  Read the query first. Every table, column and join key you use must appear
  in the schema below. Where the question needs something the schema does not
  have, say so in one line above the query and write the closest query the
  schema does support -- do not invent a column to make the question
  answerable.

  Then, below the query, and in this order:

  - one line saying what the query returns: one row per what, with which
    columns;
  - the assumptions you made about the data that the schema does not state
    (which columns are nullable in practice, whether a status code set is
    closed, what a soft delete looks like here), because those are what make a
    correct-looking query wrong;
  - the indexes or keys the query relies on, and what it would cost without
    them.

  It is a SELECT. Do not write a statement that changes anything: no INSERT,
  UPDATE, DELETE, MERGE, DROP, TRUNCATE, ALTER, CREATE, GRANT or stored
  procedure call. The operator runs what you write, by hand, on his own
  database.|]

-- | What the audit is told, above 'Workflows.Escalation.endingSpec'.
--
-- /Source:/ the same file, read as the check it implies rather than as the
-- instruction it is. Its three sentences all ask one question — did this answer
-- keep the data out of it? — and its line 3 asks a second: will the query
-- actually answer what was asked?
--
-- Both are put to a party that did not write the draft, which is why this row
-- has an audit at all.
auditBrief :: Text
auditBrief =
  [wft|
  Audit a candidate SQL query. You did not write it and you are not rewriting
  it: you judge it, and the author gets one line back.

  Three things, in this order, and the first is the one that ends a run:

  1. Disclosure. Does the answer contain data, or anything that reads as data?
     A sample row, a plausible identifier, an example output table, a count, a
     named customer, a date that looks like a real transaction. Nothing in this
     run has read a single row, so any of those is fabricated and must not be
     presented as though it came from the database. This is an objection, every
     time.

  2. Correctness against the schema. Take every table, column and join key the
     query names and find it in the schema you were given. A name that is not
     there is an objection and the line says which. Then check the joins for
     fan-out (does a one-to-many join multiply the measure being aggregated?),
     the filters for the null case, and the aggregation for whether it groups
     by what the question asked about.

  3. Does it answer the question that was asked? Not a near neighbour of it.
     If the query answers something subtly different -- the wrong grain, the
     wrong period boundary, distinct-counting rows rather than entities -- say
     which, in one line.

  A query that is correct, answers the question, and carries no data is an
  approval, and an approval is the single word APPROVE and nothing else --
  anything you add beside it is read as an objection by the program that
  consumes your verdict. So what you checked belongs in an objection line or
  nowhere. Style, formatting and micro-optimisation are not objections.|]

-- | What the author is told on a repair trip.
reviseBrief :: Text
reviseBrief =
  [wft|
  An auditor read your query and objected. Produce the next version of the
  query and nothing else -- the same output contract as before, and no
  commentary about the change.

  Fix what the objection names. If the objection is wrong, say so in one line
  at the top and leave the query as it stands: a query quietly bent to satisfy
  a mistaken objection is worse than the objection.|]

-- ---------------------------------------------------------------------------
-- The provenance lines
-- ---------------------------------------------------------------------------

-- | The arm where the audit approved.
approvedNote :: Text
approvedNote =
  [wft|
  Outcome: A QUERY, AUDITED. The schema was read as a receipt, one query was
  written against it, and an auditor on a different serving model approved it
  for disclosure, for correctness against that schema and for answering the
  question asked. Report the query, the assumptions it rests on, and the fact
  that nothing in this run connected to the database -- so the query has never
  been executed and its plan has never been seen.|]

-- | The arm where the bound ran out.
unresolvedNote :: Text
unresolvedNote =
  [wft|
  Outcome: NOT SETTLED. The audit still objected after every repair trip this
  run was given, so the query below is the one the last trip produced and the
  final audit objected to -- no trip was spent answering that last objection. Do
  NOT present it as ready to run. Report the outstanding objection first, in the
  auditor's own words, and then the query beneath it.|]

-- | The arm where the audit declined.
declinedNote :: Text
declinedNote =
  [wft|
  Outcome: NOT AUDITED. The auditor declined to judge the query at all, which
  means it could not tell what it was looking at -- most often because the
  schema receipt is not a schema, or is empty. Report the query as UNCHECKED,
  name the schema file the run was pointed at, and say that no disclosure check
  and no correctness check was completed.|]

-- | The arm the free decider takes.
--
-- /Source:/ the negation of @query-builder.md@ line 3's \"a query that I can run
-- myself\". This is the one ending the corpus cannot have, because it has nothing
-- that reads the answer.
mutatingNote :: Text
mutatingNote =
  [wft|
  Outcome: REFUSED -- THE ANSWER WOULD CHANGE THE DATABASE. A line of the draft
  begins with a statement that writes: INSERT, UPDATE, DELETE, MERGE, DROP,
  TRUNCATE, ALTER, CREATE, GRANT, REVOKE or a procedure call. This row exists to
  hand the operator something he runs by hand against his own database, so a
  write is refused rather than reported. Nothing was audited and no repair was
  attempted. Quote the offending line, say what a read-only query answering the
  same question would look like, and stop.|]

-- ---------------------------------------------------------------------------
-- The function
-- ---------------------------------------------------------------------------

-- | What the report is written through.
queryReportBrief :: Text
queryReportBrief =
  [wft|
  Write the report for a query-building run. It is read by the operator, who
  will run the query himself against a database this run never touched.

  Open with the provenance line you were given, verbatim, on its own line. It
  is the run's own account of how it ended and it is not yours to soften.

  Then, from the work below and nothing else:

  - the query, in one fenced block, exactly as it stands;
  - what it returns: one row per what, with which columns;
  - the assumptions it rests on, as a list;
  - the schema file this run read, by name, and this sentence: the query was
    written against that file, and this run has no way to know whether the
    file is current;
  - what was NOT established -- the query has not been executed, its plan has
    not been seen, and no row of this database has been read by anything in
    this run.

  Two things you must not write. Do not add an example result set, a sample
  row, or an illustrative value of any kind: nothing here has seen the data,
  so every such value would be invented. And do not describe the query as
  verified: an audit read it, which is not the same as a database having run
  it.|]

-- | One act, four provenance lines.
--
-- Three parameters, in the order the body reads them: the provenance first, for
-- "Workflows.Report"'s reason; then the query; then the schema receipt, so the
-- report can name the file it was written against without a question being spent
-- on saying so.
queryReportFn :: Fn '[ 'CodeText, 'CodeText, 'CodeText] 'CodeAck
queryReportFn =
  function
    "query.report"
    ( takes @"provenance" Text
        . takes @"query" Text
        . takes @"schema" Text
        $ noParams
    )
    \provenance qry schema -> W.do
      act reporter [wf|
          {queryReportBrief}

          Provenance:

          {provenance}

          The query:

          {qry}

          The schema it was written against:

          {schema}

          Write the report, then reply DONE.|]
      done

-- | The table 'queryProgram' hands @'Agentic.Workflow.defining'@.
queryTable :: [SomeFn]
queryTable = [SomeFn queryReportFn]

-- ---------------------------------------------------------------------------
-- The program
-- ---------------------------------------------------------------------------

-- | One schema receipt, one draft, one free refusal, and a bounded audit on
-- another engine.
--
-- Three inputs. @question@ is what the query must answer — @query-builder.md@'s
-- own trailing \"I want an SQL query that can answer the following\"; @schema@ is
-- the path to the exported schema, and 'schemaPath' says what an absent one
-- means; @dialect@ is which SQL, and 'dialectOf' carries the corpus's own default.
--
-- The shape, top to bottom: read the schema as bytes; draft one query against it;
-- refuse for nothing if the draft would write; otherwise audit it on a different
-- serving model with a bound, and end in one of three ways. Four endings, four
-- provenance lines, __one__ 'queryReportFn'.
--
-- __There is no @act@ in this program.__ That is not an omission and it is the
-- row: @Agentic.Acp.permissionByCode@ grants write authority only to an @act@ at
-- @'Agentic.Raw.CodeAck'@, and the only one here is inside 'queryReportFn',
-- which writes a report. So \"a query that I can run myself\" is a property of
-- the printed program rather than a sentence in a prompt.
queryProgram :: Parameterized
queryProgram =
  taking (input "question" :> input "schema" :> input "dialect" :> noInputs) \question schemaArg dialectArg ->
    -- Tier 1, twice: which file, and which SQL. Both are ordinary Haskell over
    -- the invocation, and both are visible in `wf plan --raw` before the run.
    let path = schemaPath schemaArg
        dialect = dialectOf dialectArg
     in defining queryTable W.do
          -- The one thing the world authors here, bound once and spliced into
          -- the draft and into every audit trip.
          schema <- ask (fileContents path) [wf|{schemaBrief}|]

          draft <- ask sqlPro [wf|
              {drafting}

              The SQL dialect: {dialect}

              The question:

              {question}

              The schema:

              {schema}|]

          -- Zero questions, one path, and the needles are in the printed
          -- program. The owner runs what comes back, so this is the cheapest
          -- check in the row and it goes first.
          writes <- tested mutatingStatement draft

          if writes
            then W.do
              call_ queryReportFn (arg mutatingNote :> arg draft :> arg schema :> noArgs)
              stop
            else W.do
              -- The audit is a different serving model from the author's, which
              -- is the whole reason this row has one.
              audited <-
                escalating
                  (lateral (model "query-audit"))
                  (auditFor dialect)
                  sqlPro
                  reviseBrief
                  draft
                  (atMost 2)

              case audited of
                SettledOn final -> W.do
                  call_ queryReportFn (arg approvedNote :> arg final :> arg schema :> noArgs)
                  stop
                UnsettledOn final -> W.do
                  call_ queryReportFn (arg unresolvedNote :> arg final :> arg schema :> noArgs)
                  stop
                AbandonedOn final -> W.do
                  call_ queryReportFn (arg declinedNote :> arg final :> arg schema :> noArgs)
                  stop
  where
    drafting = draftBrief

-- | The audit's brief with the dialect named in it.
--
-- __Tier 1__, and it is why the row has one define and not two: the author and
-- the auditor are told the same dialect, computed once from the invocation, so
-- they cannot be talking about two engines. The schema is a handle and is spliced
-- by 'Workflows.Escalation.escalating' as the candidate's companion; the dialect
-- is a fact about the invocation and belongs in the define.
auditFor :: Text -> Text
auditFor dialect = auditBrief <> "\n\nThe SQL dialect: " <> dialect

-- ---------------------------------------------------------------------------
-- The registry's two other columns
-- ---------------------------------------------------------------------------

-- | The one line @wf list@ prints beside this row.
queryDoc :: Text
queryDoc =
  "query-builder.md: a query written against a schema receipt by parties that cannot reach the data, audited on another engine"

-- | The canned replies a @--scripted@ run answers from, keyed by prefix.
--
-- __The keys are the defines themselves__, so each is a prefix of the rendered
-- prompt by construction: the schema receipt's question opens with 'schemaBrief',
-- the draft's with 'draftBrief', and the audit's with 'auditBrief' — the last
-- through @'auditFor' \"\"@, which is 'auditBrief' followed by the default dialect,
-- and 'auditBrief' alone is a prefix of it either way.
--
-- __The draft's row is the load-bearing one.__ 'mutatingStatement' reads it, so
-- this canned query is what decides which arm a scripted run takes: as written it
-- is a @SELECT@ and the run walks the audit; open any line of it with @DELETE @
-- and the same run takes the refusal arm and still exits 0. That is the point of
-- writing the cheap ending first — it is reachable by editing one word here.
--
-- The audit's row is written with the approving answer even though a verdict
-- question's scripted default is @APPROVE@ anyway, for
-- @'Workflows.Comments.commentsScript'@'s reason: a table that relies on a default
-- cannot be edited into the other two arms in one line. An @OBJECTION:@ here
-- reaches @UnsettledOn@ and an empty answer reaches @AbandonedOn@, and all three
-- exit 0.
--
-- __And it is the bare word, which is not a stylistic choice.__
-- @Agentic.Text.approvesB@ approves only a reply that /is/ an approve word and
-- nothing else, so a row answering @\"APPROVE -- checked the joins\"@ would be
-- read as an objection carrying that sentence, and this table would rehearse the
-- unsettled arm while claiming the approved one. "Workflows.OrgTasks" and
-- "Workflows.Effort" both record the same fact at their own verdict rows.
queryScript :: [(Text, Text)]
queryScript =
  [ (schemaBrief, schema),
    (draftBrief, drafted),
    (auditBrief, "APPROVE"),
    (reviseBrief, drafted)
  ]
  where
    -- fixture bytes, not prose: the schema DDL the MCP server returns. The fence
    -- carries the exact bytes: its margin sits at the `CREATE TABLE` lines, so
    -- common-strip removes the margin and nothing else, and the two-space column
    -- indent and the type-column padding both survive.
    schema =
      [wft|
      CREATE TABLE dbo.Invoice (
        InvoiceId    INT           NOT NULL PRIMARY KEY,
        CustomerId   INT           NOT NULL,
        IssuedOn     DATE          NOT NULL,
        VoidedOn     DATE          NULL,
        TotalCents   BIGINT        NOT NULL
      );
      CREATE TABLE dbo.Customer (
        CustomerId   INT           NOT NULL PRIMARY KEY,
        Name         NVARCHAR(200) NOT NULL,
        RegionId     INT           NOT NULL
      );|]

    drafted =
      [wft|
      ```sql
      SELECT c.RegionId,
             SUM(i.TotalCents) / 100.0 AS BilledDollars
      FROM dbo.Invoice AS i
      JOIN dbo.Customer AS c ON c.CustomerId = i.CustomerId
      WHERE i.VoidedOn IS NULL
        AND i.IssuedOn >= '2026-01-01'
        AND i.IssuedOn <  '2026-04-01'
      GROUP BY c.RegionId
      ORDER BY BilledDollars DESC;
      ```

      Returns one row per region, with the region id and the dollars billed in
      the first quarter of 2026.

      Assumptions: a voided invoice is one with a non-null VoidedOn, and
      IssuedOn is the billing date rather than the delivery date. Relies on the
      primary key on Customer.CustomerId; without an index on Invoice.IssuedOn
      this is a full scan of Invoice.|]
