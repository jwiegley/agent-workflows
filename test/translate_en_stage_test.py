#!/usr/bin/env python3
"""Deterministic contracts for translation stages, without model or network access."""

import copy
import hashlib
import importlib.machinery
import importlib.util
import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
import unittest
from unittest import mock
import zipfile

ROOT = Path(__file__).resolve().parent.parent
loader = importlib.machinery.SourceFileLoader("translate_stage", str(ROOT / "tools" / "wf-translate-stage"))
spec = importlib.util.spec_from_loader(loader.name, loader)
stage = importlib.util.module_from_spec(spec)
loader.exec_module(stage)

ARABIC = "يا أهل العالم اسلكوا سبيل العدل."
PERSIAN = "ای دوست، در راه عدل گام بردار."
ENGLISH = "O peoples of the world! Walk in the path of justice."


def document(source=ARABIC):
    return stage.prepare({"file": "", "text": source, "independentBackTranslation": True})


def prepared(doc, fragment=False):
    context = stage.section(doc)
    return stage.accept("brief", context, {
        "languages": [{"id": u["id"], "language": "Persian" if "ای دوست" in u["source"] else "Arabic"} for u in context["units"]],
        "terminology": [{"term": term["term"], "applications": [{"unitId": unit_id, "applies": True, "reason": "The term is applicable in this source."} for unit_id in term["unitIds"]]} for term in context["termCandidates"]],
        "sentenceFragment": fragment, "fragmentReason": "A vocative phrase, not a complete sentence." if fragment else "",
    })


def draft(context, text=ENGLISH):
    return stage.accept("draft", context, {"units": [{"id": u["id"], "text": text} for u in context["units"]]})


def review_body(context, issue=None):
    return "".join(
        f"<{role}>\n" + json.dumps({
            "status": "reviewed", "issues": [issue] if issue and role == "back-translator" else [],
            "scores": {score: 8 for score in stage.SCORES[role]},
            "strengths": ["Concise wording."], "summary": "No issues." if not issue else "See findings.",
        }) + f"\n</{role}>\n" for role in stage.ROLES
    )


def reviewed(context, round_name, issue=None):
    back = {"units": [{"id": u["id"], "text": u["source"]} for u in context["units"]]}
    context = stage.accept("back-" + round_name, context, back)
    return stage.accept_reviews(round_name, context, review_body(context, issue))


def synthesize(context, round_name, action="accept"):
    return stage.accept("synthesis-" + round_name, context, {
        "units": context["candidate"],
        "decisions": [{"issueId": issue["id"], "action": action, "reason": "Evidence-based disposition."}
                      for review in context["history"]["reviews-" + round_name].values() for issue in review["issues"]],
        "notes": [],
    })


def verified(doc):
    context = draft(prepared(doc))
    context = synthesize(reviewed(context, "one"), "one")
    context = synthesize(reviewed(context, "two"), "two")
    return stage.accept("verify", context, {"edits": []})


class TranslationStages(unittest.TestCase):
    def test_unicode_mixed_paragraphs_and_alignment(self):
        doc = document(ARABIC + "\r\n \t\r\n" + PERSIAN)
        self.assertEqual(len(doc["paragraphs"]), 2)
        context = prepared(doc)
        self.assertEqual([x["language"] for x in context["brief"]["languages"]], ["Arabic", "Persian"])
        complete = stage.append(doc, verified(doc))
        self.assertEqual(stage.final_text(complete).count("\n\n"), 1)
        self.assertNotIn("Quality notes", stage.final_text(complete))

    def test_empty_ambiguous_and_non_source_inputs(self):
        for file, text in (("", ""), ("source.txt", ARABIC), ("", " \n "), ("", "English only")):
            with self.subTest(file=file, text=text), self.assertRaises(stage.Invalid):
                stage.prepare({"file": file, "text": text, "independentBackTranslation": True})

    def test_missing_unsupported_invalid_utf8_and_nonregular(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name, data in (("input.pdf", b"pdf"), ("input.txt", b"\xff"), ("input.docx", b"invalid zip")):
                path = root / name
                path.write_bytes(data)
                with self.subTest(name=name), self.assertRaises((ValueError, zipfile.BadZipFile)):
                    stage.read_source(path)
            with self.assertRaises(FileNotFoundError):
                stage.read_source(root / "missing.txt")
            with self.assertRaises((OSError, stage.Invalid)):
                stage.read_source(root)

    def test_txt_bom_and_docx_tables_in_document_order(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "source.txt"
            source.write_bytes(("\ufeff" + ARABIC).encode())
            self.assertEqual(stage.read_source(source), ARABIC)
            docx = root / "source.docx"
            xml = f'<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>{ARABIC}</w:t></w:r></w:p><w:tbl><w:tr><w:tc><w:p><w:r><w:t>{PERSIAN}</w:t></w:r></w:p></w:tc></w:tr></w:tbl></w:body></w:document>'
            with zipfile.ZipFile(docx, "w") as archive:
                archive.writestr("word/document.xml", xml)
            self.assertEqual(stage.read_source(docx), ARABIC + "\n\n" + PERSIAN)

    def test_docx_unsupported_content_never_silently_disappears(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "source.docx"
            for tag in ("drawing", "footnoteReference", "ins", "txbxContent", "numPr", "headerReference", "footerReference"):
                with zipfile.ZipFile(path, "w") as archive:
                    archive.writestr("word/document.xml", f'<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:{tag}/></w:p></w:body></w:document>')
                with self.subTest(tag=tag), self.assertRaisesRegex(stage.Invalid, "nothing was omitted"):
                    stage.read_source(path)

    def test_natural_long_segmentation_preserves_paragraph_and_text(self):
        source = ("هذا نص طويل. " * 800).strip() + "\n\n" + PERSIAN
        paragraphs, sections = stage.partition(source)
        self.assertGreater(len(sections), 1)
        rebuilt = [[] for _ in paragraphs]
        for section_ in sections:
            for unit in section_:
                rebuilt[unit["paragraph"] - 1].append(unit["source"])
        self.assertEqual([" ".join(p.split()) for p in paragraphs], [" ".join(" ".join(parts).split()) for parts in rebuilt])

    def test_limits_fail_before_models(self):
        with self.assertRaisesRegex(stage.Invalid, "natural boundary"):
            stage.partition("كلمة " * 4001)
        with self.assertRaisesRegex(stage.Invalid, "more than 64"):
            stage.partition("\n\n".join(["كلمة " * 2000] * 65))

    def test_phrase_exception_is_explicit_and_not_word_count_alone(self):
        self.assertFalse(prepared(document("سر في الطريق"))["short"])
        context = prepared(document("ای دوست"), fragment=True)
        self.assertTrue(context["short"])
        doc = document("ای دوست")
        context = draft(prepared(doc, fragment=True), "O friend")
        context = stage.accept("verify", context, {"edits": []})
        stage.append(doc, context)
        self.assertIn("specialist review was skipped", stage.quality_notes(doc))
        self.assertFalse(prepared(document(ARABIC), fragment=True)["short"])

    def test_glossary_normalization_and_boundaries(self):
        self.assertTrue(stage.term_matches("هُوَ الْعَلِيمُ", "عليم"))
        self.assertTrue(stage.term_matches("ملکوت", "ملكوت"))
        self.assertFalse(stage.term_matches("روحانی", "روح"))
        context = draft(prepared(document("عدل")), "Justice")
        self.assertEqual(stage.mechanical_errors(context), [])
        context["candidate"][0]["text"] = "Fairness"
        self.assertIn("missing mandatory", stage.mechanical_errors(context)[0])

    def test_conditional_glossary_and_alternatives(self):
        doc = document("باب")
        context = stage.section(doc)
        brief = {"languages": [{"id": context["units"][0]["id"], "language": "Arabic"}],
                 "terminology": [{"term": context["termCandidates"][0]["term"], "applications": [{"unitId": context["units"][0]["id"], "applies": False, "reason": "A door, not the person."}]}],
                 "sentenceFragment": True, "fragmentReason": "A noun."}
        context = draft(stage.accept("brief", context, brief), "A door")
        self.assertFalse(stage.mechanical_errors(context))
        context = draft(prepared(document("وجود")), "existence")
        self.assertFalse(stage.mechanical_errors(context))

    def test_back_translation_prompt_has_no_source_or_glossary(self):
        context = draft(prepared(document()))
        prompt = stage.prompt("back-one", context)
        self.assertNotIn(ARABIC, prompt)
        self.assertNotIn("fullGlossary", prompt)
        self.assertNotIn("termCandidates", prompt)
        self.assertIn(ENGLISH, prompt)
        self.assertIn("Arabic", prompt)

    def test_two_rounds_and_prior_feedback_flow(self):
        context = draft(prepared(document()))
        context = synthesize(reviewed(context, "one"), "one")
        context = stage.accept("back-two", context, {"units": [{"id": context["units"][0]["id"], "text": ARABIC}]})
        prompt = stage.review_prompt("two", "diction-grammar", context)
        self.assertIn('"previousReview"', prompt)
        self.assertIn('"previousDecisions"', prompt)
        context = stage.accept_reviews("two", context, review_body(context))
        self.assertEqual(set(context["history"]["reviews-two"]), set(stage.ROLES))

    def test_missing_empty_and_malformed_reviews_fail(self):
        context = draft(prepared(document()))
        context = stage.accept("back-one", context, {"units": [{"id": context["units"][0]["id"], "text": ARABIC}]})
        body = review_body(context)
        for invalid in ("", body.replace('<diction-grammar>\n', '<diction-grammar>\nno JSON'), body.split('<oral-spiritual>')[0]):
            with self.subTest(invalid=invalid[:30]), self.assertRaises(ValueError):
                stage.accept_reviews("one", copy.deepcopy(context), invalid)

    def test_missing_duplicate_and_reordered_units_fail(self):
        context = prepared(document(ARABIC + "\n\n" + PERSIAN))
        units = [{"id": u["id"], "text": ENGLISH} for u in context["units"]]
        for candidate in (units[:1], units[::-1], [units[0], units[0]]):
            with self.assertRaises(stage.Invalid):
                stage.accept("draft", copy.deepcopy(context), {"units": candidate})

    def test_normal_text_cannot_skip_review(self):
        context = draft(prepared(document()))
        with self.assertRaisesRegex(stage.Invalid, "cannot skip"):
            stage.accept("verify", context, {"edits": []})

    def test_valid_verifier_must_preserve_text(self):
        context = synthesize(reviewed(synthesize(reviewed(draft(prepared(document())), "one"), "one"), "two"), "two")
        with self.assertRaisesRegex(stage.Invalid, "unauthorized edit"):
            stage.accept("verify", context, {"edits": [{"id": "invented", "replacement": "Verily."}]})
        self.assertEqual(stage.accept("verify", context, {"edits": []})["candidate"][0]["text"], ENGLISH)

    def test_verification_failure_and_unresolved_critical_are_honest(self):
        context = draft(prepared(document()), "Walk in your path of justice.")
        context = synthesize(reviewed(context, "one"), "one")
        issue = {"unitId": context["units"][0]["id"], "current": "", "suggested": "", "reason": "Meaning has been lost.", "severity": "critical"}
        context = synthesize(reviewed(context, "two", issue), "two", action="reject")
        with self.assertRaisesRegex(stage.Invalid, "unresolved critical"):
            stage.accept("verify", context, {"edits": [{"id": stage.repair_options(context)[0]["id"], "replacement": "thy"}]})

    def test_synthesis_must_address_every_issue(self):
        context = draft(prepared(document()))
        issue = {"unitId": context["units"][0]["id"], "current": "Walk", "suggested": "Tread", "reason": "An example finding.", "severity": "minor"}
        context = reviewed(context, "one", issue)
        with self.assertRaisesRegex(stage.Invalid, "every reviewer issue"):
            stage.accept("synthesis-one", context, {"units": context["candidate"], "decisions": [], "notes": []})

    def test_payload_cannot_replace_context_with_duplicate_fields(self):
        with self.assertRaisesRegex(stage.Invalid, "duplicate JSON"):
            stage.one_json('{"units":[],"units":[1]}')
        with self.assertRaisesRegex(stage.Invalid, "extra content"):
            stage.one_json('{} {"phase":"verified"}')
        with self.assertRaises(stage.Invalid):
            stage.one_json('{"value":NaN}')

    def test_publish_is_private_separate_and_no_clobber(self):
        doc = document(ARABIC + "\n\n" + PERSIAN)
        stage.append(doc, verified(doc))
        with tempfile.TemporaryDirectory() as directory:
            previous = Path.cwd()
            try:
                os.chdir(directory)
                stage.publish(doc)
                target = Path(doc["outputDirectory"])
                translation = (target / "translation.txt").read_text()
                self.assertEqual(translation, stage.final_text(doc))
                self.assertNotIn("Quality notes", translation)
                self.assertEqual(stat.S_IMODE((target / "translation.txt").stat().st_mode), 0o600)
                self.assertTrue((target / "quality-notes.txt").is_file())
                manifest = json.loads((target / "manifest.json").read_text())
                self.assertEqual(manifest["paragraphs"], 2)
                with self.assertRaises(FileExistsError):
                    stage.publish(doc)
                self.assertEqual((target / "translation.txt").read_text(), translation)
            finally:
                os.chdir(previous)

    def test_progress_exhaustion_and_context_isolation(self):
        doc = document()
        with self.assertRaisesRegex(stage.Invalid, "sections remain"):
            stage.dispatch("progress", [], stage.dump(doc))
        with self.assertRaisesRegex(stage.Invalid, "bound exhausted"):
            stage.dispatch("exhausted", [], stage.dump(doc))
        doc["independentBackTranslation"] = False
        with self.assertRaisesRegex(stage.Invalid, "shares source context"):
            stage.dispatch("independent", [], stage.dump(doc))
        with self.assertRaises(stage.Invalid):
            stage.append(doc, verified(doc))

    def test_native_short_predicate_uses_exit_status(self):
        for source, fragment, expected in ((ARABIC, False, 1), ("ای دوست", True, 0)):
            context = prepared(document(source), fragment=fragment)
            reply = subprocess.run(
                [sys.executable, str(ROOT / "tools" / "wf-translate-stage"), "short"],
                input="TRANSLATE_EN short\n" + stage.dump(context), text=True, capture_output=True, check=False,
            )
            self.assertEqual(reply.returncode, expected, reply.stderr)

    def test_extra_terminology_entry_is_not_ignored(self):
        doc = document()
        brief = prepared(doc)["brief"]
        brief["terminology"].append(123)
        with self.assertRaisesRegex(stage.Invalid, "every detected glossary"):
            stage.accept("brief", stage.section(doc), brief)

    def test_long_document_assembly_checks_every_section(self):
        doc = document((ARABIC + " ") * 600)
        self.assertGreater(len(doc["sections"]), 1)
        while len(doc["completed"]) < len(doc["sections"]):
            context = prepared(doc)
            units = [{"id": u["id"], "text": " ".join([ENGLISH] * u["source"].count("."))} for u in context["units"]]
            context = stage.accept("draft", context, {"units": units})
            context = synthesize(reviewed(context, "one"), "one")
            context = synthesize(reviewed(context, "two"), "two")
            context = stage.accept("verify", context, {"edits": []})
            stage.append(doc, context)
        self.assertEqual(stage.final_text(doc).strip(), " ".join([ENGLISH] * 600))
        self.assertEqual(stage.dispatch("progress", [], stage.dump(doc)), "")

    def test_mandates_calibration_and_priority_reach_stages(self):
        context = prepared(document())
        draft_prompt = stage.prompt("draft", context)
        self.assertIn(stage.REGISTER, draft_prompt)
        self.assertIn("TOO ORNATE", draft_prompt)
        context = draft(context)
        context = stage.accept("back-one", context, {"units": [{"id": context["units"][0]["id"], "text": ARABIC}]})
        for role in stage.ROLES:
            prompt = stage.review_prompt("one", role, context)
            self.assertIn(stage.MANDATES[role], prompt)
            self.assertIn(stage.PRIORITY, prompt)
        context = stage.accept_reviews("one", context, review_body(context))
        self.assertIn(stage.PRIORITY, stage.prompt("synthesis-one", context))

    def test_all_consultations_stay_inside_the_native_stage(self):
        doc = document()
        context = prepared(doc)
        prompts = [stage.prompt("brief", stage.section(doc)), stage.prompt("draft", context)]
        context = draft(context)
        for round_name in ("one", "two"):
            prompts.append(stage.prompt("back-" + round_name, context))
            context = stage.accept("back-" + round_name, context, {
                "units": [{"id": u["id"], "text": u["source"]} for u in context["units"]],
            })
            prompts.extend(stage.review_prompt(round_name, role, context) for role in stage.ROLES)
            context = stage.accept_reviews(round_name, context, review_body(context))
            prompts.append(stage.prompt("synthesis-" + round_name, context))
            context = synthesize(context, round_name)
        prompts.append(stage.prompt("verify", context))
        self.assertEqual(len(prompts), 19)
        for instruction in (
            "one consultation in an already-running native translation workflow",
            "Do not load or invoke skills, call tools, delegate, or start another workflow",
            "Return exactly one JSON object, with no preamble, commentary or code fences",
        ):
            self.assertTrue(all(instruction in prompt for prompt in prompts), instruction)

    def test_model_prose_and_code_fences_are_not_json_answers(self):
        reply = stage.dump({"units": []})
        self.assertEqual(stage.one_json(reply), {"units": []})
        for contaminated in (
            "\n\nI'll start by invoking the relevant skill for this translation task.\n\n\n\n" + reply,
            "```json\n" + reply + "\n```",
            reply + "\nHere is the translation.",
        ):
            with self.subTest(reply=contaminated), self.assertRaises(ValueError):
                stage.one_json(contaminated)

    def test_conditional_glossary_is_per_source_unit(self):
        doc = document("حضرت باب\n\nالباب مفتوح.")
        context = prepared(doc)
        applications = context["brief"]["terminology"][0]["applications"]
        applications[1].update(applies=False, reason="An ordinary door, not the person.")
        context = stage.accept("brief", stage.section(doc), context["brief"])
        candidate = [{"id": u["id"], "text": text} for u, text in zip(context["units"], ["the Báb", "The door is open."])]
        context = stage.accept("draft", context, {"units": candidate})
        self.assertFalse(stage.mechanical_errors(context))
        context["candidate"][0]["text"] = "The door"
        self.assertEqual(len(stage.mechanical_errors(context)), 1)
        self.assertIn(context["units"][0]["id"], stage.mechanical_errors(context)[0])

    def test_terminology_applications_cannot_omit_or_duplicate_units(self):
        doc = document("باب\n\nباب")
        good = prepared(doc)["brief"]
        applications = good["terminology"][0]["applications"]
        for bad in (applications[:1], applications[::-1], [applications[0], applications[0]]):
            reply = copy.deepcopy(good)
            reply["terminology"][0]["applications"] = bad
            with self.assertRaisesRegex(stage.Invalid, "every matching source unit"):
                stage.accept("brief", stage.section(doc), reply)

    def test_pronoun_repairs_cannot_rewrite_unrelated_words(self):
        context = draft(prepared(document("ای دوست"), fragment=True), "You are my friend; I trust you and your wisdom.")
        options = stage.repair_options(context)
        choices = {"You are": "Thou art", "you": "thee", "your": "thy"}
        edits = [{"id": option["id"], "replacement": choices[option["current"]]} for option in options]
        altered = copy.deepcopy(edits)
        altered[0]["replacement"] = "Thou art my wise companion"
        with self.assertRaisesRegex(stage.Invalid, "unauthorized replacement"):
            stage.accept("verify", context, {"edits": altered})
        with self.assertRaisesRegex(stage.Invalid, "duplicate verification"):
            stage.accept("verify", context, {"edits": edits + edits[:1]})
        with self.assertRaisesRegex(stage.Invalid, "verification exhausted"):
            stage.accept("verify", context, {"edits": []})
        final = stage.accept("verify", context, {"edits": edits})
        self.assertEqual(final["candidate"][0]["text"], "Thou art my friend; I trust thee and thy wisdom.")

    def test_contraction_repairs_are_whole_and_case_preserving(self):
        context = draft(prepared(document("ای دوست"), fragment=True), "YOU'RE welcome; you’ve heard.")
        options = stage.repair_options(context)
        self.assertEqual([option["current"] for option in options], ["YOU'RE", "you’ve"])
        reply = {"edits": [{"id": option["id"], "replacement": option["replacements"][0]} for option in options]}
        self.assertEqual(stage.accept("verify", context, reply)["candidate"][0]["text"], "THOU ART welcome; thou hast heard.")

    def test_glossary_mismatch_is_not_repaired_by_free_paraphrase(self):
        context = draft(prepared(document("عدل"), fragment=True), "Fairness")
        with self.assertRaisesRegex(stage.Invalid, "verification exhausted.*mandatory rendering"):
            stage.accept("verify", context, {"edits": []})

    def test_publication_write_failure_exposes_no_final_bundle(self):
        doc = document()
        stage.append(doc, verified(doc))
        with tempfile.TemporaryDirectory() as directory:
            previous = Path.cwd()
            try:
                os.chdir(directory)
                with mock.patch.object(stage.os, "fsync", side_effect=[None, OSError("injected write failure")]):
                    with self.assertRaisesRegex(OSError, "injected write failure"):
                        stage.publish(doc)
                self.assertFalse(Path(doc["outputDirectory"]).exists())
                self.assertEqual(list(Path(".translate-en").iterdir()), [])
            finally:
                os.chdir(previous)

    def test_publication_refuses_symlink_root_and_existing_destination(self):
        doc = document()
        stage.append(doc, verified(doc))
        with tempfile.TemporaryDirectory() as directory:
            previous = Path.cwd()
            try:
                os.chdir(directory)
                outside = Path("outside")
                outside.mkdir()
                Path(".translate-en").symlink_to(outside, target_is_directory=True)
                with self.assertRaises(OSError):
                    stage.publish(doc)
                self.assertEqual(list(outside.iterdir()), [])
                Path(".translate-en").unlink()
                Path(".translate-en").mkdir(mode=0o700)
                destination = Path(doc["outputDirectory"])
                destination.mkdir()
                sentinel = destination / "keep.txt"
                sentinel.write_text("untouched")
                with self.assertRaises(FileExistsError):
                    stage.publish(doc)
                self.assertEqual(sentinel.read_text(), "untouched")
                self.assertEqual(list(Path(".translate-en").iterdir()), [destination])
            finally:
                os.chdir(previous)

    def test_publication_detects_root_replacement_at_commit(self):
        doc = document()
        stage.append(doc, verified(doc))
        with tempfile.TemporaryDirectory() as directory:
            previous = Path.cwd()
            real_symlink = stage.os.symlink
            def move_root(*args, **kwargs):
                Path(".translate-en").rename("old-root")
                Path(".translate-en").mkdir(mode=0o700)
                (Path(".translate-en") / "keep.txt").write_text("untouched")
                return real_symlink(*args, **kwargs)
            try:
                os.chdir(directory)
                with mock.patch.object(stage.os, "symlink", side_effect=move_root):
                    with self.assertRaisesRegex(stage.Invalid, "changed during publication"):
                        stage.publish(doc)
                self.assertEqual((Path(".translate-en") / "keep.txt").read_text(), "untouched")
                self.assertEqual(list(Path("old-root").iterdir()), [])
            finally:
                os.chdir(previous)

    def test_packaged_assets_match_their_recorded_hashes(self):
        provenance = json.loads((stage.ASSETS / "provenance.json").read_text(encoding="utf-8"))
        self.assertEqual(set(provenance["assets"]), {"register.md", "reviewers.json", "glossary.csv"})
        for name, expected in provenance["assets"].items():
            self.assertEqual(hashlib.sha256((stage.ASSETS / name).read_bytes()).hexdigest(), expected)
        self.assertEqual(set(provenance["files"]), {"translate.py", "skill/SKILL.md", "glossary.csv"})
        self.assertEqual(len(stage.GLOSSARY), 43)
        self.assertEqual(set(stage.MANDATES), set(stage.ROLES))

    def test_untranslated_source_cannot_be_delivered_as_english(self):
        context = prepared(document("ای دوست"), fragment=True)
        with self.assertRaisesRegex(stage.Invalid, "English candidate retains"):
            draft(context, "ای دوست")
        context = draft(context, "O friend")
        back = {"units": [{"id": context["units"][0]["id"], "text": "ای دوست"}]}
        self.assertEqual(stage.accept("back-one", context, back)["backTranslation"][0]["text"], "ای دوست")

    def test_synthesis_preserves_units_without_accepted_findings(self):
        context = reviewed(draft(prepared(document(ARABIC + "\n\n" + PERSIAN))), "one")
        rewritten = copy.deepcopy(context["candidate"])
        rewritten[0]["text"] += " Verily."
        with self.assertRaisesRegex(stage.Invalid, "without accepted review feedback"):
            stage.accept("synthesis-one", context, {"units": rewritten, "decisions": [], "notes": []})
        issue = {"unitId": context["units"][0]["id"], "current": "Walk", "suggested": "Proceed", "reason": "A localized ambiguity.", "severity": "minor"}
        context = reviewed(draft(prepared(document(ARABIC + "\n\n" + PERSIAN))), "one", issue)
        finding = context["history"]["reviews-one"]["back-translator"]["issues"][0]
        decision = {"issueId": finding["id"], "action": "accept", "reason": "Repair the identified unit."}
        revised = copy.deepcopy(context["candidate"])
        revised[1]["text"] += " Verily."
        with self.assertRaisesRegex(stage.Invalid, "without accepted review feedback"):
            stage.accept("synthesis-one", context, {"units": revised, "decisions": [decision], "notes": []})
        revised = copy.deepcopy(context["candidate"])
        revised[0]["text"] = revised[0]["text"].replace("Walk", "Proceed")
        accepted = stage.accept("synthesis-one", context, {"units": revised, "decisions": [decision], "notes": []})
        self.assertEqual(accepted["candidate"], revised)


if __name__ == "__main__":
    unittest.main()
