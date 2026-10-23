#!/usr/bin/env python3
"""Reproduce packaged translation guidance from an authoritative translate-tool tree."""

import argparse
import ast
import hashlib
import json
from pathlib import Path
import re
import subprocess


ROLES = (
    "diction-grammar",
    "beauty-eloquence",
    "clarity-accessibility",
    "se-conventions",
    "back-translator",
    "oral-spiritual",
)


def snapshot(source: Path) -> dict[str, bytes]:
    paths = ("translate.py", "skill/SKILL.md", "glossary.csv")
    originals = {path: (source / path).read_bytes() for path in paths}
    module = ast.parse(originals["translate.py"].decode("utf-8"))
    prompt = next(
        ast.literal_eval(node.value)
        for node in module.body
        if isinstance(node, ast.Assign)
        and any(isinstance(target, ast.Name) and target.id == "SYSTEM_PROMPT" for target in node.targets)
    )
    register = prompt.split("## Mandatory Terminology", 1)[0].strip()
    # The quoted passages survive verbatim; unsupported numerical claims do not.
    register = register.replace("Exactly 35 words — densely packed, no padding.", "Densely packed, without padding.")
    register = register.replace('80+ words vs. 35. "Primaeval", "sempiternal", "pulchritude" are overwrought.', 'The phrasing is over-expanded. "Primaeval" and "sempiternal" are overwrought.')
    register = register.replace('"Crucible of creation" and "sanctified gaze" fabricate content not in the source.', '"Crucible of creation" fabricates content not in the source.')
    register += "\n\nConcision never licenses an omission. Cross-language word counts are not a fidelity test. Preserve sound initial choices unless a concrete defect requires correction.\n"
    skill = originals["skill/SKILL.md"].decode("utf-8")
    reviewers = {}
    for index, role in enumerate(ROLES, 1):
        match = re.search(rf"\*\*Reviewer {index}: `{re.escape(role)}`\*\*\s*```\s*(.*?)```", skill, re.S)
        if match is None:
            raise ValueError(f"missing reviewer mandate: {role}")
        mandate = match.group(1).split("SOURCE TEXT:", 1)[0].strip()
        if role == "back-translator":
            mandate = (
                "A separate source-hidden call has already back-translated the English candidate. "
                "Compare that supplied back-translation with the original. Do not replace it with a reconstruction informed by the source.\n\n"
                + mandate.split("STEP 3: ", 1)[1]
            )
        reviewers[role] = mandate
    revision = subprocess.check_output(
        ["git", "--no-optional-locks", "-C", str(source), "log", "-1", "--format=%H", "--", *paths], text=True
    ).strip()
    provenance = {
        "version": 1,
        "sourceRepository": "translate-tool",
        "revision": revision,
        "files": {path: hashlib.sha256(data).hexdigest() for path, data in originals.items()},
        "generatorSha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        "adaptations": [
            "Remove incorrect calibration counts and commentary about absent quoted words.",
            "Make concision subordinate to coverage and defect-driven revision.",
            "Give the fidelity reviewer a separately produced source-hidden back-translation.",
            "Use workflow-owned structured response contracts instead of interpolated skill placeholders.",
        ],
    }
    encode = lambda value: (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
    assets = {
        "register.md": register.encode("utf-8"),
        "reviewers.json": encode(reviewers),
        "glossary.csv": originals["glossary.csv"],
    }
    provenance["assets"] = {name: hashlib.sha256(data).hexdigest() for name, data in assets.items()}
    assets["provenance.json"] = encode(provenance)
    return assets


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="authoritative translate-tool checkout")
    parser.add_argument("--check", action="store_true", help="verify packaged assets without changing them")
    args = parser.parse_args()
    destination = Path(__file__).resolve().parent.parent / "assets" / "translate-en"
    expected = snapshot(args.source.resolve())
    if args.check:
        changed = [name for name, data in expected.items() if not (destination / name).is_file() or (destination / name).read_bytes() != data]
        if changed:
            raise SystemExit("translation assets differ: " + ", ".join(changed))
        print("translation assets match their authoritative source and recorded adaptations")
    else:
        destination.mkdir(parents=True, exist_ok=True)
        for name, data in expected.items():
            (destination / name).write_bytes(data)
        print(f"wrote {len(expected)} translation assets to {destination}")


if __name__ == "__main__":
    main()
