#!/usr/bin/env python3
"""Self-contained deterministic ACP adapter for the Taskmaster workflow gate."""

from __future__ import annotations

import json
import os
import re
import sys

PROTOCOL_VERSION = 1
SESSION_ID = "9f3f7b1e-2c4a-4d5e-8f00-000000000074"
MODE = os.environ.get("TASKMASTER_FIXTURE_MODE", "valid")
MODEL_NAMES = [
    "fable",
    "gemini-3.1-pro-preview",
    "opus",
    "gpt-5.5-pro",
]
CONFIG_OPTIONS = [
    {
        "id": "mode",
        "name": "Mode",
        "category": "mode",
        "type": "select",
        "currentValue": "default",
        "options": [{"value": "default", "name": "Default"}],
    },
    {
        "id": "model",
        "name": "Model",
        "category": "model",
        "type": "select",
        "currentValue": MODEL_NAMES[0],
        "options": [{"value": name, "name": name} for name in MODEL_NAMES],
    },
]
MODES = {
    "currentModeId": "default",
    "availableModes": [{"id": "default", "name": "Default", "description": "Fixture mode"}],
}


def send(value):
    sys.stdout.write(json.dumps(value, separators=(",", ":")) + "\n")
    sys.stdout.flush()


def result(identifier, value):
    send({"jsonrpc": "2.0", "id": identifier, "result": value})


def error(identifier, code, message):
    send({"jsonrpc": "2.0", "id": identifier, "error": {"code": code, "message": message}})


def update(value):
    send({
        "jsonrpc": "2.0",
        "method": "session/update",
        "params": {"sessionId": SESSION_ID, "update": value},
    })


def prompt_text(params):
    return "".join(
        block.get("text", "")
        for block in params.get("prompt", [])
        if block.get("type") == "text"
    )


def tagged(text, name):
    match = re.search(rf"<{name}>(.*?)</{name}>", text, re.S)
    if not match:
        raise RuntimeError(f"fixture prompt lacks <{name}>")
    return json.loads(match.group(1))


def inventory(manifest):
    grouped = {"taskmaster": {}, "agent-cat": {}}
    for record in manifest["evidence"]:
        grouped[record["repository"]].setdefault(record["category"], []).append(record)

    def records(repository):
        return [
            {
                "category": category,
                "summary": "; ".join(
                    record["claim"].rstrip(".")
                    for record in grouped[repository][category]
                ) + ".",
                "evidenceIds": [record["id"] for record in grouped[repository][category]],
            }
            for category in manifest["requiredCategories"]
            if category != "license-provenance"
        ]

    return {
        "version": 1,
        "status": "complete",
        "upstream": records("taskmaster"),
        "agentCat": records("agent-cat"),
    }


def design(manifest):
    by_category = {}
    for record in manifest["evidence"]:
        by_category.setdefault(record["category"], []).append(record["id"])
    categories = [
        category
        for category in manifest["requiredCategories"]
        if category != "license-provenance"
    ]
    mapping_policy = {
        "task-structure-dependencies": ("ADAPT", "Agentic.Framework.Spec", "Represent cross-run dependencies in FrameworkSpec; leave single-run Plan sequencing unchanged."),
        "decomposition": ("ADAPT", "proposal Registry programs", "Let ordinary Registry programs propose validated graph patches; do not add decomposition primitives to Plan."),
        "research": ("ADAPT", "proposal Registry programs", "Treat research as an evidence-producing program that may propose a graph patch behind a person gate."),
        "execution-loops": ("ADAPT", "Agentic.Framework.Controller", "Use Controller attempt bounds across runs and keep revising bounded within one run."),
        "workflow-state": ("ADAPT", "Agentic.Framework.Controller", "Store node status in Controller state rather than adding operational status to Workflow stages."),
        "storage-persistence": ("ADAPT", "Agentic.Framework.Repository", "Persist Controller state and certificate references atomically; keep ExecTrace as run evidence."),
        "interfaces": ("ADAPT", "Registry and Agentic.Cli", "Expose FrameworkSpec through thin Registry/Cli integration after semantic modules exist."),
        "providers": ("ADOPT", "Agentic.Route and Agentic.Chains", "Reuse existing model routing and fail-over without a framework-specific provider layer."),
        "tags-workstreams": ("DEFER", "repository adapter metadata", "Defer workstream tags; reserve optional repository metadata without changing framework meaning."),
        "collaboration": ("DEFER", "repository adapter metadata", "Keep multi-user collaboration outside the minimum framework and preserve only optional ownership metadata."),
    }
    mappings = [
        {
            "category": category,
            "disposition": mapping_policy[category][0],
            "agentCatOwner": mapping_policy[category][1],
            "interpretation": mapping_policy[category][2],
            "evidenceIds": by_category[category],
        }
        for category in categories
    ]
    stages = [
        {"id": "formal-spec", "files": ["Agentic/Framework/Spec.lean"], "behavior": "Reject cyclic and dangling graphs and derive readiness from completed prerequisites.", "check": "lake build"},
        {"id": "haskell-spec", "files": ["haskell/src/Agentic/Framework/Spec.hs"], "behavior": "Decode the same graph shape and agree with checked Lean conformance vectors.", "check": "nix develop path:./. -c cabal build all"},
        {"id": "controller", "files": ["haskell/src/Agentic/Framework/Controller.hs"], "behavior": "Atomically claim ready nodes, enforce attempt bounds, and report no-ready deadlock.", "check": "./ci/tier0.sh"},
        {"id": "certificate", "files": ["haskell/src/Agentic/Framework/Certificate.hs"], "behavior": "Refuse completion unless accepted ExecTrace and Certify evidence produce a RunCertificate.", "check": "./ci/policies.sh"},
        {"id": "repository", "files": ["haskell/src/Agentic/Framework/Repository.hs"], "behavior": "Persist Controller state atomically and replay a crashed run idempotently.", "check": "./ci/acp.sh"},
        {"id": "proposal-workflow", "files": ["haskell/example/Example/FrameworkProposal.hs"], "behavior": "Emit a graph patch that schema validation and an explicit person gate can accept or reject.", "check": "./ci/deck.sh"},
        {"id": "cli-integration", "files": ["haskell/src/Agentic/Cli.hs", "haskell/ci/framework.sh"], "behavior": "Run one named FrameworkSpec node through Registry routing and print matching Plan facts.", "check": "./ci/examples.sh"},
    ]
    risks = [
        {"risk": "Mutable status leaks into Plan meaning.", "mitigation": "Keep Controller state in Agentic.Framework only."},
        {"risk": "Agent prose falsely claims completion.", "mitigation": "Require RunCertificate evidence."},
        {"risk": "Crash repeats an effect.", "mitigation": "Use run IDs and idempotent certificate replay."},
        {"risk": "Concurrent claims lose updates.", "mitigation": "Make claim atomic in the repository adapter."},
        {"risk": "Unbounded retries spend indefinitely.", "mitigation": "Store and enforce a finite attempt bound."},
        {"risk": "License conclusions are overstated.", "mitigation": "Copy no implementation and retain exact license provenance."},
    ]
    recommendation_policy = {
        "collaboration": ("Defer multi-user collaboration and keep optional ownership fields in repository metadata.", "nix develop path:./. -c cabal build all"),
        "decomposition": ("Implement decomposition and research as Registry programs that propose validated FrameworkSpec patches.", "./ci/deck.sh"),
        "execution-loops": ("Put cross-run attempts and retry exhaustion in Controller while retaining bounded revising inside each run.", "./ci/tier0.sh"),
        "interfaces": ("Add only thin Registry and Cli entry points after Spec, Controller, Certificate, and Repository exist.", "./ci/examples.sh"),
        "providers": ("Reuse Route and Chains unchanged for framework nodes and add no framework-specific provider abstraction.", "./ci/acp.sh"),
        "research": ("Require research-produced graph patches to pass schema validation and an explicit person gate.", "./ci/deck.sh"),
        "storage-persistence": ("Persist Controller state and RunCertificate references atomically, never ExecTrace as mutable state.", "./ci/policies.sh"),
        "tags-workstreams": ("Defer workstream tags until a repository adapter demonstrates a semantic requirement for them.", "nix develop path:./. -c cabal build all"),
        "task-structure-dependencies": ("Define FrameworkSpec as the separate finite dependency DAG and keep Plan unchanged.", "lake build"),
        "workflow-state": ("Define Controller node states and no-ready deadlock separately from Workflow authoring stages.", "./ci/tier0.sh"),
    }
    recommendations = [
        {
            "id": f"R{index + 1}",
            "recommendation": recommendation_policy[category][0],
            "evidenceIds": by_category[category],
            "check": recommendation_policy[category][1],
        }
        for index, category in enumerate(categories)
    ]
    return {
        "version": 1,
        "status": "complete",
        "executiveDecision": "Build a finite FrameworkSpec DAG, separate Controller, RunCertificate, repository adapter, proposal workflows, and thin Registry/Cli integration without changing Plan.",
        "mappings": mappings,
        "architecture": {
            "frameworkSpecKind": "finite multi-run DAG",
            "frameworkSpecOutsidePlan": True,
            "controllerOwnsOperationalState": True,
            "readinessOwner": "FrameworkSpec",
            "execTraceRole": "run evidence",
            "persistenceOwner": "repository adapter",
            "planChanged": False,
            "workflowChanged": False,
            "execChanged": False,
            "routeChanged": False,
            "certifyChanged": False,
            "taskmasterJsonParsed": False,
        },
        "semantics": {
            "principalObject": "FrameworkSpec is a finite dependency DAG whose nodes name Registry rows, inputs, prerequisites, and completion contracts.",
            "representationTower": ["FrameworkSpec", "Controller state", "existing Plan and ExecTrace", "RunCertificate"],
            "laws": [
                "the graph is finite and acyclic",
                "a node is ready exactly when every prerequisite has a completion certificate",
                "claiming one node does not change Plan meaning",
                "ExecTrace is immutable run evidence rather than controller state",
                "a node completes only after its completion contract yields a RunCertificate",
            ],
        },
        "lifecycle": [
            "validate every node reference and reject a cyclic graph before execution",
            "derive the ready set from prerequisite completion certificates",
            "atomically claim one ready node with a stable run identifier",
            "execute the node's Registry row through existing Route and Exec seams",
            "evaluate its completion contract against ExecTrace and Certify evidence",
            "record an immutable RunCertificate for an accepted result",
            "complete, retry, or block the node within its stored attempt bound",
            "persist Controller state and repeat, or report no-ready deadlock",
        ],
        "failures": [
            "invalid or dangling graph input refuses controller initialization",
            "no ready node with unfinished work reports an explicit deadlock",
            "transport failure records the attempt without completing the node",
            "tool failure records the attempt without treating model prose as success",
            "failed acceptance retains evidence but produces no completion certificate",
            "retry exhaustion blocks the node and prevents further spending",
            "persistence failure withholds acknowledgement of the state transition",
            "crash replay uses the stable run identifier to avoid repeating accepted effects",
        ],
        "extensionPoints": [
            "Registry rows define executable node behavior without extending Plan",
            "repository adapters add storage backends without changing graph meaning",
            "completion contracts add acceptance policy without changing ExecTrace",
            "proposal workflows may suggest patches but validation and person gates apply them",
        ],
        "stages": stages,
        "risks": risks,
        "rejectedAlternatives": [
            "Do not parse Taskmaster JSON into RawProgram or Plan.",
            "Do not add dependency readiness as a new Plan level.",
            "Do not persist ExecTrace as mutable Controller state.",
            "Do not add framework-specific provider, MCP, editor, or cloud layers.",
            "Do not implement collaboration or workstream tags before a semantic requirement exists.",
        ],
        "decisions": [
            {"question": "First repository adapter?", "recommendedDefault": "Keep obr outside the semantic core."},
            {"question": "Certificate payload?", "recommendedDefault": "Store evidence digests plus an optional explicitly retained transcript reference."},
        ],
        "recommendations": recommendations,
        "license": {
            "basis": "MIT plus Commons Clause",
            "restrictionScope": "selling the Software as defined by the license",
            "legalAdvice": False,
            "implementationCodeCopied": False,
        },
    }


def answer_for(wire_text):
    text = (
        wire_text.split("]\n\n", 1)[1]
        if wire_text.startswith("[question for ") and "]\n\n" in wire_text
        else wire_text
    )
    if text.startswith("Read the canonical evidence manifest"):
        if MODE in {"repair-inventory", "fail-inventory"}:
            return "{}"
        return json.dumps(inventory(tagged(text, "evidence")), separators=(",", ":"), sort_keys=True)
    if text.startswith("From the validated evidence manifest"):
        if MODE in {"repair-design", "fail-design"}:
            return "{}"
        return json.dumps(design(tagged(text, "evidence")), separators=(",", ":"), sort_keys=True)
    if text.startswith("Audit the validated design"):
        if MODE in {"repair-audit", "fail-audit"}:
            return "{}"
        return '{"complete":true,"findings":[],"status":"complete","version":1}'
    if text.startswith("Return corrected design JSON"):
        if MODE in {"repair-revision", "fail-revision"}:
            return "{}"
        return json.dumps(tagged(text, "design"), separators=(",", ":"), sort_keys=True)
    if text.startswith("The JSON below failed"):
        if "Schema: inventory" in text:
            if MODE == "fail-inventory":
                return "{}"
            return json.dumps(inventory(tagged(text, "evidence")), separators=(",", ":"), sort_keys=True)
        if "Schema: design" in text:
            if MODE == "fail-design":
                return "{}"
            return json.dumps(design(tagged(text, "evidence")), separators=(",", ":"), sort_keys=True)
        if "Schema: audit" in text:
            if MODE == "fail-audit":
                return "{}"
            return '{"complete":true,"findings":[],"status":"complete","version":1}'
        if "Schema: revision" in text:
            if MODE == "fail-revision":
                return "{}"
            return json.dumps(design(tagged(text, "evidence")), separators=(",", ":"), sort_keys=True)
    raise RuntimeError("fixture received an unknown prompt")


def handle_prompt(identifier, params):
    if params.get("sessionId") != SESSION_ID:
        error(identifier, -32602, "unknown session")
        return
    reply = answer_for(prompt_text(params))
    midpoint = len(reply) // 2
    for chunk in [reply[:midpoint], reply[midpoint:]]:
        update({
            "sessionUpdate": "agent_message_chunk",
            "content": {"type": "text", "text": chunk},
            "messageId": "taskmaster-fixture-message",
        })
    result(identifier, {
        "stopReason": "end_turn",
        "usage": {
            "inputTokens": 1,
            "outputTokens": 1,
            "cachedReadTokens": 0,
            "cachedWriteTokens": 0,
            "totalTokens": 2,
        },
    })


def main():
    for line in sys.stdin:
        if not line.strip():
            continue
        message = json.loads(line)
        method = message.get("method")
        identifier = message.get("id")
        if identifier is None:
            continue
        params = message.get("params", {})
        if method == "initialize":
            result(identifier, {
                "protocolVersion": PROTOCOL_VERSION,
                "agentCapabilities": {
                    "promptCapabilities": {"image": False, "embeddedContext": False},
                    "mcpCapabilities": {"http": False, "sse": False},
                    "loadSession": False,
                    "sessionCapabilities": {},
                },
                "agentInfo": {"name": "taskmaster-fixture", "title": "Taskmaster Fixture", "version": "1.0.0"},
                "authMethods": [],
            })
        elif method == "session/new":
            result(identifier, {"sessionId": SESSION_ID, "modes": MODES, "configOptions": CONFIG_OPTIONS})
        elif method == "session/set_mode":
            result(identifier, {})
        elif method == "session/set_config_option":
            config_id = params.get("configId")
            for option in CONFIG_OPTIONS:
                if option["id"] == config_id:
                    option["currentValue"] = params.get("value")
            result(identifier, {"configOptions": CONFIG_OPTIONS})
        elif method == "session/prompt":
            handle_prompt(identifier, params)
        else:
            error(identifier, -32601, f"method not found: {method}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
