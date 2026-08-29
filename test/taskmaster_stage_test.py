#!/usr/bin/env python3
import copy
import hashlib
import json
import re
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).parents[1]
TOOL = ROOT / "tools" / "wf-taskmaster-stage"
GOLDEN = ROOT / "test" / "taskmaster_report_golden.md"
CATEGORIES = [
    "task-structure-dependencies", "decomposition", "research", "execution-loops",
    "workflow-state", "storage-persistence", "interfaces", "providers",
    "tags-workstreams", "collaboration",
]


def fixture():
    evidence = []
    for index, category in enumerate(CATEGORIES):
        evidence.append({
            "id": f"tm-{index}", "category": category, "classification": "verified",
            "claim": f"Taskmaster {category}", "repository": "taskmaster", "path": "src.ts",
            "start": index + 1, "end": index + 1, "excerpt": f"tm {category}\n",
            "excerptSha256": hashlib.sha256(f"tm {category}\n".encode()).hexdigest(),
        })
        evidence.append({
            "id": f"ac-{index}", "category": category, "classification": "verified",
            "claim": f"agent-cat {category}", "repository": "agent-cat", "path": "Agent.hs",
            "start": index + 1, "end": index + 1, "excerpt": f"ac {category}\n",
            "excerptSha256": hashlib.sha256(f"ac {category}\n".encode()).hexdigest(),
        })
    evidence.append({
        "id": "tm-license", "category": "license-provenance", "classification": "verified",
        "claim": "Taskmaster license", "repository": "taskmaster", "path": "LICENSE",
        "start": 1, "end": 2, "excerpt": "license\n", "excerptSha256": hashlib.sha256(b"license\n").hexdigest(),
    })
    manifest = {
        "version": 1,
        "repositories": {
            "taskmaster": {"url": "https://github.com/eyaltoledano/claude-task-master", "revision": "1" * 40, "tree": "2" * 40},
            "agent-cat": {"url": "https://github.com/jwiegley/agent-cat", "revision": "3" * 40, "tree": "4" * 40},
        },
        "requiredCategories": CATEGORIES + ["license-provenance"],
        "evidence": evidence,
    }
    inventory = {
        "version": 1, "status": "complete",
        "upstream": [{"category": c, "summary": f"Taskmaster {c}", "evidenceIds": [f"tm-{i}"]} for i, c in enumerate(CATEGORIES)],
        "agentCat": [{"category": c, "summary": f"agent-cat {c}", "evidenceIds": [f"ac-{i}"]} for i, c in enumerate(CATEGORIES)],
    }
    checks = [
        "lake build", "nix develop path:./. -c cabal build all", "./ci/tier0.sh",
        "./ci/examples.sh", "./ci/acp.sh", "./ci/deck.sh", "./ci/citations.sh",
    ]
    design = {
        "version": 1, "status": "complete",
        "executiveDecision": "Build a separate FrameworkSpec DAG and controller.",
        "mappings": [{
            "category": c, "disposition": "ADAPT", "agentCatOwner": "FrameworkSpec",
            "interpretation": f"Map {c} without changing Plan.", "evidenceIds": [f"tm-{i}", f"ac-{i}"],
        } for i, c in enumerate(CATEGORIES)],
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
            "principalObject": "FrameworkSpec is a finite DAG outside Plan.",
            "representationTower": ["Spec", "Controller", "ExecTrace evidence", "RunCertificate"],
            "laws": ["Acyclic", "Ready iff prerequisites complete", "Plan unchanged", "Trace is evidence", "Completion needs certificate"],
        },
        "lifecycle": ["validate", "select ready", "claim", "execute", "accept", "complete", "persist", "repeat"],
        "failures": ["invalid graph", "no-ready deadlock", "transport failure", "tool failure", "failed acceptance", "retry exhaustion", "persistence failure", "crash replay"],
        "extensionPoints": ["Registry rows", "repository adapter", "completion contract", "proposal workflow"],
        "stages": [{
            "id": f"stage-{i+1}", "files": [f"File{i+1}.hs"],
            "behavior": f"Observable behavior {i+1}", "check": checks[i],
        } for i in range(7)],
        "risks": [{"risk": f"Risk {i+1}", "mitigation": f"Mitigation {i+1}"} for i in range(6)],
        "rejectedAlternatives": ["Reject alternative one", "Reject alternative two", "Reject alternative three", "Reject alternative four"],
        "decisions": [{"question": "Which adapter?", "recommendedDefault": "obr outside core"}],
        "recommendations": [{
            "id": f"R{i+1}", "recommendation": f"Recommendation {i+1}",
            "evidenceIds": [f"tm-{i}", f"ac-{i}"], "check": checks[i % len(checks)],
        } for i in range(10)],
        "license": {
            "basis": "MIT plus Commons Clause",
            "restrictionScope": "selling the Software as defined by the license",
            "legalAdvice": False,
            "implementationCodeCopied": False,
        },
    }
    audit = {"version": 1, "status": "complete", "complete": True, "findings": []}
    return manifest, inventory, design, audit


def run_tool(action, schema, value):
    command = [str(TOOL), action]
    if schema:
        command.append(schema)
    return subprocess.run(command, input=json.dumps(value), text=True, capture_output=True)


class StageTest(unittest.TestCase):
    def test_inventory_schema(self):
        _, inventory, _, _ = fixture()
        result = run_tool("canonical", "inventory", inventory)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout), inventory)

    def test_inventory_rejects_missing_category(self):
        _, inventory, _, _ = fixture()
        inventory["upstream"].pop()
        result = run_tool("review", "inventory", inventory)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("at least 10", result.stderr)

    def test_design_schema_and_real_commands(self):
        _, _, design, _ = fixture()
        self.assertEqual(run_tool("canonical", "design", design).returncode, 0)
        design["stages"][0]["check"] = "made-up test"
        result = run_tool("review", "design", design)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unsupported command", result.stderr)

    def test_design_rejects_architecture_boundary_violation(self):
        _, _, design, _ = fixture()
        design["architecture"]["planChanged"] = True
        result = run_tool("review", "design", design)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("invalid boundary value", result.stderr)

    def test_design_rejects_shallow_acceptance(self):
        _, _, design, _ = fixture()
        design["stages"][0]["behavior"] = "passes"
        result = run_tool("review", "design", design)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("too shallow", result.stderr)

        _, _, design, _ = fixture()
        for stage in design["stages"]:
            stage["check"] = "lake build"
        result = run_tool("review", "design", design)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("five distinct real checks", result.stderr)

    def test_audit_schema(self):
        _, _, _, audit = fixture()
        self.assertEqual(run_tool("canonical", "audit", audit).returncode, 0)
        audit["findings"].append({"severity": "high", "category": "evidence", "message": "bad", "evidenceIds": ["tm-0"]})
        result = run_tool("review", "audit", audit)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("true requires no findings", result.stderr)

    def test_renderer_matches_golden(self):
        manifest, inventory, design, _ = fixture()
        result = run_tool("render", None, {"manifest": manifest, "inventory": inventory, "design": design})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, GOLDEN.read_text())
        self.assertEqual(re.findall(r"(?m)^## .+$", result.stdout), [
            "## 1. Status and provenance",
            "## 2. Executive decision",
            "## 3. Verified Taskmaster capability inventory",
            "## 4. Existing agent-cat capability inventory",
            "## 5. Capability map",
            "## 6. Minimum framework semantics and representation tower",
            "## 7. Lifecycle, failure, persistence, and extension boundaries",
            "## 8. Ordered implementation plan with acceptance checks",
            "## 9. Risks, license/provenance constraints, and rejected alternatives",
            "## 10. Open owner decisions",
            "## 11. Verification matrix",
        ])
        lines = result.stdout.splitlines()
        self.assertEqual(sum(any(line.startswith(f"| {category} |") for category in CATEGORIES) for line in lines), 10)
        self.assertEqual(len(re.findall(r"(?m)^### Stage \d+:", result.stdout)), 7)
        self.assertEqual(result.stdout.count("**Recommendation — failure:**"), 8)
        self.assertEqual(result.stdout.count("- **Risk:**"), 6)
        self.assertEqual(len(re.findall(r"(?m)^\| R\d+ \|", result.stdout)), 10)
        self.assertIn("**Verified:**", result.stdout)
        self.assertIn("**Interpretation:**", result.stdout)
        self.assertIn("**Recommendation:**", result.stdout)

    def test_renderer_rejects_tampered_excerpt(self):
        manifest, inventory, design, _ = fixture()
        manifest["evidence"][0]["excerpt"] += "tampered"
        result = run_tool("render", None, {"manifest": manifest, "inventory": inventory, "design": design})
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("digest mismatch", result.stderr)

    def test_renderer_escapes_model_markdown(self):
        manifest, inventory, design, _ = fixture()
        inventory["upstream"][0]["summary"] = "evil | **bold**\nnext"
        result = run_tool("render", None, {"manifest": manifest, "inventory": inventory, "design": design})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(r"evil \| \*\*bold\*\* next", result.stdout)

    def test_renderer_labels_interpretive_evidence(self):
        manifest, inventory, design, _ = fixture()
        next(record for record in manifest["evidence"] if record["id"] == "ac-8")["classification"] = "interpretation"
        result = run_tool("render", None, {"manifest": manifest, "inventory": inventory, "design": design})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("- **Interpretation — tags-workstreams:**", result.stdout)

    def test_renderer_rejects_inventory_category_mismatch(self):
        manifest, inventory, design, _ = fixture()
        inventory["upstream"][0]["evidenceIds"] = ["tm-1"]
        result = run_tool("render", None, {"manifest": manifest, "inventory": inventory, "design": design})
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("wrong-category evidence", result.stderr)

    def test_renderer_rejects_mapping_category_mismatch(self):
        manifest, inventory, design, _ = fixture()
        design["mappings"][0]["evidenceIds"] = ["tm-1", "ac-1"]
        result = run_tool("render", None, {"manifest": manifest, "inventory": inventory, "design": design})
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("wrong-category evidence", result.stderr)

    def test_renderer_rejects_one_sided_mapping_evidence(self):
        manifest, inventory, design, _ = fixture()
        design["mappings"][0]["evidenceIds"] = ["tm-0"]
        result = run_tool("render", None, {"manifest": manifest, "inventory": inventory, "design": design})
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("expected upstream and agent-cat evidence", result.stderr)

    def test_renderer_rejects_unknown_evidence(self):
        manifest, inventory, design, _ = fixture()
        design = copy.deepcopy(design)
        design["recommendations"][0]["evidenceIds"] = ["missing"]
        result = run_tool("render", None, {"manifest": manifest, "inventory": inventory, "design": design})
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unknown evidence", result.stderr)


if __name__ == "__main__":
    unittest.main()
