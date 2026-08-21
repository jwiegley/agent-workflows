-- |
-- Module      : Workflows.Prose
-- Description : The four mechanics every rubric module needs, promoted.
--
-- "Example.Isaac" defines @bullets@ and @tshow@ privately, and every module in
-- this tree would otherwise redefine them. They are here, once, with Isaac's own
-- arguments for each — this module is the bottom of the dependency order,
-- imported by every other and importing none of them.
--
-- __A fifth mechanic used to live here and no longer does.__ Isaac's @wfText@ —
-- @'Agentic.Builder.wordsClosed'@ of a @[wf|…|]@, which is how a define written
-- as a fence became the 'Text' it says — was promoted with the rest, and every
-- define in the tree opened with it. It is now @[wft|…|]@ (@Agentic.WF.wft@, and
-- "Workflows.Prelude" re-exports it): the same fence, the same layout rule and
-- the same hole scan, saying its text directly. The conversion is written once,
-- in the quoter, instead of once in front of each of the 412 defines that used
-- it — which is the whole of the change, and why it could not move a byte.
--
-- __And the string-gap literal went with it, on a ruling that let bytes move.__
-- Those 412 were the defines that were /already/ fences. Beside them stood some
-- 470 prose blocks written as Haskell string gaps — a line ending in a backslash,
-- continued by one beginning with a backslash — which the first sweep left alone
-- for a reason that was true: a gap join encodes a __space__ and a fence join
-- encodes a __newline__, so converting one moves its bytes. The owner ruled on
-- 2026-08-21 that consistency outranks those bytes for prose, \"it should only
-- use the latter\". So every prose gap literal under @src\/@ is now a fence,
-- re-wrapped to read at the width it is sent at, and what survives as a gap
-- literal is __fixture bytes only__: canned stdout, a diff, a schema, a JSON
-- payload, a directory listing, a code scrap — text standing in for what some
-- tool or file produced, inside a scripted table. Several of those shapes a
-- fence cannot hold at all, because it drops its leading and trailing blank
-- lines and cannot end in a newline. Each survivor carries one line above it
-- saying which it is.
--
-- __What made that safe was an oracle rather than care.__ A prompt reaches a
-- run's trace through @Agentic.Exec.oneLine@, which collapses every run of
-- whitespace to a single space — so a re-wrap that moves no /word/ cannot move a
-- printed byte, and all 72 rows' @plan@, @cost@ and @--scripted@ output are
-- byte-for-byte what they were before the sweep. Two things do read line
-- structure, and both are left alone with the reason written beside them: an
-- answer decoded as a verdict, where @Agentic.Text.decodeVerdict@ makes one
-- objection __per line__, and "Workflows.Deciders"' needles, which no wrapped
-- line may begin with.
--
-- __Why a define is 'Text' and not the 'Words' a prompt is__ — the argument that
-- travelled with @wfText@, and which the four fragments below now carry, because
-- each of them is a define computed rather than written:
--
--   * A scripted table keys its canned replies on the defines themselves, and a
--     key is a 'Text' matched as a prefix of a /rendered/ prompt. Defines typed
--     as @Words@ would have to be rendered at every row instead.
--   * __Chunking is normative.__ @plan --raw@ prints the chunk list, so a define
--     that splices as /two/ chunks where it spliced as one is a visible change
--     even when the prompt's bytes are identical. Every derived brief in this
--     tree holes a computed count or a roster table; as @Words@ each of those
--     holes would carry a chunk boundary into every prompt that splices them,
--     and as 'Text' they carry the one @lit@ they always did.
--
-- __Why this is not @Workflows.Prelude@.__ 'Workflows.Prelude' re-exports the
-- whole foundation, so nothing the foundation is made of can import it. The two
-- names are the split: the /mechanics/ are here and every foundation module
-- imports them directly; the /one import an author writes/ is
-- "Workflows.Prelude", and only the programs use it.
{-# LANGUAGE OverloadedStrings #-}

module Workflows.Prose
  ( -- * Derived prompt fragments
    bullets,
    numbered,
    fenceOf,
    tshow,
  )
where

import Data.Text (Text)
import qualified Data.Text as T

-- | A roster as the bullet table a derived brief holes, one row per entry.
--
-- This is @incite@'s @qaOfCommitOver@ and @grindSynthesisOver@: a member's
-- brief is spliced with the roster derived from the very list the fan-out is
-- built from, so a lens added to the table arrives in every sibling's brief by
-- being added, and \"do not repeat what the others own\" is a sentence with a
-- referent.
bullets :: [(Text, Text)] -> Text
bullets rows = T.intercalate "\n" ["- " <> n <> " -- " <> owns | (n, owns) <- rows]

-- | The same table, numbered, for a brief that asks for an ordered walk.
numbered :: [Text] -> Text
numbered rows =
  T.intercalate "\n" [tshow i <> ". " <> r | (i, r) <- zip [1 :: Int ..] rows]

-- | One named block of a folded document — the shape
-- 'Agentic.Workflow.panelText' writes, available to a brief that has to /ask/
-- for it.
--
-- A brief that tells a model \"fence your answer under \<name\>\" and a fold
-- that fences it are two spellings of one contract, and this is the spelling
-- both use.
fenceOf :: Text -> Text -> Text
fenceOf n body = "<" <> n <> ">\n" <> body <> "\n</" <> n <> ">"

-- | A number as prompt text, for the briefs that tell a member how many blocks
-- it is one of.
tshow :: Int -> Text
tshow = T.pack . show
