-- |
-- Module      : Workflows.Service
-- Description : A service on the NixOS host — nine obligations as nine calls, a
--               gate no run can pass on its own, and a removal that generates a
--               script it cannot run.
--
-- == The map: old Markdown -> new program
--
-- +-----------------------------------------+--------------------------------------------------------------+
-- | @~\/src\/nix\/config\/ai@               | here                                                         |
-- +=========================================+==============================================================+
-- | @commands\/install-service.md@ items    | 'obligations' — nine of the ten, each a @call_@ of __one__    |
-- | 1–9                                     | 'obligationFn'                                               |
-- +-----------------------------------------+--------------------------------------------------------------+
-- | its item 10 (\"test to ensure the       | @'Workflows.Evidence.systemctlStatus'@ and                     |
-- | newly installed service is working\")   | @'Workflows.Evidence.httpHealth'@ — two receipts and three     |
-- |                                         | endings                                                       |
-- +-----------------------------------------+--------------------------------------------------------------+
-- | its two capital-letter pleas            | @'Workflows.Evidence.consentFile'@, and                        |
-- |                                         | @'Agentic.Workflow.ask_' 'Workflows.Parties.owner'@ as a      |
-- |                                         | terminal the run cannot pass                                  |
-- +-----------------------------------------+--------------------------------------------------------------+
-- | its database preference                 | 'housePreferences'                                            |
-- +-----------------------------------------+--------------------------------------------------------------+
-- | @commands\/remove-service.md@           | rung 'Remove' — 'removalRoster' at @text@, and one @act@ that |
-- |                                         | writes a script rather than running one                       |
-- +-----------------------------------------+--------------------------------------------------------------+
-- | @skills\/nixos\/SKILL.md@               | "Workflows.Nix"'s reading of it: the driver as the gate, and  |
-- |                                         | three prohibitions that are absences                          |
-- +-----------------------------------------+--------------------------------------------------------------+
--
-- The Markdown was read as __data__. Nothing in @~\/src\/nix\/config\/ai@ is
-- modified by this module, and no party in it points at that tree.
--
-- == The leveling-up, item by item
--
--   1. __The two capital-letter pleas become a gate the run cannot pass.__
--      @install-service.md@ shouts twice — \"DO NOT try to generate the
--      certificate yourself, but ask me\" and \"never reveal secrets in this
--      chat; ask me to create and install them for you\" — and a shout is a thing
--      a tired run does anyway. @doc\/design.md@ §7.2 row 29 asks for
--      @'Agentic.Workflow.ask_' ('Agentic.Workflow.person' \"owner\")@ terminals,
--      and that is the arm below; what /decides/ that arm is
--      @'Workflows.Evidence.consentFile'@, whose own haddock names this command,
--      and the reason it is a file rather than a question is worth stating
--      plainly: __a person's question is not a real gate when unattended.__
--      @--scripted@ answers a flag @yes@ and an unwatched run reaches nobody, so a
--      certificate that must come from a human is gated on a file the program is
--      forbidden to create. Nothing in "Workflows.Evidence" can write it.
--
--   2. __Nine obligations, nine calls, one body.__ The corpus's numbered list is
--      worked down by a reader who is also doing the work, and there is no way to
--      tell from the output whether item 6 happened. Here each is
--      @call_ 'obligationFn'@ with the obligation as an /argument/: nine nodes in
--      the elaborated program, in dependency order, each priced at the callee's
--      own body — so @wf plan service-install --raw@ lists all nine before the
--      first one is attempted, and an obligation nobody performed is a node whose
--      receipt is missing rather than a bullet somebody stopped at.
--
--   3. __Item 10 is two receipts and three endings.__ \"Test to ensure the newly
--      installed service is working before you finish your work\" is, in Markdown,
--      the last bullet — the one that gets the least attention precisely because
--      everything else already happened. Here it is
--      @systemctl status@ and @curl@, each an exit code no model authored, and the
--      three states they distinguish are the ones an operator actually needs:
--      __the unit is up and the vhost answers__, __the unit is up and the vhost
--      does not__ (which is nginx, or the certificate, or the port — a different
--      problem entirely), and __the unit is not up__.
--
--   4. __\"Whichever is best for my configuration\" is a question, once, at the
--      top.__ The command offers a native NixOS service or a rootless quadlet
--      under home-manager and leaves the choice implicit in whatever the reader
--      does. Here it is one ask whose answer is bound and spliced into all nine
--      obligations, so the nine cannot disagree about what is being installed —
--      which is the failure mode of a list worked item by item.
--
--   5. __The removal is the tree's exemplar of structural read-only.__
--      @remove-service.md@'s inversion — \"do not perform this removal directly,
--      rather generate a script that I can run at a later time\" — is a rule in
--      Markdown and a /type/ here, and @doc\/design.md@ §7.2 row 51 names it as
--      the exemplar: every discovery question in 'removalRoster' is asked at
--      @text@, and @Agentic.Acp.permissionByCode@ grants write authority only to
--      an act at @receipt@. So the twelve questions that find out what to remove
--      __cannot remove anything__, whatever they are told, and the one act writes
--      a script. The corpus's \"do not perform this removal directly\" is not
--      obeyed here; it is unavailable.
--
--   6. __The Nix edits the removal /is/ allowed are a separate authority.__
--      @remove-service.md@ says \"you are entirely free to remove declarations
--      from the Nix files, but leave cleanup of the SOPS secrets to me\", which is
--      a permission and an exception in one sentence. The permission is the single
--      @act@; the exception needs nothing, because there is no @sops@ argv
--      anywhere in this tree and the script the act writes is told to leave the
--      secrets to the operator by name.
--
-- == Three honest notes
--
-- __Why @service-install@ and @service-remove@, and no bare @service@.__ The
-- naming rule is family-first with the owner's own word as the suffix, and \"where
-- a family has a default rung, the bare family name is that rung\". This family
-- has no default rung: install and remove are opposites rather than two weights of
-- one thing, and a bare @service@ would have to pick one of them to be the
-- ordinary case. On a row whose ordinary case would then be reachable by typing
-- four fewer characters, and whose other case removes a service and its data, that
-- is not a saving worth having.
--
-- __'Workflows.Nix.hostFlags' is imported and not copied.__ This is the tree's
-- first import of one program module by another, and it is deliberate: the VPS
-- constraint is one fact about one machine, and two modules that both build on
-- that host must not each carry their own reading of it. The alternative was to
-- copy nine characters of argv and a @T.isInfixOf@ — which is precisely the
-- duplication "Workflows.Evidence" exists to prevent, one level up. If a third
-- module ever wants it, it belongs beside
-- @'Workflows.Evidence.nixosBuild'@ instead, and that move is one line.
--
-- __The removal's script is not run, and this row cannot check that it works.__
-- That is the corpus's own design and it is kept: what the operator gets is a
-- script to read before running. What the row /can/ check is that the tree still
-- builds after the Nix declarations came out, and that is the gate — so a removal
-- that broke the configuration is caught here, and a removal whose script is wrong
-- is caught by the operator reading it. The two halves of that sentence are
-- different guarantees, and the report is told to keep them apart.
{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QualifiedDo #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE RebindableSyntax #-}
{-# LANGUAGE TypeApplications #-}

module Workflows.Service
  ( -- * The two operations
    ServiceOp (..),
    serviceName,
    serviceDoc,
    serviceHelp,

    -- * The programs
    serviceProgram,
    serviceScript,

    -- * The nine obligations, and the twelve surfaces
    obligations,
    removalRoster,
    removalSurfaces,

    -- * The rubrics, transplanted
    housePreferences,
    secretsDiscipline,

    -- * The functions
    obligationFn,
    serviceReportFn,
    serviceTable,

    -- * The tier-1 readings of an invocation
    consentPath,
    unitName,
    healthUrl,
  )
where

import qualified Agentic.Workflow.Do as W
import Data.String (fromString)
import Data.Text (Text)
import qualified Data.Text as T
import Workflows.Nix (hostFlags)
import Workflows.Prelude
import Prelude

-- ---------------------------------------------------------------------------
-- The two operations
-- ---------------------------------------------------------------------------

-- | Install, or remove. Two commands, two rows, one module.
data ServiceOp
  = -- | @commands\/install-service.md@
    Install
  | -- | @commands\/remove-service.md@
    Remove

-- | The name the operator types. See the module header for why there is no bare
-- @service@ row.
serviceName :: ServiceOp -> Text
serviceName Install = "service-install"
serviceName Remove = "service-remove"

-- | The one line @wf list@ prints beside each row.
serviceDoc :: ServiceOp -> Text
serviceDoc Install =
  "install-service.md: nine obligations as nine calls behind a consent file the run cannot create, then two health receipts"
serviceDoc Remove =
  "remove-service.md: twelve read-only discovery questions, then one act that writes a script rather than running one"

-- | The page @wf help \<op\>@ prints under the computed header
-- ('Agentic.Cli.rowHelp').
--
-- One text at two settings. The pair shares three inputs and one machine, so
-- the inputs paragraph is written once; what differs is the opening, /why/ each
-- wants a watched pane — one has a person's gate and the other does not — and
-- the caveat that names what the run will and will not do to the host.
--
-- __The consent file is the paragraph that matters__, and it is @Install@'s
-- alone: the run cannot create it, so an operator who has not put it there gets
-- the cheapest ending and nothing on the machine changed. Saying so here is
-- what stops that ending being read as a failure.
--
-- __It states no price.__ The header above it carries the numbers off the same
-- 'Agentic.Plan.Facts' @wf list@ publishes.
serviceHelp :: ServiceOp -> Text
serviceHelp o =
  [wft|
  {opening}

  **Inputs.**

  * `service` — the service's name, and it names **both** the consent file and
    the systemd unit, so one flag is two arguments. An empty one names
    `.consent/service-unnamed`, which is exactly what a plan should print for an
    operator who forgot the flag — and what a run against it will fail to find.
  * `domain` — the virtual host, which names the health URL the run checks
    afterwards. Empty is legal and leaves the health check pointed at nothing
    useful, which the plan prints.
  * `host` — the machine the declarations belong to.

  **Transport.** {transport}
  {paneNote}

  ```sh
  wf run {row} --session "$PANE" --require-pinned \
     --input-arg service=grafana --input-arg domain=grafana.example.com \
     --input-arg host=vulcan
  ```

  **Rehearsal.** All three inputs named empty, every question answered from the
  row's own canned table, consulting nobody:

  ```sh
  wf run {row} --scripted --input-arg service= --input-arg domain= --input-arg host=
  ```

  **Caveats.**

  {caveat}
  * Both rows edit a host's declarations, which is to say they edit *your
    configuration repository* and not the running machine directly. What
    switches the machine is still yours to run, which is the boundary this pair
    keeps on purpose.
  |]
  where
    row = serviceName o

    opening = case o of
      Install ->
        [wft|
        `commands/install-service.md` as a program: nine obligations as nine
        calls behind a consent file **the run cannot create**, and then two
        health receipts. The consent gate is a person's decision expressed as a
        file on disk, so a run that reaches it without one ends at your desk.|]
      Remove ->
        [wft|
        `commands/remove-service.md` as a program: twelve read-only discovery
        questions — what the unit is, what it owns, what points at it — and then
        exactly one act, which **writes a removal script rather than running
        one**. The asymmetry with installing is deliberate: taking a service
        away is where a wrong answer costs the most.|]

    transport = case o of
      Install ->
        [wft|
        A watched pane. Its consent gate is a *person's*, and an unwatched run
        reaches nobody: `--scripted` answers a flag and an adapter of the run's
        own has no one to ask. Give it the pane you are sitting in front of.|]
      Remove ->
        [wft|
        A watched pane, for a different reason: there is no person gate here.
        It edits the host's declarations and writes a script you will want to
        read before running it, so the pane is where you can see both as they
        happen.|]

    caveat = case o of
      Install ->
        [wft|
        * The cheapest ending finds no consent file, changes nothing on the
          machine, and stops. That is not a failure — it is the gate working,
          and the fix is to put the file there deliberately rather than to
          re-run with a flag.
        * The two health receipts are commands, so "it came up" is an exit code.
          A unit that installed and did not start is reported as such.|]
      Remove ->
        [wft|
        * **It writes a removal script; it does not remove.** The one act in the
          program produces a file for you to read and run, which is why the
          twelve discovery questions are worth paying for: their whole output is
          a script whose every line you can check against what they found.
        * Twelve read-only questions are its floor, and there is no arm in which
          fewer are asked. Discovery is not conditional here, because a removal
          script built from partial discovery is the failure this row exists to
          avoid.|]

-- ---------------------------------------------------------------------------
-- The two parties that are this program's own
-- ---------------------------------------------------------------------------

-- | The party that edits the host's configuration.
--
-- A @tool@ with __no__ argv, for "Workflows.Nix"'s reason: which Nix files an
-- obligation touches is whatever the obligation is, and an
-- @'Agentic.Workflow.act'@ at @'Agentic.Raw.CodeAck'@ is the only kind of answer
-- the ACP transport grants write authority to.
integrator :: Party 'IsTool
integrator = tool "service-configure"

-- | The party that writes the removal script.
--
-- A second tool and not 'integrator', deliberately: at @Remove@ the only writing
-- turn in the run is this one, and @wf plan service-remove --raw@ therefore shows
-- exactly one node with write authority against twelve without any. That is what
-- makes the read-only claim checkable from the printed program rather than from
-- this paragraph.
scriptwriter :: Party 'IsTool
scriptwriter = tool "service-script"

-- ---------------------------------------------------------------------------
-- The tier-1 readings of an invocation
-- ---------------------------------------------------------------------------

-- | The file whose presence is the operator's consent, named by the program.
--
-- /Source:/ @commands\/install-service.md@'s two capital-letter pleas, and
-- @'Workflows.Evidence.consentFile'@'s haddock, which names this command as one of
-- the two constructs it exists for.
--
-- __The path is program-authored, and it has to be.__ A gate whose file the
-- /answer/ named would be a gate a run could point at something that already
-- exists. This is ordinary Haskell over the service name — __tier 1__, zero
-- questions and zero paths — so @wf plan service-install --raw@ prints
-- @test -f .consent\/service-\<name\>@ and an operator can see the exact path he
-- has to create before the run will proceed. Nothing in "Workflows.Evidence" can
-- create it.
consentPath :: Text -> Text
consentPath svc = ".consent/service-" <> slug svc

-- | @\<name\>.service@ — the unit item 10's first receipt asks about.
--
-- __Tier 1__. A guess, and an honest one: most NixOS services name their unit
-- after themselves, and where this one does not the receipt fails loudly — a
-- @systemctl status@ on a unit that does not exist is a nonzero exit, which is a
-- @no@ and reaches the arm that says the unit is not up. The alternative was to
-- ask a model for the unit name and then run a command built from its answer,
-- which is exactly what an argv may never be.
unitName :: Text -> Text
unitName svc = slug svc <> ".service"

-- | The URL item 10's second receipt asks about.
--
-- __Tier 1__ over the @domain@ input, which is the vhost obligation 2 creates.
-- @https@ and not @http@, deliberately: obligation 2 is \"creating a TLS
-- certificate for the new domain so it can be accessed using HTTPS\", so a run
-- that only answers on port 80 has not met it, and the receipt should say so.
--
-- An absent domain becomes a URL no host serves, which is
-- 'Workflows.Git.Commit.treeNeedle'\''s rule: @wf plan --raw@ prints it, so an
-- operator who forgot the flag learns it from the plan rather than from a health
-- check that quietly passed against something else.
healthUrl :: Text -> Text
healthUrl d
  | T.null (T.strip d) = "https://no-domain-given.invalid/"
  | "http" `T.isPrefixOf` T.strip d = T.strip d
  | otherwise = "https://" <> T.strip d <> "/"

-- | A service name as a path component: lower-cased, spaces to hyphens.
slug :: Text -> Text
slug s
  | T.null (T.strip s) = "unnamed"
  | otherwise = T.toLower (T.replace " " "-" (T.strip s))

-- ---------------------------------------------------------------------------
-- The rubrics, transplanted
-- ---------------------------------------------------------------------------

-- | @commands\/install-service.md@'s standing constraints: coherence with the
-- machine, and the database preference.
--
-- /Source:/ its closing paragraphs — \"everything you do should be coherent with
-- the other services on this NixOS machine\" and \"if there is a choice of backing
-- database, I prefer to use the PostgreSQL and Redis services already running on
-- this server, even though you will likely need to create new users and databases
-- within those services\" — verbatim in substance.
housePreferences :: Text
housePreferences =
  [wft|
  Everything you do must be coherent with the other services already on this
  machine. Read how an existing service of the same shape is declared and
  follow it: the same module layout, the same naming, the same monitoring
  pattern, the same directory conventions. A service that works and looks
  nothing like its neighbours is a service the next person maintains twice.

  Where there is a choice of backing store, use the PostgreSQL and Redis
  services already running on this server rather than standing up new ones --
  you will need to create a new user and a new database inside them, and that
  is the intended cost.

  Where you must choose between a native NixOS service and a rootless quadlet
  container under a home-manager-managed user account, choose the one that fits
  this machine's existing practice for this kind of service, and say which and
  why. Do not introduce a second pattern for the sake of one service.|]

-- | @commands\/install-service.md@'s secrets rule, and what makes it hold.
--
-- /Source:/ its item 1 (\"never reveal secrets in this chat; ask me to create and
-- install them for you\") and its closing \"do not reveal ANY secrets during this
-- chat, and always ask me if you need to create a new SOPS secret or you need to
-- create a Web SSL certificate\", together with @skills\/nixos\/SKILL.md@'s \"do
-- not, under any circumstances, decrypt the SOPS secrets.yaml file\".
--
-- __What is carried and what is not.__ The prohibition on /decrypting/ is not in
-- this text and is not in any prompt in this tree: there is no @sops@ argv in
-- "Workflows.Evidence", so it is a command that does not exist rather than a rule
-- a run is trusted with, and @doc\/design.md@ §7.4 row 26 rules that this policy
-- \"rides on the argv … never in prompt text\". What /is/ carried is the part that
-- is a positive instruction — declare the secret, name it, and leave its creation
-- to the operator — because that is a thing the acting turn has to do rather than
-- refrain from.
secretsDiscipline :: Text
secretsDiscipline =
  [wft|
  Secrets are declared here and created by the operator. Where this service
  needs one, add its SOPS declaration and wire the service to read it from the
  path that declaration produces -- and then say, in one line, exactly which
  secret the operator must create and what it must contain.

  Do not put a secret's value anywhere: not in a file, not in a commit, not in
  your answer. A declaration names a secret; it does not carry one.

  The same applies to the TLS certificate: declare the virtual host and the
  certificate it uses, and ask for the certificate rather than issuing one.|]

-- ---------------------------------------------------------------------------
-- The nine obligations
-- ---------------------------------------------------------------------------

-- | @commands\/install-service.md@'s numbered list, items 1 through 9, in the
-- file's own order.
--
-- /Source:/ the ten items, less item 10 — which is the verification and is two
-- receipts here rather than a tenth call, exactly as @doc\/design.md@ §7.2 row 29
-- rules. The order is the file's and it is load-bearing: the secret before the
-- vhost that reads it, the vhost before the certificate monitoring that watches
-- it, the exporter before the alerting that reads it.
obligations :: [(Text, Text)]
obligations =
  [ ( "secrets",
      [wft|
      Manage every secret this service needs with SOPS. Add the declaration,
      wire the service to the path it produces, and state in one line which
      secret the operator has to create and what it must contain. Do not
      generate, read, print or commit a secret value.|]
    ),
    ( "vhost",
      [wft|
      Set up the nginx virtual host for this service, on the domain this run was
      given, so that it is reachable over HTTPS. Declare the virtual host and
      the certificate it uses; the certificate itself is the operator's to issue
      and this run has already confirmed he has done so. Follow the existing
      virtual hosts on this machine: the same ACME wiring, the same headers, the
      same proxy conventions.|]
    ),
    ( "cert-monitoring",
      [wft|
      Set up certificate monitoring and renewal for the new domain, exactly as
      it is already done for the other certificates this system manages. Find
      how an existing certificate is monitored and add this one to the same
      mechanism rather than inventing a second one.|]
    ),
    ( "prometheus",
      [wft|
      Set up Prometheus to gather metrics about this service: the exporter or
      the service's own metrics endpoint, the scrape configuration, and the
      labels that match this machine's existing convention. If the service
      exposes no metrics, say so plainly and say what could be scraped instead
      -- a process or a systemd unit collector.|]
    ),
    ( "alertmanager",
      [wft|
      Set up Alertmanager rules for the health of this service. Name the
      condition, the threshold, the duration, and the severity label -- and make
      the severity label match what this machine's existing rules use, because
      that label is what routes the page. A rule with no `for` duration is a
      rule that pages on a blip.|]
    ),
    ( "nagios",
      [wft|
      Set up a Nagios check confirming the health of this service, in addition
      to Prometheus. The two are deliberately redundant on this machine:
      Prometheus tells you how it is behaving and Nagios tells you whether it is
      there. Follow the existing checks.|]
    ),
    ( "grafana",
      [wft|
      If this service presents a full set of new metrics, create a Grafana
      dashboard for them. Prefer an existing published dashboard for this
      service where one fits -- say which, and where it came from -- over
      authoring panels from scratch. If the service's metrics are already
      covered by an existing dashboard on this machine, say so and add nothing.|]
    ),
    ( "glance",
      [wft|
      Add a link to this service under the appropriate existing section of the
      Glance dashboard. Name the section you chose and why it is the right one;
      do not create a new section for one service.|]
    ),
    ( "samba",
      [wft|
      If a new filesystem is being created to support this service, add it to
      the set of available Samba mounts, following the existing mounts'
      declaration and permissions. If no new filesystem is being created, say so
      in one line -- an absence stated is this obligation met, and an omission
      is not.|]
    )
  ]

-- ---------------------------------------------------------------------------
-- The twelve surfaces a removal must find
-- ---------------------------------------------------------------------------

-- | @commands\/remove-service.md@'s sweep, surface by surface.
--
-- /Source:/ its first paragraph — \"including nginx virtual hosts, monitoring,
-- alerting, systemd services and timers, containers, Nagios, Alertmanager,
-- Prometheus exporters, etc.\" — and its second, which extends the sweep to \"all
-- related configuration files, users, directories, data, etc.\" The @etc.@ is
-- where a Markdown sweep loses things, so the list is written out: twelve named
-- surfaces, and the twelfth is the one the file says to leave alone.
removalSurfaces :: [(Text, Text)]
removalSurfaces =
  [ ( "nix",
      [wft|
      Every declaration of this service in the Nix configuration: the module
      import, the service block, its options, its package, and any `let` binding
      or overlay that exists only for it. Name the file and the attribute path
      of each. This is the one surface this run may edit directly.|]
    ),
    ( "systemd",
      [wft|
      Every systemd unit, timer, socket, path unit and tmpfiles rule this
      service brings, including any generated by the module rather than written
      by hand. Name each unit and say whether it is enabled, and what stops and
      disables it.|]
    ),
    ( "containers",
      [wft|
      Any container or rootless quadlet this service runs under, its user
      account, its generated units, its volumes and its images. Name what has to
      be stopped, what has to be removed, and what would still occupy disk after
      the declaration is gone.|]
    ),
    ( "nginx",
      [wft|
      The nginx virtual host, its server names, its proxy targets, any redirect
      that points at it, and any include that exists only for it.|]
    ),
    ( "tls",
      [wft|
      The TLS certificate for its domain, its ACME configuration, and its
      renewal and monitoring entries -- including the monitoring this machine
      adds for every certificate, which is a place a removal is routinely
      forgotten.|]
    ),
    ( "prometheus",
      [wft|
      The Prometheus exporter, the scrape job, any relabelling that names this
      service, and any recording rule computed from its metrics.|]
    ),
    ( "alertmanager",
      [wft|
      Every Alertmanager rule and route that names this service, and any silence
      or inhibition that exists because of it.|]
    ),
    ( "nagios",
      "Every Nagios host, service, command and contact entry for it."
    ),
    ( "grafana",
      [wft|
      Its Grafana dashboard, any panel in a shared dashboard that queries only
      its metrics, and any datasource that exists only for it.|]
    ),
    ( "glance",
      [wft|
      Its link on the Glance dashboard, and the section that would be left empty
      by removing it.|]
    ),
    ( "state",
      [wft|
      Its users and groups, its home and state directories, its data, its
      database and database user inside the shared PostgreSQL and Redis, its
      Samba mount if it had one, and its backup entries. Say which of these hold
      DATA that would be destroyed, because those are the lines the operator
      will want to read twice before running anything.|]
    ),
    ( "sops",
      [wft|
      Its SOPS secrets: find them and name them, and DO NOT include their
      removal in the script. The operator cleans up secrets himself, by his own
      instruction. Your job on this surface is a list he can work from -- which
      secret, in which file, referenced from where.|]
    )
  ]

-- | The twelve surfaces, as a roster of questions asked at @text@.
--
-- __This roster is the exemplar.__ @doc\/design.md@ §7.2 row 51 says every
-- discovery question here is @'Agentic.Raw.CodeText'@, and that is the whole
-- mechanism of @remove-service.md@'s inversion: a reviewing question is asked at
-- @text@, and @Agentic.Acp.permissionByCode@ grants write authority only to an act
-- at @receipt@ — so none of these twelve /can/ remove anything, whatever a prompt
-- says to it. The one act in the run writes a script.
--
-- Three rungs: @'Workflows.Parties.reasoning'@ for the three surfaces where
-- getting it wrong destroys something (the Nix declarations, the state, the
-- secrets), @'Workflows.Parties.lateral'@ for the two that are routinely
-- forgotten and therefore want a different reader, and
-- @'Workflows.Parties.broad'@ for the rest.
--
-- __The roster is fixed at twelve, so WR-1 has nothing to say here__: no input
-- shapes it and @'Agentic.Workflow.panelText' []@ is unreachable.
removalRoster :: Roster
removalRoster =
  [ Lens
      { lensName = n,
        lensOwns = "what to remove on the " <> n <> " surface, and what it would destroy",
        lensBrief = brief,
        lensParty = rungFor n (model ("service-remove-" <> n))
      }
  | (n, brief) <- removalSurfaces
  ]
  where
    rungFor n
      | n `elem` ["nix", "state", "sops"] = reasoning
      | n `elem` ["tls", "grafana"] = lateral
      | otherwise = broad

-- ---------------------------------------------------------------------------
-- The prompts
-- ---------------------------------------------------------------------------

-- | What the consent receipt is asked.
--
-- /Source:/ @install-service.md@'s two pleas. Asked as a __flag__, because that is
-- what an exit code is: @test -f@ answers yes or no and nothing else.
consentBrief :: Text
consentBrief =
  [wft|
  The operator's consent file. Its presence means he has issued the TLS
  certificate for the new domain and installed the SOPS secrets this service
  needs. Its absence means he has not, and this run does not proceed: nothing
  in this program can create this file.|]

-- | What the run says to the operator when the consent file is absent.
--
-- /Source:/ @install-service.md@ items 1 and 2, said back to the person the file
-- says to say them to. This is a __terminal__: the run ends here, which is what
-- \"DO NOT try to generate the certificate yourself\" means when it is a shape
-- rather than a shout.
prerequisitesBrief :: Text
prerequisitesBrief =
  [wft|
  This installation needs two things from you before it can start, and neither
  is something this run may do for itself.

  First, the TLS certificate for the new domain. Issue it the way you issue the
  others on this machine. This run will declare the virtual host that uses it
  and will not generate it.

  Second, the SOPS secrets this service needs. The run cannot know which until
  it has read the service's configuration, so this is the ordering: create the
  consent file now if you are content for the run to proceed and to TELL you
  which secrets to create as it goes, and it will declare each one and name it
  for you rather than inventing a value.

  Create the consent file named in this run's own plan, and start the run
  again. Nothing has been changed on this machine.|]

-- | What the shape question asks.
--
-- /Source:/ @install-service.md@'s first sentence: \"either as a native NixOS
-- service or as a rootless quadlet container under a user account managed by
-- home-manager, whichever is best for my configuration.\"
shapeBrief :: Text
shapeBrief =
  [wft|
  Decide how this service should be installed on this machine, and answer with
  that decision and nothing else: it is spliced into every obligation below, so
  the nine of them cannot disagree about what is being installed.

  Choose between a native NixOS service and a rootless quadlet container under
  a home-manager-managed user account. Say which, and say why in terms of THIS
  machine's existing practice for services of this shape -- not in terms of
  which is better in general.

  Then state the concrete consequences of the choice that the obligations will
  need: the unit name, the user it runs as, the port it listens on, its state
  directory, and where its configuration will live. Where you are not sure of
  one, say so rather than picking: an obligation that acts on a guessed port
  produces a service that starts and answers nothing.|]

-- | What each obligation's planning question asks, above the obligation itself.
obligationBrief :: Text
obligationBrief =
  [wft|
  Carry out one obligation of a service installation, and only that one. The
  obligation is stated below; everything else about this installation is
  somebody else's turn.

  Answer with the plan: which file, which attribute, what it becomes, and what
  existing declaration on this machine you are following. Then it is applied.

  Say explicitly if this obligation does not apply to this service, and why.
  "Not applicable, because this service exposes no metrics" is a complete
  answer to an obligation and is worth more than a plausible one invented to
  fill the slot.|]

-- | What the applying act is told.
obligationApplyBrief :: Text
obligationApplyBrief =
  [wft|
  Apply the plan below, and only it. Do not do the next obligation, do not
  reformat the files you are in, and do not fix an unrelated thing you notice --
  each obligation is applied by its own turn precisely so that a failure can be
  attributed to one.

  Do not activate the configuration and do not build it: a later step runs the
  host's own driver, and its verdict is the one that counts.

  Where the plan says this obligation does not apply, change nothing and say so.

  When you are done, reply DONE with one line per file changed.|]

-- | What the removal script act is told.
--
-- /Source:/ @remove-service.md@, whose inversion this is: \"do not perform this
-- removal directly, however, rather generate a script that I can run at a later
-- time that will carry out all of the action you would have performed. You are
-- entirely free, although, to remove declarations from the Nix files, but leave
-- cleanup of the SOPS secrets to me.\"
scriptBrief :: Text
scriptBrief =
  [wft|
  Two things, and they have different authority.

  First, remove this service's declarations from the Nix configuration. That is
  an edit you may make: the nix surface below says which files and which
  attribute paths, and you make exactly those removals. Leave the rest of each
  file alone.

  Second, write a shell script -- do not run it -- that carries out everything
  else the surfaces below describe: stopping and disabling units, removing
  containers and images, dropping the database and its user, removing users,
  groups, state directories and data, and removing the Samba mount and backup
  entries. This script is read by the operator before he runs it, so write it to
  be read:

  - `set -euo pipefail`, and no `rm -rf` without the path written out in full;
  - one commented section per surface, in the order the surfaces are given;
  - every destructive line preceded by a comment saying what data it destroys
    and whether it is recoverable;
  - a first section that is purely a dry run -- what exists, what would be
    removed -- so the operator can read the script's own findings before
    anything is deleted;
  - no secret values, and NOTHING that touches SOPS. The operator cleans up
    secrets himself. List the secrets in a comment at the end, by name and
    location, and stop there.

  Name the script for the service and put it where a human will find it. When
  you are done, reply DONE with the script's path and the files whose
  declarations you edited.|]

-- | What the unit receipt is asked.
--
-- /Source:/ @install-service.md@ item 10. Asked as a flag: @systemctl status@
-- exits nonzero when the unit is not running, so this is an exit code and not a
-- reading.
unitBrief :: Text
unitBrief =
  [wft|
  The service's own systemd unit, as systemctl reports it. A pass here means
  the unit is loaded, enabled and running on this machine right now.|]

-- | What the endpoint receipt is asked.
--
-- /Source:/ @install-service.md@ items 2 and 10, together: the vhost exists so
-- that the service \"can be accessed using HTTPS\", and item 10 wants the service
-- tested. This receipt tests the two at once, which is why its failure is a
-- distinct ending — the unit can be perfectly healthy while nginx, the
-- certificate, or the port is wrong.
endpointBrief :: Text
endpointBrief =
  [wft|
  The service over HTTPS, at the domain this run was given. A pass here means
  nginx is routing, the certificate is valid and trusted, and the service
  answered.|]

-- ---------------------------------------------------------------------------
-- The provenance lines
-- ---------------------------------------------------------------------------

-- | The install arm where every obligation was met and both receipts passed.
installedNote :: Text
installedNote =
  [wft|
  Outcome: INSTALLED AND ANSWERING. The operator's consent file was present, so
  the certificate and the secrets were his; nine obligations were each planned
  and applied in their own turn, in the file's own order; and both closing
  receipts passed -- the systemd unit is running and the service answers over
  HTTPS at its domain with a certificate this machine trusts. Report each
  obligation and what was changed for it, name every obligation that reported
  itself not applicable and why, and list every SOPS secret the operator still
  has to create.|]

-- | The install arm where the unit is up and nothing answers.
--
-- This is the ending the corpus's last bullet cannot have, and it is the most
-- useful of the three: a running unit and a dead endpoint is nginx, or the
-- certificate, or the port — and none of those is the service.
notAnsweringNote :: Text
notAnsweringNote =
  [wft|
  Outcome: RUNNING, NOT REACHABLE. The systemd unit is up, and the service did
  NOT answer over HTTPS at its domain. Do not report this installation as
  finished. The unit being healthy narrows it: the service itself started, so
  the fault is between the domain and the process -- the nginx virtual host and
  its proxy target, the certificate's validity or trust chain, or the port the
  service actually listens on against the port the virtual host proxies to. Say
  which of those three this run can rule out from what it changed, and which it
  cannot. Every obligation's edit is still in place.|]

-- | The install arm where the unit itself is not up.
notRunningNote :: Text
notRunningNote =
  [wft|
  Outcome: NOT RUNNING. `systemctl status` says the service's unit is not
  running, so the endpoint was not asked about -- there is nothing behind it to
  answer. Do not report this installation as finished and do not describe the
  monitoring as working: an exporter scraping a dead service is a dashboard of
  zeroes. Report the unit name that was asked about, since a unit named
  differently from the service would produce exactly this result, and then the
  obligations as applied. Every edit is still in place.|]

-- | The install arm where the operator has not done his part.
consentAbsentNote :: Text
consentAbsentNote =
  [wft|
  Outcome: NOT STARTED -- WAITING ON THE OPERATOR. The consent file this run
  requires was not there, so nothing was planned, nothing was changed and no
  obligation was attempted. This is the gate that stands in for two instructions
  the source command shouts: the TLS certificate and the SOPS secrets are the
  operator's, and a run that could satisfy the gate itself would not be a gate.
  Report the exact path the run looked for and what has to exist before it is
  started again.|]

-- | The remove arm where the tree still builds.
removedNote :: Text
removedNote =
  [wft|
  Outcome: DECLARATIONS REMOVED, SCRIPT WRITTEN, TREE STILL BUILDS. Twelve
  surfaces were swept by questions that had no authority to remove anything; the
  service's Nix declarations were removed; a script carrying out everything else
  was WRITTEN AND NOT RUN; and the host's own build driver was run afterwards
  and passed. Those are two different guarantees and the report must keep them
  apart: the build proves the configuration is still coherent without this
  service, and it proves nothing at all about the script -- which the operator
  reads before he runs it. Report the script's path, its destructive sections
  and what each destroys, and the SOPS secrets listed for him to clean up
  himself.|]

-- | The remove arm where the tree stopped building.
removalRedNote :: Text
removalRedNote =
  [wft|
  Outcome: THE CONFIGURATION NO LONGER BUILDS. The service's declarations were
  removed and the host's own build driver still objects after every repair trip
  this run was given -- so something else on this machine depended on what came
  out. Do not report the removal as complete and do not suggest running the
  script: a script that tears down state for a service whose declaration cannot
  be removed cleanly is a script run against a half-configured machine. Quote
  the driver's own failing line, name what it says still references the service,
  and say what would have to change first. The script was written and is not to
  be run yet.|]

-- ---------------------------------------------------------------------------
-- The functions
-- ---------------------------------------------------------------------------

-- | One obligation: plan it, then apply it.
--
-- Two parameters and two statements, and it is called __nine times__. A function
-- rather than nine copies for "Workflows.Report"'s reason: a call is priced at the
-- callee's own body with the arguments ignored, so the nine call sites share one
-- body and cannot drift, and the elaborated program still shows nine nodes in
-- dependency order.
obligationFn :: Fn '[ 'CodeText, 'CodeText] 'CodeAck
obligationFn =
  function
    "service.obligation"
    ( takes @"obligation" Text
        . takes @"shape" Text
        $ noParams
    )
    \obligation shape -> W.do
      plan <- ask nixPro [wf|
          {obligationBrief}

          {preferences}

          {secrets}

          How this service is being installed, decided once for every obligation:

          {shape}

          The obligation:

          {obligation}|]

      act integrator [wf|
          {obligationApplyBrief}

          {plan}|]
      done
  where
    preferences = housePreferences
    secrets = secretsDiscipline

-- | The brief the report is written through.
serviceReportBrief :: Text
serviceReportBrief =
  [wft|
  Write the report for a service run on this NixOS host. It is read by the
  operator of the machine, who will decide from it what to do next.

  Open with the provenance line you were given, verbatim, on its own line. It is
  the run's own account of how it ended, and it is not yours to soften or to
  restate.

  Then, from the work below and nothing else:

  - one line per obligation or surface, saying what was done, or that it did not
    apply and why;
  - every SOPS secret the operator must create or clean up, by name and
    location, and no secret values;
  - what the closing receipts said -- the unit, the endpoint, or the build
    driver -- verbatim;
  - what this run did NOT establish;
  - what to do next, in order.

  Two things you must not write. Do not describe monitoring as working because
  it was declared: a scrape job is not a metric. And do not describe anything as
  verified that a receipt did not verify -- say which claims rest on a command's
  exit code and which rest on a reading.|]

-- | One act, seven provenance lines.
--
-- Three parameters: the provenance first, for "Workflows.Report"'s reason; then
-- what the run did, which is the obligations or the surfaces; then the closing
-- evidence, which is whichever receipt the arm ended on.
serviceReportFn :: Fn '[ 'CodeText, 'CodeText, 'CodeText] 'CodeAck
serviceReportFn =
  function
    "service.report"
    ( takes @"provenance" Text
        . takes @"work" Text
        . takes @"evidence" Text
        $ noParams
    )
    \provenance work evidence -> W.do
      act reporter [wf|
          {serviceReportBrief}

          Provenance:

          {provenance}

          What this run did:

          {work}

          The closing evidence:

          {evidence}

          Write the report, then reply DONE.|]
      done

-- | The table 'serviceProgram' hands @'Agentic.Workflow.defining'@.
--
-- Two entries, and @'Agentic.Workflow.defining'@ checks that every call names one
-- the list declared — so the @Remove@ operation, which never calls
-- 'obligationFn', still declares it. That is the table being the /family's/ and
-- not the operation's, which is "Workflows.Report"'s arrangement.
serviceTable :: [SomeFn]
serviceTable = [SomeFn obligationFn, SomeFn serviceReportFn]

-- ---------------------------------------------------------------------------
-- The program
-- ---------------------------------------------------------------------------

-- | Install behind a gate the run cannot pass, or remove with questions that
-- cannot remove.
--
-- Three inputs, shared by both operations. @service@ is the service's name, and
-- it names the consent file and the unit in Haskell; @domain@ is the virtual
-- host, and it names the health URL; @host@ is the machine, and it decides the
-- build flags exactly as "Workflows.Nix" does.
--
-- At @Install@: the consent flag, then — and only then — the shape question, nine
-- obligation calls in the file's own order, and two health receipts read as three
-- endings. At @Remove@: twelve read-only surface questions, one act that edits the
-- Nix declarations and writes a script it does not run, and the host's own driver
-- as the gate. Six endings in all, six provenance lines, __one__
-- 'serviceReportFn'.
serviceProgram :: ServiceOp -> Parameterized
serviceProgram op =
  taking (input "service" :> input "domain" :> input "host" :> noInputs) \svc domain host ->
    -- Tier 1, four times: the consent file's path, the unit's name, the health
    -- URL, and the build flags this host needs. All four are ordinary Haskell over
    -- the invocation, and all four are in the printed argv.
    let consent = consentPath svc
        unit = unitName svc
        url = healthUrl domain
        flags = hostFlags host
        checked = checkedNote unit url
     in defining serviceTable case op of
          Install -> W.do
            -- The gate that stands in for two shouted instructions. A file the
            -- program is forbidden to create, so an unattended run cannot pass it
            -- by answering its own question.
            ready <- passes (consentFile consent) [wf|{consentBrief}|]

            if ready
              then W.do
                -- Decided once, spliced into all nine. The corpus leaves this
                -- implicit in whatever the reader happens to do first.
                shape <- ask nixPro [wf|
                    {shapeBrief}

                    {preferences}

                    The service: {svc}
                    Its domain: {domain}|]

                -- Nine obligations, nine calls, in the file's own order.
                call_ obligationFn (arg (obligationText "secrets") :> arg shape :> noArgs)
                call_ obligationFn (arg (obligationText "vhost") :> arg shape :> noArgs)
                call_ obligationFn (arg (obligationText "cert-monitoring") :> arg shape :> noArgs)
                call_ obligationFn (arg (obligationText "prometheus") :> arg shape :> noArgs)
                call_ obligationFn (arg (obligationText "alertmanager") :> arg shape :> noArgs)
                call_ obligationFn (arg (obligationText "nagios") :> arg shape :> noArgs)
                call_ obligationFn (arg (obligationText "grafana") :> arg shape :> noArgs)
                call_ obligationFn (arg (obligationText "glance") :> arg shape :> noArgs)
                call_ obligationFn (arg (obligationText "samba") :> arg shape :> noArgs)

                -- Item 10, as two exit codes and three endings.
                up <- passes (systemctlStatus unit) [wf|{unitBrief}|]

                if up
                  then W.do
                    reachable <- passes (httpHealth url) [wf|{endpointBrief}|]

                    if reachable
                      then W.do
                        call_ serviceReportFn (arg installedNote :> arg shape :> arg checked :> noArgs)
                        stop
                      else W.do
                        call_ serviceReportFn (arg notAnsweringNote :> arg shape :> arg checked :> noArgs)
                        stop
                  else W.do
                    call_ serviceReportFn (arg notRunningNote :> arg shape :> arg checked :> noArgs)
                    stop
              else
                -- The terminal `doc/design.md` §7.2 row 29 asks for. The run ends
                -- at the owner's desk, and nothing on the machine has changed.
                ask_ owner [wf|
                    {prerequisitesBrief}

                    The service: {svc}
                    Its domain: {domain}
                    The consent file this run requires: {consent}

                    {absent}|]
          Remove -> W.do
            -- Twelve questions at `text`, which is what makes them unable to
            -- remove anything. See the module header, item 5.
            surfaces <- panelText (zip (lensNames removalRoster) (asksOver removalRoster removalClosing svc))

            -- The one act, and the only node in this program with write
            -- authority.
            act scriptwriter [wf|
                {scriptBrief}

                The service: {svc}
                Its domain: {domain}

                What the twelve surface sweeps found:

                {surfaces}|]

            -- The host's own driver, as the verification that what came out could
            -- come out.
            gated <- gate (nixosBuild "build" flags) repairBrief nixPro surfaces (atMost 2)

            case gated of
              Settled final -> W.do
                call_ serviceReportFn (arg removedNote :> arg final :> arg surfaces :> noArgs)
                stop
              Unsettled final -> W.do
                call_ serviceReportFn (arg removalRedNote :> arg final :> arg surfaces :> noArgs)
                stop
  where
    preferences = housePreferences
    absent = consentAbsentNote

-- | What the closing receipts asked about, named for the report.
--
-- __Tier 1__: both names were computed from the invocation, so the report can say
-- which unit and which URL were tested without a receipt being spent on saying it
-- — which matters most on the not-running arm, where a unit named differently
-- from the service produces exactly the observed result and is the first thing to
-- rule out.
checkedNote :: Text -> Text -> Text
checkedNote unit url =
  "The two closing receipts asked about `systemctl status "
    <> unit
    <> "` and `curl -fsS "
    <> url
    <> [wft|
       `. Both names were derived from this run's inputs, not discovered: if the
       service's unit is not called that, or its virtual host is not at that
       address, then the receipt tested the wrong thing and that is the first
       possibility to rule out.|]

-- | One obligation's text, by name.
--
-- The list is 'obligations' and the lookup is total: a name this module does not
-- carry is a programming error here and not a run-time one, so the fallback says
-- so rather than passing an empty obligation to a turn that would then invent one.
obligationText :: Text -> Text
obligationText n = case [b | (k, b) <- obligations, k == n] of
  (b : _) -> "(" <> n <> ") " <> b
  [] -> "(" <> n <> ") NO OBLIGATION OF THIS NAME IS DEFINED. Change nothing and report this."

-- | What each removal surface is told about the shape of its answer.
removalClosing :: Text
removalClosing =
  [wft|
  Sweep your own surface and nothing else. Your answer is one block of a
  document whose other blocks are the other surfaces', each fenced under its own
  name: do not sweep theirs and do not summarise the whole.

  You are reading, not writing. Report what exists, where it is declared, what
  removes it, and what data -- if any -- removing it destroys. Do not remove
  anything and do not propose a command you have not established is needed.

  Where your surface is empty for this service, say so. An empty surface stated
  is a surface accounted for, and it is what stops the script from carrying a
  line that removes something that was never there.|]

-- ---------------------------------------------------------------------------
-- The registry's other column
-- ---------------------------------------------------------------------------

-- | The canned replies a @--scripted@ run of an operation answers from, keyed by
-- prefix.
--
-- __The keys are the defines themselves__, so each is a prefix of the rendered
-- prompt by construction: the shape question opens with 'shapeBrief', every
-- obligation's planning question opens with 'obligationBrief' — /all nine/, which
-- is what one row here covers — and each surface's with its own
-- 'Workflows.Panels.lensBrief'.
--
-- __At @Install@ the flag defaults do the steering and they steer it well.__
-- @'Agentic.Exec.scriptedDefault'@ answers a flag @yes@, so the consent file is
-- present, the unit is up and the endpoint answers: the run walks the whole
-- installation and ends in 'installedNote', which is the arm an operator wants
-- rehearsed. The other three arms are one line each — @(consentBrief, \"no\")@
-- reaches the owner's terminal, @(unitBrief, \"no\")@ reaches the not-running
-- ending, and @(endpointBrief, \"no\")@ reaches the most interesting one — and all
-- four exit 0.
--
-- __The nine obligations share one canned answer, and that is correct here.__ They
-- share an opening chunk by construction, because 'obligationFn' is one body
-- called nine times and its question opens with 'obligationBrief'. A scripted
-- table matches the first key that is a prefix of the rendered prompt, so one row
-- answers all nine — which is what a shared body /means/, and it is the same fact
-- @wf cost@ reports when it prices nine calls at one body's worth of nodes.
--
-- __One consequence shows in the run's own bills and is worth reading correctly.__
-- A scripted @service-install@ reports @billFresh 23@ and @billMemo 15@, and the
-- gap of eight is __the table's and not the program's__: the nine planning
-- questions differ, because each carries its own obligation, but the nine applying
-- acts are handed the same canned plan and are therefore the same question eight
-- times over. Under a real engine the nine plans differ and the nine acts differ
-- with them. A rehearsal is a rehearsal, and this is the one place the difference
-- is visible in a number.
serviceScript :: ServiceOp -> [(Text, Text)]
serviceScript Install =
  [ (shapeBrief, shaped),
    (obligationBrief, planned)
  ]
  where
    shaped =
      [wft|
      Native NixOS service. This machine declares its other metrics-exposing
      services natively and reserves quadlets for upstreams that ship only
      images; this one has a nixpkgs module.
      Unit: paperless.service. User: paperless. Port: 28981. State:
      /var/lib/paperless. Configuration: hosts/vulcan/paperless.nix.
      Not sure of: whether the module's default port is overridden elsewhere on
      this host.|]

    planned =
      [wft|
      hosts/vulcan/paperless.nix -- add the declaration this obligation needs,
      following hosts/vulcan/grafana.nix, which is the nearest existing service
      of the same shape. Applied as written.|]
serviceScript Remove =
  [ (repairBrief, "Removed the last reference to the service from hosts/vulcan/monitoring.nix.")
  ]
    <> [(lensBrief l, sweptAnswer l) | l <- removalRoster]
  where
    sweptAnswer l
      | lensName l == "sops" =
          [wft|
          sops/secrets.yaml carries `paperless/admin-password`, referenced from
          hosts/vulcan/paperless.nix:22. Listed for the operator and NOT in the
          script.|]
      | lensName l == "state" =
          [wft|
          /var/lib/paperless (DATA: documents and their index; not recoverable
          once removed), the `paperless` user and group, and the `paperless`
          database and role in the shared PostgreSQL (DATA).|]
      | otherwise =
          [wft|
          On {owns}: found and named, with the file and the attribute path, and
          nothing removed. (the {name} surface)|]
      where
        owns = lensOwns l
        name = lensName l
