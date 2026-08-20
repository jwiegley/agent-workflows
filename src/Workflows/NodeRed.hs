-- |
-- Module      : Workflows.NodeRed
-- Description : Flows on the owner's own host — the admin boundary as argv, and
--               the event log as a receipt.
--
-- == The map: old Markdown -> new program
--
-- +-------------------------------------------+---------------------------------------------------------------+
-- | @~\/src\/nix\/config\/ai@                 | here                                                          |
-- +===========================================+===============================================================+
-- | @skills\/node-red\/SKILL.md@              | @nodered@ — the whole file, as one program                     |
-- +-------------------------------------------+---------------------------------------------------------------+
-- | its @## Supported admin boundary@ (three  | 'nodeRedFlowsGet', 'nodeRedFlowGet', 'nodeRedFlowPut' — the    |
-- | signatures, \"callers cannot supply a     | __only three__ argv in this module that touch the runtime,      |
-- | method, path, URL, or transport option\") | and there is no fourth to supply                               |
-- +-------------------------------------------+---------------------------------------------------------------+
-- | its @FLOW_ID@ regex                       | 'validFlowId' — ordinary Haskell over the invocation, so a     |
-- |                                           | malformed id never reaches the helper                          |
-- +-------------------------------------------+---------------------------------------------------------------+
-- | its @## House style@ (five subsections)   | 'houseRoster' — six lenses over one fetched tab                |
-- | and @## Top pitfalls@ (fourteen)          |                                                                |
-- +-------------------------------------------+---------------------------------------------------------------+
-- | its @## Debugging workflow@ (two SQL      | 'eventLog' — one @psql@ receipt, and                            |
-- | queries and a Grafana walk)               | 'Workflows.Deciders.noRowsReturned' reading its footer for     |
-- |                                           | nothing: \"zero rows -\> upstream issue\" becomes a branch      |
-- +-------------------------------------------+---------------------------------------------------------------+
-- | \"don't fabricate entity IDs — verify     | 'entityRegistry' — a @jq@ receipt over the registry, so the    |
-- | against @core.entity_registry@\"          | entity list is bytes rather than recall                        |
-- +-------------------------------------------+---------------------------------------------------------------+
-- | @scripts\/generate_uuid.py@               | 'freshNodeIds' — a receipt, bound before the edit              |
-- +-------------------------------------------+---------------------------------------------------------------+
-- | @scripts\/validate_flow.py@               | 'validateFlow' — a @verdict@ over the staged envelope, before  |
-- |                                           | the put                                                        |
-- +-------------------------------------------+---------------------------------------------------------------+
-- | its @### Subflow status output@ snippet   | the @naming@ lens's brief, where the snippet belongs: it is a  |
-- |                                           | pattern to match, not a command to run                         |
-- +-------------------------------------------+---------------------------------------------------------------+
-- | the six @references\/*.md@ (1,756 lines)  | @'Agentic.Workflow.input' \"references\"@ — an @--input-file@,   |
-- |                                           | not prompt bulk                                                |
-- +-------------------------------------------+---------------------------------------------------------------+
--
-- The Markdown was read as __data__. Nothing in @~\/src\/nix\/config\/ai@ is
-- modified by this module, and no party in it points at that tree.
--
-- == The leveling-up, item by item
--
--   1. __The admin boundary is the argv, and the boundary's own sentence becomes
--      an absence.__ @doc\/design.md@ §7.4 row 22 asks for exactly this: the
--      \"supported admin boundary\" rides on the question and the argv rather
--      than in prompt text. \"Callers cannot supply a method, path, URL, or
--      transport option\" is not a rule any question in this program is trusted
--      with — there are three @node-red-admin@ argv in this module and no fourth,
--      no @curl@, no HTTP library, no flow-file path and no credential read. A
--      caller cannot supply a transport option because there is nowhere to put
--      one, and @wf plan nodered --raw@ is the evidence.
--
--   2. __The @FLOW_ID@ regex is checked before the program exists.__ The skill
--      states it — @[0-9a-f]{1,32}(?:\\.[0-9a-f]{1,32})?@ — and then relies on
--      the helper to enforce it, which means a typo costs a round trip and an
--      exit-2. 'validFlowId' is tier 1: a malformed id is replaced by a name
--      nothing has, so @wf plan --raw@ prints the omission and a @--scripted@
--      run never reaches a command at all. That is
--      @'Workflows.Comments'@'s @extractor=@ arrangement at an identifier.
--
--   3. __\"Zero rows -\> upstream issue\" becomes a branch, for zero questions.__
--      The debugging workflow's whole method is: query @msg_events@ for the
--      trigger's @onSend@, and \"zero rows -\> upstream issue. Rows present -\>
--      drill in via msgid.\" @psql@ prints its own row count, so
--      @'Workflows.Deciders.noRowsReturned'@ reads it and the two conclusions the
--      skill draws are two provenance lines. The needle is @psql@'s footer,
--      which no model authored.
--
--   4. __\"Don't fabricate entity IDs\" becomes a receipt.__ The skill's last
--      \"things to avoid\" bullet says to verify against
--      @\/var\/lib\/hass\/.storage\/core.entity_registry@, filtered with @jq@.
--      Here that @jq@ runs, and its output is in every lens's dossier — so an
--      entity id in the edited flow either appears in bytes the run collected or
--      it does not, and a reader of the report can tell which. A prohibition
--      against inventing a name is much weaker than the list of real ones.
--
--   5. __\"Always check the existing wiring, never assume from the name\" is why
--      the tab is a handle.__ Pitfall 1 is the one the skill spends most words on:
--      @api-current-state@'s output 0 is the match and output 1 is the no-match,
--      the same @halt_if@ is wired both ways in different parts of this codebase,
--      and the direction must be read rather than inferred. The fetched tab is
--      bound __once__ and spliced into all six lenses by
--      @'Workflows.Panels.withEvidence'@, so no two of them can be reasoning about
--      different wires — @commands\/heavy-review.md@'s frozen-snapshot argument
--      arriving at a flow file.
--
--   6. __The put is the one node with write authority, and it is an @act@.__
--      @Agentic.Acp.permissionByCode@ grants write authority to an
--      @'Agentic.Workflow.act'@ at @receipt@ and to nothing else, and the
--      envelope goes to the helper's __standard input__, which is exactly the
--      interface @flow put FLOW_ID \< flow.json@ asks for. Every other question
--      in the program is a @text@, a @flag@ or a @verdict@, none of which can
--      write anything whatever they are told.
--
-- == Three honest notes
--
-- __Two of the four scripts are deliberately not parties, and the reason is a
-- fact about the language.__ @doc\/design.md@ §7.4 row 22 says \"four Python
-- scripts as four @proc@ parties\"; two of them are here and two are not.
-- @wire_nodes.py \<file\> \<src\> \<tgt\>@ takes the two node ids to connect, and
-- @create_flow_template.py \<type\>@ takes a template kind — and both of those
-- are things only a /model's answer/ could supply. __An answer never becomes an
-- argv; only an invocation does.__ A party whose arguments are not knowable
-- before the run is a party this language cannot build, and pretending otherwise
-- would mean asking the operator to type node ids he has not seen yet. The
-- template script has a second reason, which is the corpus's own: \"these are not
-- in John's style — use as scaffolding only\", and a row that scaffolds in
-- somebody else's style produces work he will reject.
--
-- __The staged working copy is what the validator reads, and the helper is the
-- second gate.__ The skill's canonical procedure is fetch, edit, put, refetch,
-- with \"a private mode-0700 temporary directory with a cleanup trap for every
-- returned document\". So the edit is staged by an @act@, @validate_flow.py@ runs
-- over that file as a @verdict@, and the put's stdin is the same envelope. If the
-- staging act wrote something other than what it was given, the validator would
-- pass and the helper would still catch it: it re-reads the selected flow, checks
-- the id against the command's id, checks that @nodes@ is an array and that
-- @configs@ is one when present, and __refuses a stale @baseDigest@ before
-- sending any update__. Two gates, and the second one is the runtime's own.
--
-- __This row is host-specific on purpose.__ @doc\/design.md@ §7.4 row 22 says
-- \"deeply host-specific — port last\", and it is the last of wave 5 for that
-- reason. The paths, the config-node ids, the database name and the entity
-- families are one machine's, exactly as @'Workflows.Tron'@'s are one working
-- tree's. An input whose only sensible value is one string is a flag nobody will
-- ever vary; what /is/ an input here is the pair a session actually varies — which
-- tab, and which node's history is being explained.
{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QualifiedDo #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE RebindableSyntax #-}
{-# LANGUAGE TypeApplications #-}

module Workflows.NodeRed
  ( -- * The program
    noderedProgram,
    noderedDoc,
    noderedScript,

    -- * The tier-1 readings of an invocation
    validFlowId,
    flowIdOf,
    nodeIdOf,
    scriptIn,

    -- * The house style
    houseRoster,

    -- * The rubrics, transplanted
    hostFacts,
    houseClosing,
    editBrief,

    -- * The function
    noderedReportFn,
    noderedTable,
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
-- labelled block, for @'Workflows.Tron'@'s and @'Workflows.Retest'@'s reason:
-- they are one host's administration surface, the move is one cut and one paste,
-- and the exception is visible rather than scattered.
--
-- __This block is the admin boundary.__ Three @node-red-admin@ invocations, one
-- @psql@ read, one @jq@ read, and two of the skill's own Python scripts. There is
-- no @curl@, no HTTP client, no @systemctl restart@, no @npm@, no Palette
-- command, no @~\/.node-red@ path and no read of any credential — so six of the
-- skill's prohibitions are not rules this program obeys, they are commands it
-- does not contain. None of them points at @~\/src\/nix\/config\/ai@ and none is
-- composed with a shell.

-- | @node-red-admin flows get@ — the tab metadata.
--
-- /Source:/ @skills\/node-red\/SKILL.md@'s @## Supported admin boundary@, first
-- signature. The skill is explicit that this one is metadata only —
-- @{\"flows\":[{\"id\":\"a1b2c3d4\",\"label\":\"Office\"}]}@, one compact ASCII
-- JSON line — which is why it is the one flow read this program asks for before
-- it knows which tab it wants.
nodeRedFlowsGet :: Party 'IsTool
nodeRedFlowsGet = tool "nodered-tabs" `running` ("node-red-admin", ["flows", "get"])

-- | @node-red-admin flow get FLOW_ID@ — the selected tab's edit envelope.
--
-- /Source:/ the second signature. What comes back is
-- @{\"baseDigest\":\"sha256:…\",\"flow\":\<the complete selected flow\>}@ with
-- that exact key order, and the digest is the thing an edit must preserve: the
-- helper re-reads the flow and refuses a stale one before sending any update.
--
-- The id is 'flowIdOf', which is validated in Haskell — so this argv either
-- carries an id of the shape the helper accepts or carries a name nothing has.
nodeRedFlowGet :: Text -> Party 'IsTool
nodeRedFlowGet fid = tool "nodered-flow" `running` ("node-red-admin", ["flow", "get", fid])

-- | @node-red-admin flow put FLOW_ID@ — the update, with the envelope on standard
-- input.
--
-- /Source:/ the third signature, @node-red-admin flow put FLOW_ID \< flow.json@.
-- The redirection is the shell's; here the envelope is the question's words, and
-- "Agentic.Shell" writes those to the child's standard input — which is the same
-- interface with the shell removed.
--
-- __The only node in this program with write authority__, and it is an
-- @'Agentic.Workflow.act'@ because that is the only kind of statement
-- @Agentic.Acp.permissionByCode@ grants it to.
nodeRedFlowPut :: Text -> Party 'IsTool
nodeRedFlowPut fid = tool "nodered-put" `running` ("node-red-admin", ["flow", "put", fid])

-- | @sudo -u postgres psql -d nodered_events -c \<query\>@ — the event log.
--
-- /Source:/ @## Debugging workflow@'s first query, and pitfall 7: \"the node-red
-- postgres role is INSERT-only on @msg_events@\/@audit_events@. __Reads require
-- @sudo -u postgres psql -d nodered_events@__.\" So the @sudo@ is the skill's own
-- and is not this module reaching for privilege: it is the only way the log can be
-- read at all, and the role that writes it cannot.
--
-- The query is computed in Haskell from the node id — tier 1, in the printed argv
-- — so what is asked of the database is visible before it is asked, and no model
-- composes SQL here.
--
-- Asked at @text@: @psql@ exits @0@ on a successful query including one that
-- matched nothing, and prints its own row count, which is what
-- @'Workflows.Deciders.noRowsReturned'@ reads.
eventLog :: Text -> Party 'IsTool
eventLog nid =
  tool "nodered-events"
    `running` ( "sudo",
                [ "-u",
                  "postgres",
                  "psql",
                  "-d",
                  "nodered_events",
                  "-c",
                  "SELECT ts, msgid, node_name, hook, topic, payload FROM msg_events \
                  \WHERE node_id = '"
                    <> nid
                    <> "' AND ts > now() - INTERVAL '24 hours' ORDER BY ts"
                ]
              )

-- | @jq -r .data.entities[].entity_id \/var\/lib\/hass\/.storage\/core.entity_registry@
-- — the entity ids that actually exist.
--
-- /Source:/ @## Things to avoid offering@, last bullet: \"don't fabricate entity
-- IDs — verify against @\/var\/lib\/hass\/.storage\/core.entity_registry@ (jq
-- filtered by platform)\". The filter here is by /field/ rather than by platform,
-- because the list every lens needs is the ids: a flow references
-- @switch.pool@ and never a platform.
entityRegistry :: Party 'IsTool
entityRegistry =
  tool "nodered-entities"
    `running` ( "jq",
                [ "-r",
                  ".data.entities[].entity_id",
                  "/var/lib/hass/.storage/core.entity_registry"
                ]
              )

-- | @python3 \<scripts\>\/generate_uuid.py 16@ — fresh Node-RED node ids.
--
-- /Source:/ @## Available scripts@: \"@scripts\/generate_uuid.py [count]@ —
-- Node-RED 16-char hex UUIDs\". A receipt rather than a suggestion, and bound
-- __before__ the edit, so a new node's id is a value the run collected instead of
-- sixteen characters a model chose — which is how two nodes end up sharing one.
freshNodeIds :: Text -> Party 'IsTool
freshNodeIds dir = tool "nodered-uuids" `running` ("python3", [scriptIn dir "generate_uuid.py", "16"])

-- | @python3 \<scripts\>\/validate_flow.py \<file\>@ — the staged envelope, checked.
--
-- /Source:/ @## Available scripts@: \"@scripts\/validate_flow.py \<file\>@ —
-- full-flow or selected-flow-envelope JSON + wire integrity\", which is exactly
-- the shape the put requires.
--
-- Asked at @'Agentic.Workflow.Verdict'@, which is the one kind of ask that
-- survives a nonzero exit: a malformed envelope objects with the validator's own
-- first failing line, and a missing script is a __gap__ — it did not fail, it did
-- not run — which the skill's own rule covers: \"a helper failure is a blocker to
-- report, not permission to fall back to a lower-level interface.\"
validateFlow :: Text -> Text -> Party 'IsTool
validateFlow dir path =
  tool "nodered-validate" `running` ("python3", [scriptIn dir "validate_flow.py", path])

-- ---------------------------------------------------------------------------
-- The tier-1 readings of an invocation
-- ---------------------------------------------------------------------------

-- | The skill's own @FLOW_ID@ shape:
-- @[0-9a-f]{1,32}(?:\\.[0-9a-f]{1,32})?@, whole.
--
-- __Tier 1__ ("Workflows.Deciders"): ordinary Haskell over the invocation, zero
-- questions and zero paths. Lowercase hex only, because that is what the regex
-- says; one optional dotted part, because a subflow instance id has one; and both
-- parts non-empty and at most thirty-two characters.
validFlowId :: Text -> Bool
validFlowId t = case T.splitOn "." t of
  [a] -> hexRun a
  [a, b] -> hexRun a && hexRun b
  _ -> False
  where
    hexRun s =
      not (T.null s)
        && T.length s <= 32
        && T.all (\c -> (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f')) s

-- | The @flow@ input, validated.
--
-- An id that does not match becomes a name nothing has, so
-- @wf plan nodered --raw@ prints @node-red-admin flow get \<no valid flow id
-- given\>@ and this gate's own @--scripted@ run never reaches a command. That is
-- @'Workflows.Comments'@'s arrangement for a missing extractor, applied to an
-- identifier the helper would have refused with exit 2 a round trip later.
flowIdOf :: Text -> Text
flowIdOf raw
  | validFlowId trimmed = trimmed
  | otherwise = "<no valid flow id given>"
  where
    trimmed = T.strip raw

-- | The @node@ input, validated the same way.
--
-- A Node-RED node id has the same shape as a flow id — the skill's own
-- @generate_uuid.py@ produces \"16-char hex UUIDs\" — so the same predicate
-- decides it, and an unvalidated id never reaches the SQL. That is not a
-- convenience: the id is interpolated into a query, and a value that cannot be
-- anything but lowercase hex and one dot cannot be anything else either.
nodeIdOf :: Text -> Text
nodeIdOf raw
  | validFlowId trimmed = trimmed
  | otherwise = "0000000000000000"
  where
    trimmed = T.strip raw

-- | A script inside the skill's own @scripts@ directory.
--
-- __Tier 1__, and the directory is an input for @'Workflows.Comments'@'s reason:
-- the scripts ship with the skill, the skill's location is the operator's, and an
-- absent directory becomes a name nothing has rather than a guess at a path.
scriptIn :: Text -> Text -> Text
scriptIn dir name
  | T.null (T.strip dir) = "<no scripts directory given>/" <> name
  | otherwise = T.strip dir <> "/" <> name

-- | Where the edited envelope is staged before it is validated and put.
--
-- /Source:/ @## Supported admin boundary@: \"use a private mode-0700 temporary
-- directory with a cleanup trap for every returned document and
-- acknowledgement\". The path is derived from the flow id so two concurrent
-- sessions cannot stage over each other.
stagedAt :: Text -> Text
stagedAt fid = "/tmp/nodered-" <> fid <> "/flow.json"

-- ---------------------------------------------------------------------------
-- The house style
-- ---------------------------------------------------------------------------

-- | The facts about this host every question in the run carries.
--
-- /Source:/ @## Where things live@, reduced to the rows a flow author acts on,
-- plus the context-persistence row, which is the one that changes what code is
-- correct.
hostFacts :: Text
hostFacts =
  wfText
    [wf|
    This is Node-RED 4.1.10 on the owner's NixOS host. The facts that change what
    a correct answer is:

    - Flow administration goes through `node-red-admin` and nothing else. The
      transport is helper-owned and fixed; there is no URL, method or credential
      to supply, and none is available to this run.
    - Plugins installed through the Palette live in
      `/var/lib/node-red/node_modules/`; plugins installed through Nix come from
      the NixOS overlay, and the overlay is the right vehicle for a new one.
    - `settings.js` is generated from `/etc/nixos/config/node-red-settings.js`.
      The copy under `/nix/store` is read-only and is never edited.
    - The service is `node-red.service`, running as user `node-red`.
    - The event log is the PostgreSQL database `nodered_events`, with a Grafana
      dashboard over it.
    - Two config nodes are shared by everything: the Home Assistant server
      `86b277e82b069e9b`, and the chronos location node `f1c80506d19d3de2`.
    - CONTEXT PERSISTENCE IS ON BY DEFAULT: `contextStorage.default` is the
      local filesystem store, so every `flow.set`/`get`, `global.set`/`get` and
      `context.set`/`get` persists under `/var/lib/node-red/context/` with a
      30-second flush. No `'file'` argument is needed, and code that passes one
      is code written for a different host.
    - There is no `~/.node-red/` on this host. A path under it is a path that
      does not exist.|]

-- | The six lenses the skill's house style and pitfalls become.
--
-- /Source:/ @## House style@'s five subsections, @## Top pitfalls@'s fourteen
-- items and @## Plugin field guide@, distributed to the seat that owns each. The
-- distribution is the transplant: in the corpus a flow author holds all
-- twenty-odd facts at once, and here each is told to the one reader whose
-- question it changes.
--
-- __The roster is fixed at six, so house rule WR-1 has nothing to say here__: no
-- input shapes it, and @'Agentic.Workflow.panelText' []@ is unreachable.
houseRoster :: Roster
houseRoster =
  [ Lens
      { lensName = "wiring",
        lensOwns = "the direction of every gate's outputs, read from the wires that are there rather than inferred from a name",
        lensParty = reasoning (model "nodered-wiring"),
        lensBrief =
          wfText
            [wf|
            You own the ONE mistake this codebase makes most often, and the whole
            of your job is to read rather than to infer.

            `api-current-state` with `halt_if` has two outputs. OUTPUT 0 FIRES
            WHEN THE STATE MATCHES `halt_if`. OUTPUT 1 FIRES WHEN IT DOES NOT.
            The convention here is that a gate is named as a lowercase question --
            `anyone home?`, `office door closed?` -- and the question's "yes"
            answer routes to output 0. One output is wired to the continuation and
            the other is left empty.

            THE SAME `halt_if` STRING IS WIRED BOTH WAYS IN DIFFERENT PARTS OF
            THIS CODEBASE. So DO NOT GUESS THE DIRECTION from the node's name:
            read the existing wires in the tab you were given, say what they do,
            and only then say what the requested change means for them. The
            recorded failure is an Office HVAC misfire where
            `office door closed? halt_if="off"` wired to output 0 meant "fire when
            the door IS closed", which was the opposite of what the name suggested
            to a reader.

            For a comparison, a JSONata halt is supported and is often clearer:
            `halt_if_type: "jsonata"`, `halt_if: "3*24*60*60"`,
            `halt_if_compare: "gt"`.

            Also yours: `api-current-state`'s `outputProperties` value types. The
            valid ones are entityState, entityId, jsonata, str, num, bool, flow,
            global, msg, env, date, bin and eventData. `entity` IS NOT ONE -- for
            an attribute, use jsonata with `$entity().attributes.<key>`. And every
            working node here carries `override_topic: false`.

            Report what the wires do, what the change requires, and every place
            the requested change would depend on a direction you could not read.|]
      },
    Lens
      { lensName = "triggers",
        lensOwns = "every time trigger: chronos, the six-field cron, sun-relative offsets, and the two millisecond traps",
        lensParty = reasoning (model "nodered-triggers"),
        lensBrief =
          wfText
            [wf|
            You own the time triggers.

            Use `chronos-scheduler`, not a stock `inject` with a cron expression.
            The location config node is shared: `f1c80506d19d3de2`.

            CRONTAB VALUES HERE ARE SIX-FIELD CronosJS: second, minute, hour,
            day-of-month, month, day-of-week. `0 0 23 * * 2,4,6` is 23:00 on
            Tuesday, Thursday and Saturday. A five-field expression is a
            different schedule, and the day-of-week list belongs in the LAST
            field. This is the ninth pitfall on the list and it is still the
            easiest one to write.

            Sun-relative triggers: `type: "sun"`, `value` one of `sunsetStart`,
            `goldenHour`, `night` and the rest, plus a `random` offset between 15
            and 240 minutes so that many schedules do not all fire at once.

            Two traps that are both about `chronos-repeat`, and both are
            recorded because both have bitten:

            - ITS JSONATA INTERVAL IS IN MILLISECONDS. Returning `5` is five
              milliseconds. For seconds, `$number($env("Repeat")) * 1000`.
            - ITS "env" INTERVAL TYPE DOES NOT READ SUBFLOW ENVIRONMENT
              VARIABLES. Inside a subflow, switch the interval type to `jsonata`
              and use `$env("VarName")`.

            Scheduler names here are descriptive: `12:00-15:00`,
            `~Golden Hour till ~11 PM`, `Program A 23:00`, `Pool ON 09:00`.
            Inject buttons are time-shaped (`06:00 daily`, `Shut-off 23:15`) or
            state-shaped (`Lockdown`, `Turn on`).|]
      },
    Lens
      { lensName = "calls",
        lensOwns = "every service call's field shape, including the three fields a v7 node is invalid without",
        lensParty = reasoning (model "nodered-calls"),
        lensBrief =
          wfText
            [wf|
            You own the `api-call-service` nodes, and this is the seat where a
            missing field makes the editor flag a node invalid even though the
            runtime might still execute it.

            The field shapes, and they are not negotiable:

            - `entityId` IS ALWAYS AN ARRAY. One entity: `["switch.x"]`. Several:
              `["climate.a","climate.b"]`. A script or a scene: `[]`.
            - `dataType` IS ALWAYS `"jsonata"`. Never `"json"`.
            - `data` is either `""` for no extra payload, or compact JSONata:
              `{{"preset_mode": "eco"}`, `{{"temperature": $env("Temperature")}`,
              or a TTS payload built by concatenation.

            AND, ON v7, THREE MORE OR THE NODE IS INVALID: `action` spelled
            `"<domain>.<service>"` IN ADDITION to the legacy `domain` and
            `service` fields, plus `floorId: []`, `labelId: []` and
            `blockInputOverrides`. Omitting any of them shows as a red triangle in
            the editor.

            Action node names here are imperatives or device-verb-param:
            `Turn off HVAC`, `purifier on`, `upstairs heat_cool 78-82`,
            `bedroom heat off`, `tv_room set 78 heat`.

            Every entity id you use must appear in the entity list in the dossier
            you were given. If one you need is not there, say so and name it as
            unverified -- do not write it into a node as though it were checked.|]
      },
    Lens
      { lensName = "state",
        lensOwns = "state-change triggers, their dwell semantics, the v6 schema, and the sensors that are known to be unreliable",
        lensParty = reasoning (model "nodered-state"),
        lensBrief =
          wfText
            [wf|
            You own the state-change triggers and the debounces.

            `server-state-changed` ON v6 TAKES A NESTED SHAPE:
            `entities: {{entity: [...], substring: [...], regex: [...]}`. NOT the
            flat `entityId`/`entityIdType` of older versions. The wrong schema
            raises a TypeError on startup -- "cannot read properties of undefined
            (reading 'entity')" -- once per affected node. Always emit the nested
            form.

            `for: N` IS ENFORCED ON THE HOME ASSISTANT SIDE: the entity must STAY
            in the matching state for that long. A flickery sensor resets the
            dwell timer continuously and the trigger never fires. Two recorded
            consequences: `binary_sensor.johns_mac_studio_active` is unreliable
            for presence -- prefer `sensor.johns_mac_studio_active_camera` or
            `_audio_output` compared against `Inactive`.

            `join-wait` RESET SEMANTICS ARE TWO DIFFERENT THINGS AND MUST NOT BE
            CONFLATED: `msg.reset = true` silently DRAINS the queue;
            `msg.complete` drains it to the EXPIRED output. The canonical use of
            this node here is the Office tab's `confirmed absent`.

            Trigger names here carry their duration: `mac inactive 15min`,
            `TV on 2min`, `Nasim leaves 15min`, `out of office 15min`.

            Every entity id you rely on must appear in the entity list in the
            dossier. Name any that does not as unverified.|]
      },
    Lens
      { lensName = "naming",
        lensOwns = "the naming conventions, the layout bands, and the subflow status pattern",
        lensParty = broad (model "nodered-naming"),
        lensBrief =
          wfText
            [wf|
            You own what the tab will look like to the person who opens it in six
            months, which is the owner.

            NAMES. Triggers carry their `for:` duration. Gates are lowercase
            questions ending in a question mark: `anyone home?`,
            `office door closed?`, `rain delay?`, `vacuum cleaning?`. Actions are
            imperatives or device-verb-param. Inject buttons are time-shaped or
            state-shaped. Schedulers are descriptive.

            LAYOUT. Vertical bands, one per logical section, stacked top to bottom
            with roughly 100 to 220 pixels between them. Each band is anchored by
            a comment-as-header at x about 150 to 200 and y at the band's first
            row. Flow runs left to right within a band. The comment uses
            sentence-headline style with em-dashes or ellipses:
            `When I leave the computer…`, `Pre-cool upstairs for Institute
            Nights`, `B-Hyve Program A — Sac County Odd Addr (Tu/Th/Sa)`.

            SUBFLOW STATUS. A subflow's success branch goes through a small
            function that emits a status object to the status port:

              const stamp = new Date().toLocaleString('en-US', {{
                month: 'short', day: 'numeric',
                hour: 'numeric', minute: '2-digit', hour12: true
              });
              msg.payload = {{ fill: 'green', shape: 'dot',
                              text: `${{env.get('Action')} called : ${{stamp}` };
              return msg;

            The runtime timezone is local, so there is no offset to hardcode. The
            production example is the `Act until observed` subflow.

            Report the names and the coordinates the change should use, and flag
            anything in the existing tab whose name no longer matches what it
            does -- that is the cheapest finding in this whole review and nobody
            else is looking for it.|]
      },
    Lens
      { lensName = "events",
        lensOwns = "what the event log says actually happened, and what its limits are",
        lensParty = broad (model "nodered-events"),
        lensBrief =
          wfText
            [wf|
            You own the evidence. The event log in your dossier is the output of a
            query against `msg_events` for the node this run was given, over the
            last twenty-four hours, `onSend` and `onComplete` for every node.

            Read it, and answer in this order:

            1. Did the node fire at all in the window? If there are no rows, the
               problem is UPSTREAM of it -- something did not reach it -- and the
               next thing to look at is whatever feeds it, not the node itself.
            2. If there are rows, walk them by `msgid`: the first row for a msgid
               is the trigger and each later `onSend` is a hop. Find the hop where
               a predicate evaluated the wrong way, and quote the payload at that
               hop.
            3. Say what the log CANNOT tell you. Two limits are documented and
               both matter here: `msg.payload` is truncated at 4096 UTF-8 bytes,
               with anything larger stored as a truncation marker plus a preview
               and the original byte count; and the node-red role is INSERT-only,
               so this run reads the log through the postgres superuser and cannot
               modify or backfill it.

            Do not propose mocking this database. The house rule is to use the
            real PostgreSQL, and a mocked event log is a test of the mock.|]
      }
  ]

-- ---------------------------------------------------------------------------
-- The rubrics, transplanted
-- ---------------------------------------------------------------------------

-- | The closing line every house-style lens is given.
--
-- /Source:/ @## Things to avoid offering@ — the two bullets that are /judgments/
-- rather than absences — plus the sensitivity rule from @## Supported admin
-- boundary@, and the request itself.
--
-- __The other four \"avoid\" bullets are not here, because they are commands this
-- module does not contain.__ There is no Palette install, no @~\/.node-red@ path,
-- no direct flow-file access and no network client anywhere in the argv block
-- above, so \"don't offer them\" is not something a question has to say.
houseClosing :: Text -> Text
houseClosing request =
  wfText
    [wf|
    What this session is for:

    {request}

    Three standing constraints on your answer.

    THE FLOW DOCUMENT IS SENSITIVE. It is authorized output, not public data, and
    it may contain private configuration. Quote the specific nodes, fields and
    wires your finding is about; do not reproduce the whole flow, and do not
    restate configuration your finding does not turn on.

    DO NOT FABRICATE AN ENTITY ID. The entity list in your dossier is the output
    of a query against this host's own registry. An id that is not in it is
    unverified, and saying so is a finding rather than a gap.

    PRESERVE WHAT YOU WERE NOT ASKED ABOUT. Node ids, coordinates, wires and
    unrelated fields stay exactly as they are; only the requested fields on the
    selected tab change. A reformatted tab is a diff nobody can review.

    Report on your own area and nothing else. Your answer is one block of a
    document whose other blocks are your siblings', each fenced under its own
    name: do not answer theirs, and do not summarise the whole.|]

-- | What the editing turn is told.
--
-- /Source:/ @## Supported admin boundary@'s envelope contract and its
-- \"fetch-edit-put-refetch\" procedure, plus @## Things to avoid offering@'s
-- \"don't ask the user to re-import a tab for a small edit\".
editBrief :: Text
editBrief =
  wfText
    [wf|
    Produce the complete edit envelope to be put back. Your answer is fed
    straight to `node-red-admin flow put` on standard input, so it must be
    exactly the envelope and nothing else -- no commentary, no fences, no
    explanation above it.

    The envelope is two keys, in this order:

      {{"baseDigest":"sha256:<the 64 hex characters you were given, unchanged>",
       "flow":<the complete selected flow, with your edits>}

    Five rules, and four of them are about not changing things.

    1. PRESERVE `baseDigest` EXACTLY. The helper re-reads the flow and refuses a
       stale digest before sending any update, which is what protects a
       concurrent editor. A digest you recomputed or omitted is a rejected put at
       best.
    2. PRESERVE EVERY NODE ID, EVERY COORDINATE, EVERY WIRE AND EVERY FIELD YOU
       WERE NOT ASKED TO CHANGE. Update only the requested fields on this tab.
    3. `flow.id` must equal the flow id this envelope is being put to, `nodes`
       must be an array, and `configs` -- if present -- must be an array.
    4. USE THE NODE IDS FROM THE DOSSIER for any node you add. They were
       generated by this run. Do not invent a hex string: a collision with an
       existing id is a corruption that will look like a wiring bug.
    5. Emit compact JSON on a single line, ASCII, exactly as the helper's own
       output is.

    You have the reviewers' blocks above. Where two of them disagree about a
    wire's direction, follow the one that quoted the existing wires: the
    convention is read from the tab and not from the node's name.|]

-- | What the staging act is told.
stageBrief :: Text -> Text
stageBrief path =
  wfText
    [wf|
    Stage the envelope below at `{path}`, in a directory created with mode 0700,
    and nowhere else. This is the working copy the validator reads and the put
    sends; it holds an authorized but sensitive document, which is why the
    directory is private and why it is removed when this work is finished.

    Write the envelope verbatim. Do not reformat it, do not pretty-print it, and
    do not add a trailing comment: the bytes you write are the bytes that are
    validated, and a validator that passed something other than what is put has
    checked nothing.

    Then reply DONE with the path you wrote.|]

-- | What the tabs receipt is introduced as.
tabsBrief :: Text
tabsBrief =
  wfText
    [wf|
    The flow tabs on this host, as `node-red-admin flows get` wrote them: one
    compact JSON line of ids and labels, and metadata only. A receipt -- whatever
    the command printed is the answer.|]

-- | What the envelope receipt is introduced as.
envelopeBrief :: Text
envelopeBrief =
  wfText
    [wf|
    The selected tab's edit envelope, as `node-red-admin flow get` wrote it: the
    base digest and the complete flow, in that key order. A receipt, and the
    single source of truth about what is wired to what -- where this document and
    anyone's reading of a node's name disagree, this document is what is
    deployed.|]

-- | What the uuid receipt is introduced as.
uuidBrief :: Text
uuidBrief =
  wfText
    [wf|
    Sixteen fresh Node-RED node ids, generated by this run. A receipt. Any node
    added by this session takes an id from here.|]

-- | What the event-log receipt is introduced as.
eventBrief :: Text
eventBrief =
  wfText
    [wf|
    The event log for the node this run was given, over the last twenty-four
    hours. A receipt: these are rows the runtime wrote as messages passed
    through, and they are the only evidence in this run about what actually
    happened rather than about what the flow says should happen.|]

-- | What the entity receipt is introduced as.
entityBrief :: Text
entityBrief =
  wfText
    [wf|
    Every entity id in this host's Home Assistant registry. A receipt. An entity
    id that is not in this list does not exist on this host, whatever it looks
    like.|]

-- | What the validator is asked.
validateBrief :: Text
validateBrief =
  wfText
    [wf|
    The staged envelope, checked for JSON validity, envelope shape and wire
    integrity before anything is sent. A pass means the document is
    structurally what a put requires; a failure carries the validator's own first
    failing line; and a missing script is neither -- it did not fail, it did not
    run, and a helper failure is a blocker to report rather than permission to
    fall back to a lower-level interface.|]

-- | What the put is told.
putBrief :: Text
putBrief =
  wfText
    [wf|
    Put this envelope back to the selected tab. Success is exactly
    `{{"ok":true,"id":"<the flow id>"}` on one line.

    The envelope goes on standard input, unchanged. If the helper refuses -- a
    stale digest, an id mismatch, a shape it will not accept -- that refusal is
    the answer, and it is reported rather than worked around: there is no other
    interface to reach for.

    Then reply DONE.|]

-- | What the verifying refetch is introduced as.
verifyBrief :: Text
verifyBrief =
  wfText
    [wf|
    The selected tab, refetched after the put. A receipt, and the last step of
    this host's canonical procedure -- fetch, edit, put, refetch -- so that what
    is deployed is confirmed from the runtime rather than from an
    acknowledgement.|]

-- ---------------------------------------------------------------------------
-- The provenance lines
-- ---------------------------------------------------------------------------

-- | The arm where the change was put, and the node had fired in the window.
putActiveNote :: Text
putActiveNote =
  "Outcome: EDITED AND PUT, WITH HISTORY. The tab was fetched, six reviewers read \
  \the same envelope, the edit was staged and validated, the helper accepted the \
  \put, and the tab was refetched to confirm what is deployed. The event log for \
  \the node in question HAS rows in the last twenty-four hours, so the wiring \
  \question was answered against messages that actually passed through it rather \
  \than against a reading of the flow. Report what changed, field by field, and \
  \name the hop in the log where the old behaviour is visible."

-- | The arm where the change was put, and the node had never fired.
putSilentNote :: Text
putSilentNote =
  "Outcome: EDITED AND PUT, AND THE NODE HAD NEVER FIRED. The put was accepted \
  \and confirmed by a refetch. But the event log returned NO ROWS for this node in \
  \the last twenty-four hours, and this host's own debugging rule reads that \
  \exactly one way: zero rows means the problem is UPSTREAM -- something never \
  \reached the node -- and not in the node itself. So report the change that was \
  \made AND report that it may well not be the fix: name what feeds this node, and \
  \say that the next thing to look at is whether the upstream trigger fires at \
  \all. A node edited because it did the wrong thing, when it never did anything, \
  \is a change that will look like it failed."

-- | The arm where the validator objected.
invalidNote :: Text
invalidNote =
  "Outcome: NOT PUT -- THE STAGED ENVELOPE DID NOT VALIDATE. The edit was staged \
  \and the validator objected; its own first failing line is the closing evidence \
  \below. NOTHING WAS SENT to the runtime: the deployed flow is exactly what it \
  \was before this run. Report the failing line verbatim and name what in the \
  \envelope it is about -- an invalid JSON document, an envelope missing a key, a \
  \wire referring to a node id that is not in `nodes`. The reviewers' blocks are \
  \still worth reading and are below: the analysis stands even though the edit did \
  \not."

-- | The arm where the validator did not run.
noValidatorNote :: Text
noValidatorNote =
  "Outcome: NOT PUT -- THE VALIDATOR DID NOT RUN. The validation script was \
  \missing, or it outran its clock: it did not fail, it did not run. This host's \
  \rule for that case is explicit -- a helper failure is a blocker to report, not \
  \permission to fall back to a lower-level interface -- so nothing was sent and \
  \no other route was tried. Report which script was invoked and with what argv, \
  \and say that this is a fact about the run's tooling and not about the flow. The \
  \edit and the six review blocks are below and are unaffected; a second run with \
  \the scripts directory named correctly will put the same envelope."

-- ---------------------------------------------------------------------------
-- The function
-- ---------------------------------------------------------------------------

-- | What the report is written through.
noderedReportBrief :: Text
noderedReportBrief =
  wfText
    [wf|
    Write the report for a Node-RED session on this host. It is read by the owner,
    who will look at the tab in the editor next.

    Open with the provenance line you were given, verbatim, on its own line. It is
    the run's own account of what was deployed and what was not, and it is not
    yours to soften -- in particular, if it says nothing was put, do not describe
    the change as made.

    Then, from the work below and nothing else:

    - what changed, field by field, on which node, with the node's name and id;
    - what the reviewers found -- the wiring direction they read from the
      existing wires especially, because that is the fact this host's flows go
      wrong on most often;
    - what the event log said, and what follows from it;
    - any entity id used or proposed that is NOT in the registry receipt, named as
      unverified;
    - what to look at in the editor to confirm the change, by tab and band.

    Two things you must not write. Do not reproduce the flow document: it is
    authorized but sensitive output, it may contain private configuration, and the
    fields your report turns on are enough. And do not report a result for a
    command that is not in the work below -- if it did not run, nothing follows
    from it.

    Then reply DONE.|]

-- | One act, four provenance lines.
--
-- Three parameters, in the order the body reads them: the provenance first, for
-- "Workflows.Report"'s reason; then the review document; then the closing evidence,
-- which is a verdict on every arm — the validator's answer, which on two arms is
-- its own failing line and on the others is its approval.
noderedReportFn :: Fn '[ 'CodeText, 'CodeText, 'CodeVerdict] 'CodeAck
noderedReportFn =
  function
    "nodered.report"
    ( takes @"provenance" Text
        . takes @"findings" Text
        . takes @"evidence" Verdict
        $ noParams
    )
    \provenance findings evidence -> W.do
      act reporter [wf|
          {writing}

          Provenance:

          {provenance}

          What the reviewers and the edit produced:

          {findings}

          What the validator said:

          {evidence}

          Write the report, then reply DONE.|]
      done
  where
    writing = noderedReportBrief

-- | The table 'noderedProgram' hands @'Agentic.Workflow.defining'@.
noderedTable :: [SomeFn]
noderedTable = [SomeFn noderedReportFn]

-- ---------------------------------------------------------------------------
-- The program
-- ---------------------------------------------------------------------------

-- | Fetch, review, edit, stage, validate — and only then put.
--
-- Five inputs. @request@ is what the session is for; @flow@ is the tab's
-- @FLOW_ID@, validated in Haskell before the program exists; @node@ is the node
-- whose history is being explained, validated the same way because it reaches a
-- SQL string; @scripts@ is where the skill's own Python lives; @references@ is its
-- six reference files as an @--input-file@.
--
-- The shape, top to bottom: collect the four receipts — the tab list, sixteen
-- fresh node ids, the event log for the node in question, and every entity id this
-- host actually has; fetch the selected tab's envelope and bind it __once__; read
-- the event log's row count for nothing; fan out over the six house-style seats,
-- every one of them reading the same envelope and the same receipts; produce the
-- envelope to be put; stage it in a private directory; validate the staged bytes;
-- and put only in the arm where the validator approved, then refetch to confirm.
--
-- __Four endings, four provenance lines, one__ 'noderedReportFn'. Two of the four
-- put nothing, and each is more useful than a failed put would have been: an
-- envelope that does not validate names its own defect, and a validator that did
-- not run is a fact about the tooling rather than about the flow.
noderedProgram :: Parameterized
noderedProgram =
  taking (input "request" :> input "flow" :> input "node" :> input "scripts" :> input "references" :> noInputs)
    \request flowArg nodeArg scriptsArg references ->
      -- Tier 1, five times: the flow id and the node id against the skill's own
      -- regex, the two script paths, and the staging path derived from the flow
      -- id. All five are in the printed argv, and `wf plan --raw` shows them
      -- before a command runs.
      let fid = flowIdOf flowArg
          nid = nodeIdOf nodeArg
          staged = stagedAt fid
          staging = stageBrief staged
          closing = houseClosing request
       in defining noderedTable W.do
            -- The four receipts, in one fold. None of them is a judgment and none
            -- of them is a write.
            dossier <-
              panelText
                [ ("tabs", ask nodeRedFlowsGet [wf|{tabbing}|]),
                  ("node-ids", ask (freshNodeIds scriptsArg) [wf|{uuiding}|]),
                  ("events", ask (eventLog nid) [wf|{eventing}|]),
                  ("entities", ask entityRegistry [wf|{entitying}|])
                ]

            -- The selected tab, bound ONCE and spliced into all six seats.
            envelope <- ask (nodeRedFlowGet fid) [wf|{enveloping}|]

            -- "Zero rows -> upstream issue", for zero questions.
            silent <- tested noRowsReturned dossier

            found <- panelText (zip (lensNames houseRoster) (withEvidence houseRoster closing envelope dossier))

            edited <- ask (reasoning (model "nodered-edit")) [wf|
                {editing}

                {facts}

                This host's own reference material, which is authoritative
                wherever it and the briefs above disagree:

                {references}

                The tab as it stands:

                {envelope}

                What the reviewers said:

                {found}|]

            -- The private working copy the validator reads and the put sends.
            act (tool "nodered-stage") [wf|
                {staging}

                {edited}|]

            validated <- ask (validateFlow scriptsArg staged) [wf|{validating}|] `answering` Verdict

            caseVerdict
              validated
              -- Approved: the staged bytes are a well-formed envelope. Put, then
              -- refetch, which is the last step of this host's own procedure.
              ( W.do
                  act (nodeRedFlowPut fid) [wf|
                      {putting}

                      {edited}|]

                  confirmed <- ask (nodeRedFlowGet fid) [wf|{verifying}|]

                  if silent
                    then W.do
                      call_ noderedReportFn (arg putSilentNote :> arg confirmed :> arg validated :> noArgs)
                      stop
                    else W.do
                      call_ noderedReportFn (arg putActiveNote :> arg confirmed :> arg validated :> noArgs)
                      stop
              )
              -- Objected: the validator's own failing line, and nothing sent.
              ( W.do
                  call_ noderedReportFn (arg invalidNote :> arg edited :> arg validated :> noArgs)
                  stop
              )
              -- A gap: the script did not run. Not a failure of the flow.
              ( W.do
                  call_ noderedReportFn (arg noValidatorNote :> arg edited :> arg validated :> noArgs)
                  stop
              )
  where
    tabbing = tabsBrief
    uuiding = uuidBrief
    eventing = eventBrief
    entitying = entityBrief
    enveloping = envelopeBrief
    editing = editBrief
    facts = hostFacts
    validating = validateBrief
    putting = putBrief
    verifying = verifyBrief

-- $staging
--
-- 'stageBrief' is the one brief in this module that is a /function/ of the
-- invocation rather than a constant, and it is bound in the @let@ above rather
-- than in the @where@ for that reason: the act has to name the path it writes,
-- and the path is derived from the flow id. It is not a key in 'noderedScript',
-- because an act's scripted default is @DONE@ and nothing in the program reads
-- its answer — so a key that changed with the invocation would buy nothing and
-- would be one more thing to keep true.

-- ---------------------------------------------------------------------------
-- The registry's two other columns
-- ---------------------------------------------------------------------------

-- | The one line @wf list@ prints beside this row.
noderedDoc :: Text
noderedDoc =
  "node-red/SKILL.md: the three-signature admin boundary as argv, six house-style seats over one fetched tab, and a put only through a validator"

-- | The canned replies a @--scripted@ run answers from, keyed by prefix.
--
-- __The keys are the defines themselves__, so each is a prefix of the rendered
-- prompt by construction: every receipt's question opens with its own brief, each
-- seat's with its own @'Workflows.Panels.lensBrief'@ (derived from the very roster
-- the panel is built from), the edit's with 'editBrief' and the validator's with
-- 'validateBrief'.
--
-- __No command runs in a scripted rehearsal, and two things make that visible
-- rather than merely true.__ Every argv in this row is answered from this table;
-- and at the empty invocation the two identifiers are 'flowIdOf' and 'nodeIdOf''s
-- refusals, so @wf plan nodered --raw@ prints
-- @node-red-admin flow get \<no valid flow id given\>@ — an operator who forgot the
-- flag sees the omission in the plan rather than in an exit-2 from the helper.
--
-- __The event-log row is the load-bearing one.__ It is written __without__ a
-- @(0 rows)@ footer, so @'Workflows.Deciders.noRowsReturned'@ says no and the
-- rehearsal walks the with-history ending. Changing the footer to @(0 rows)@
-- rehearses the upstream-issue ending, which is the more interesting of the two
-- and the one the skill's debugging workflow starts from. Both exit 0.
--
-- __The validator's row is @APPROVE@ and is written rather than defaulted__, for
-- @'Workflows.Comments.commentsScript'@'s reason: a table that relies on
-- @'Agentic.Exec.scriptedDefault'@ cannot be edited into the other two arms in one
-- line. An @OBJECTION:@ here reaches the not-validated ending and puts nothing.
noderedScript :: [(Text, Text)]
noderedScript =
  [ (tabsBrief, tabsAnswer),
    (uuidBrief, uuidAnswer),
    (eventBrief, eventAnswer),
    (entityBrief, entityAnswer),
    (envelopeBrief, envelopeAnswer),
    (editBrief, envelopeAnswer),
    (validateBrief, "APPROVE")
  ]
    <> [(lensBrief l, seatAnswer (lensName l)) | l <- houseRoster]
  where
    tabsAnswer =
      "{\"flows\":[{\"id\":\"a1b2c3d4e5f60718\",\"label\":\"Office\"},\
      \{\"id\":\"b2c3d4e5f6071829\",\"label\":\"Pool Time\"}]}"

    uuidAnswer =
      "0f1e2d3c4b5a6978\n\
      \1a2b3c4d5e6f7081\n\
      \2b3c4d5e6f708192"

    -- Deliberately does NOT print `(0 rows)`: the rehearsal walks the
    -- with-history ending, and the upstream-issue ending is one line away.
    eventAnswer =
      "             ts             |  msgid   |     node_name      |   hook   \n\
      \----------------------------+----------+--------------------+----------\n\
      \ 2026-08-19 22:00:01.114+00 | 7f3a2b10 | office door closed? | onSend\n\
      \ 2026-08-19 22:00:01.140+00 | 7f3a2b10 | Turn off HVAC       | onSend\n\
      \(2 rows)"

    entityAnswer =
      "binary_sensor.office_door_sensor_p2_office_door\n\
      \climate.home_office\n\
      \person.john_wiegley\n\
      \sensor.johns_mac_studio_active_camera\n\
      \switch.pool"

    envelopeAnswer =
      "{\"baseDigest\":\"sha256:\
      \0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef\",\
      \\"flow\":{\"id\":\"a1b2c3d4e5f60718\",\"label\":\"Office\",\"nodes\":[],\
      \\"configs\":[]}}"

    seatAnswer n =
      "On the "
        <> n
        <> " area: the existing wiring routes `office door closed?` output 0 to \
           \`Turn off HVAC`, so the gate fires when the door IS closed, which is \
           \what the band's comment says it should do. Nothing in the requested \
           \change depends on a direction I could not read from the envelope."
