#!/usr/bin/env python3
import hashlib
import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

MODULE_PATH = Path(__file__).parents[1] / "tools" / "taskmaster-evidence.py"
SPEC = importlib.util.spec_from_file_location("taskmaster_evidence", MODULE_PATH)
assert SPEC and SPEC.loader
EVIDENCE = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = EVIDENCE
SPEC.loader.exec_module(EVIDENCE)


class EvidenceTest(unittest.TestCase):
    def make_repo(self) -> tuple[tempfile.TemporaryDirectory, Path, str]:
        temporary = tempfile.TemporaryDirectory()
        repo = Path(temporary.name)
        subprocess.run(["git", "init", "-q", str(repo)], check=True)
        subprocess.run(["git", "-C", str(repo), "config", "user.email", "test@example.invalid"], check=True)
        subprocess.run(["git", "-C", str(repo), "config", "user.name", "Test"], check=True)
        (repo / "sample.txt").write_text("alpha\nbeta\ngamma\n")
        subprocess.run(["git", "-C", str(repo), "add", "sample.txt"], check=True)
        subprocess.run(["git", "-C", str(repo), "commit", "-qm", "fixture"], check=True)
        revision = subprocess.check_output(["git", "-C", str(repo), "rev-parse", "HEAD"], text=True).strip()
        return temporary, repo, revision

    def test_repository_identity_is_pinned_and_clean(self):
        temporary, repo, revision = self.make_repo()
        self.addCleanup(temporary.cleanup)
        identity = EVIDENCE.repository_identity(repo, revision)
        self.assertEqual(identity["revision"], revision)
        self.assertEqual(len(identity["tree"]), 40)

    def test_repository_identity_rejects_revision_mismatch(self):
        temporary, repo, _ = self.make_repo()
        self.addCleanup(temporary.cleanup)
        with self.assertRaisesRegex(EVIDENCE.EvidenceError, "revision mismatch"):
            EVIDENCE.repository_identity(repo, "0" * 40)

    def test_repository_identity_rejects_dirty_checkout(self):
        temporary, repo, revision = self.make_repo()
        self.addCleanup(temporary.cleanup)
        (repo / "sample.txt").write_text("changed\n")
        with self.assertRaisesRegex(EVIDENCE.EvidenceError, "checkout is dirty"):
            EVIDENCE.repository_identity(repo, revision)

    def test_excerpt_rejects_symlink(self):
        temporary, repo, _ = self.make_repo()
        self.addCleanup(temporary.cleanup)
        (repo / "alias.txt").symlink_to("sample.txt")
        spec = EVIDENCE.EvidenceSpec("sample", "research", "taskmaster", "alias.txt", 1, 1, "claim")
        with self.assertRaisesRegex(EVIDENCE.EvidenceError, "symlinked evidence path"):
            EVIDENCE.collect_excerpt(repo, spec)

    def test_excerpt_rejects_checkout_escape(self):
        temporary, repo, _ = self.make_repo()
        self.addCleanup(temporary.cleanup)
        outside = repo.parent / f"{repo.name}-outside.txt"
        outside.write_text("outside\n")
        self.addCleanup(outside.unlink)
        spec = EVIDENCE.EvidenceSpec("sample", "research", "taskmaster", f"../{outside.name}", 1, 1, "claim")
        with self.assertRaisesRegex(EVIDENCE.EvidenceError, "escapes checkout"):
            EVIDENCE.collect_excerpt(repo, spec)

    def test_excerpt_is_exact_and_hashed(self):
        temporary, repo, _ = self.make_repo()
        self.addCleanup(temporary.cleanup)
        spec = EVIDENCE.EvidenceSpec("sample", "research", "taskmaster", "sample.txt", 2, 3, "claim")
        record = EVIDENCE.collect_excerpt(repo, spec)
        self.assertEqual(record["excerpt"], "beta\ngamma\n")
        self.assertEqual(record["excerptSha256"], hashlib.sha256(b"beta\ngamma\n").hexdigest())

    def test_excerpt_rejects_invalid_range(self):
        temporary, repo, _ = self.make_repo()
        self.addCleanup(temporary.cleanup)
        spec = EVIDENCE.EvidenceSpec("sample", "research", "taskmaster", "sample.txt", 2, 4, "claim")
        with self.assertRaisesRegex(EVIDENCE.EvidenceError, "invalid range"):
            EVIDENCE.collect_excerpt(repo, spec)

    def test_excerpt_rejects_broad_range(self):
        temporary, repo, _ = self.make_repo()
        self.addCleanup(temporary.cleanup)
        path = repo / "broad.txt"
        path.write_text("".join(f"line {index}\n" for index in range(EVIDENCE.MAX_EXCERPT_LINES + 1)))
        spec = EVIDENCE.EvidenceSpec(
            "broad", "research", "taskmaster", path.name, 1, EVIDENCE.MAX_EXCERPT_LINES + 1, "claim"
        )
        with self.assertRaisesRegex(EVIDENCE.EvidenceError, "broad evidence range"):
            EVIDENCE.collect_excerpt(repo, spec)

    def test_reviewed_specs_are_narrow(self):
        self.assertTrue(
            all(spec.end - spec.start + 1 <= EVIDENCE.MAX_EXCERPT_LINES for spec in EVIDENCE.SPECS)
        )

    def test_required_category_validation(self):
        with self.assertRaisesRegex(EVIDENCE.EvidenceError, "missing evidence categories"):
            EVIDENCE.validate_categories([{"category": "research"}])
        EVIDENCE.validate_categories(
            [{"category": category} for category in EVIDENCE.REQUIRED_CATEGORIES]
        )

    def test_canonical_json_is_stable(self):
        left = EVIDENCE.canonical_json({"b": [2, 1], "a": "x"})
        right = EVIDENCE.canonical_json({"a": "x", "b": [2, 1]})
        self.assertEqual(left, right)
        self.assertEqual(json.loads(left), {"a": "x", "b": [2, 1]})
        self.assertTrue(left.endswith("\n"))


if __name__ == "__main__":
    unittest.main()
