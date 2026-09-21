#!/usr/bin/env python3
"""Validate the I03 localization registry, catalogs, placeholders and UI wiring."""
from __future__ import annotations
import argparse
import hashlib
import json
import re
from collections import Counter
from pathlib import Path
from typing import Any

ENABLED = ("en","es","fr","it","pt-BR","ro","de","pl","nl","ga","cs","uk","ru","ja","zh-CN","zh-TW","ko","hi","th","id","vi","tr","ar")
RESERVE = ("bn","ur","mr","te","arz","pcm","ha")
REGISTERED = ENABLED[:18] + RESERVE[:4] + ENABLED[18:21] + ENABLED[21:] + RESERVE[4:]
NATIVE_NAMES = {
 "en":"English","es":"Español","fr":"Français","it":"Italiano","pt-BR":"Português (Brasil)",
 "ro":"Română","de":"Deutsch","pl":"Polski","nl":"Nederlands","ga":"Gaeilge","cs":"Čeština",
 "uk":"Українська","ru":"Русский","ja":"日本語","zh-CN":"简体中文","zh-TW":"繁體中文",
 "ko":"한국어","hi":"हिन्दी","bn":"বাংলা","ur":"اردو","mr":"मराठी","te":"తెలుగు","th":"ไทย",
 "id":"Bahasa Indonesia","vi":"Tiếng Việt","tr":"Türkçe","ar":"العربية",
 "arz":"العربية المصرية","pcm":"Naijá","ha":"Hausa",
}
CANONICAL_KEY_COUNT = 1292
SPANISH_EXTRA_COUNT = 58
SPANISH_EXTRA_KEYS_SHA256 = "14a47a3db8969d4864b8cdc6bfe28be68333946bdc89e2dd30a30fd5186147c4"
PLACEHOLDER = re.compile(r"\{[^{}]+\}")
RESIDUE = re.compile(r"PMMTERM|PMMTOKEN|__PMM|\bTERM\d+\b")

class VerificationError(RuntimeError):
    pass

def _unique_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise VerificationError(f"duplicate JSON key: {key!r}")
        result[key] = value
    return result

def load_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8-sig"), object_pairs_hook=_unique_object)
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise VerificationError(f"{path}: {exc}") from exc
    if not isinstance(value, dict):
        raise VerificationError(f"{path}: root must be an object")
    return value

def placeholders(value: str) -> Counter[str]:
    return Counter(PLACEHOLDER.findall(value))

def verify(repo_root: Path) -> dict[str, Any]:
    package = repo_root / "PMM"
    loc = package / "Resources" / "Localization"
    registry = load_json(loc / "languages.json")
    problems: list[str] = []
    if registry.get("schema") != "PMM_LANGUAGES_V1":
        problems.append("languages.json schema is not PMM_LANGUAGES_V1")
    if registry.get("default") != "en":
        problems.append("English is not the registry default")
    definitions = registry.get("languages")
    if not isinstance(definitions, list):
        raise VerificationError("languages.json languages must be an array")
    codes = [str(item.get("code", "")) for item in definitions if isinstance(item, dict)]
    if tuple(codes) != REGISTERED:
        problems.append(f"registered language order differs: {codes!r}")
    if len(codes) != len(set(codes)):
        problems.append("duplicate language codes in registry")
    by_code = {str(item.get("code")): item for item in definitions if isinstance(item, dict)}
    enabled = tuple(code for code in codes if bool(by_code[code].get("enabled")))
    reserve = tuple(code for code in codes if not bool(by_code[code].get("enabled")))
    if enabled != ENABLED:
        problems.append(f"enabled languages differ: {enabled!r}")
    if reserve != RESERVE:
        problems.append(f"reserve languages differ: {reserve!r}")
    for code in REGISTERED:
        definition = by_code.get(code)
        if definition is None:
            problems.append(f"{code}: missing registry definition")
            continue
        if definition.get("nativeName") != NATIVE_NAMES[code]:
            problems.append(f"{code}: nativeName differs")
        if code == "en":
            if definition.get("fallback") is not None:
                problems.append("en: fallback must be null")
        elif definition.get("fallback") != "en":
            problems.append(f"{code}: fallback must be en")
        expected_status = "complete" if code in ENABLED else "reserve"
        if definition.get("status") != expected_status:
            problems.append(f"{code}: status must be {expected_status}")
        if not (loc / f"{code}.json").is_file():
            problems.append(f"{code}: catalog file missing")
    if by_code.get("ar", {}).get("direction") != "rtl":
        problems.append("ar: direction must be rtl")
    english = load_json(loc / "en.json")
    canonical = english.get("strings")
    if not isinstance(canonical, dict):
        raise VerificationError("en.json strings must be an object")
    if len(canonical) != CANONICAL_KEY_COUNT:
        problems.append(f"en: expected {CANONICAL_KEY_COUNT} canonical keys, found {len(canonical)}")
    catalog_counts: dict[str, int] = {}
    for code in ENABLED:
        catalog = load_json(loc / f"{code}.json")
        strings = catalog.get("strings")
        if not isinstance(strings, dict):
            problems.append(f"{code}: strings must be an object")
            continue
        catalog_counts[code] = len(strings)
        if catalog.get("schema") != "PMM_LANGUAGE_V1":
            problems.append(f"{code}: invalid catalog schema")
        if catalog.get("language") != code:
            problems.append(f"{code}: catalog language field differs")
        if catalog.get("nativeName") != NATIVE_NAMES[code]:
            problems.append(f"{code}: catalog nativeName differs")
        expected_fallback = None if code == "en" else "en"
        if catalog.get("fallback") != expected_fallback:
            problems.append(f"{code}: catalog fallback differs")
        missing = sorted(set(canonical) - set(strings))
        extra = sorted(set(strings) - set(canonical))
        empty = sorted(key for key in canonical if key in strings and not str(strings[key]).strip())
        mismatch = sorted(key for key in canonical if key in strings and placeholders(key) != placeholders(str(strings[key])))
        residue = sorted(key for key in canonical if key in strings and RESIDUE.search(str(strings[key])))
        if missing: problems.append(f"{code}: {len(missing)} canonical keys missing")
        if empty: problems.append(f"{code}: {len(empty)} empty canonical translations")
        if mismatch: problems.append(f"{code}: {len(mismatch)} placeholder mismatches")
        if residue: problems.append(f"{code}: {len(residue)} translation residues")
        if code == "es":
            extra_hash = hashlib.sha256(("\n".join(extra) + "\n").encode("utf-8")).hexdigest()
            if len(extra) != SPANISH_EXTRA_COUNT or extra_hash != SPANISH_EXTRA_KEYS_SHA256:
                problems.append(f"es: compatibility extension changed (count={len(extra)}, sha256={extra_hash})")
        elif extra:
            problems.append(f"{code}: {len(extra)} unexpected keys outside English canonical set")
    library_ui = (package/"Modules"/"Presentation"/"Library.UI.ps1").read_text(encoding="utf-8-sig")
    expected_selector = "$Script:CmbLanguage.SelectedValue = Resolve-PMMLanguageCode ([string]$cfg.Language)"
    if expected_selector not in library_ui:
        problems.append("language selector does not restore the resolved saved code")
    if "if ($cfg.Language -eq 'es') { 'es' } else { 'en' }" in library_ui:
        problems.append("legacy en/es-only selector path remains")
    bootstrap = (package/"Modules"/"Bootstrap"/"Start-PalModMerger.ps1").read_text(encoding="utf-8-sig")
    for token in ("$Script:LanguageOptions=@(Get-PMMLanguageOptions)","$cfg.Language = Resolve-PMMLanguageCode $selectedCode","Save-PMMConfig $cfg","Restart Palworld Manager Merger to apply it to the entire interface."):
        if token not in bootstrap:
            problems.append(f"startup language wiring missing: {token}")
    localization = (package/"Modules"/"Shared"/"Localization.ps1").read_text(encoding="utf-8-sig")
    for token in ("'HashShort'","'SizeText'","'Priority'"):
        if token not in localization:
            problems.append(f"RTL technical binding exception missing: {token}")
    ltr_block = localization.split("$Script:PMMLtrControlNames=@(",1)[-1].split(")",1)[0]
    for forbidden in ("'TxtStatus'","'TxtLog'"):
        if forbidden in ltr_block:
            problems.append(f"mixed localized control incorrectly forced LTR: {forbidden}")
    if problems:
        raise VerificationError("\n".join(problems))
    return {
      "schema":"PMM_I03_LOCALIZATION_CHECKS_V1","ok":True,
      "registeredLanguages":len(REGISTERED),"enabledLanguages":list(ENABLED),
      "reserveLanguages":list(RESERVE),"canonicalKeyCount":len(canonical),
      "catalogKeyCounts":catalog_counts,"placeholderMismatches":0,
      "missingCanonicalKeys":0,"spanishCompatibilityExtraKeys":SPANISH_EXTRA_COUNT,
      "spanishCompatibilityExtraKeysSha256":SPANISH_EXTRA_KEYS_SHA256,
      "defaultLanguage":"en","fallbackLanguage":"en","languageChangePolicy":"save-and-restart",
    }

def main() -> int:
    parser=argparse.ArgumentParser()
    parser.add_argument("--repo",type=Path,default=Path(__file__).resolve().parents[4])
    parser.add_argument("--json",action="store_true")
    args=parser.parse_args()
    try:
        report=verify(args.repo.resolve())
    except VerificationError as exc:
        print(f"FAIL: {exc}")
        return 1
    if args.json:
        print(json.dumps(report,ensure_ascii=False,indent=2))
    else:
        print(f"I03 localization OK: {report['registeredLanguages']} registered, {len(report['enabledLanguages'])} enabled, {report['canonicalKeyCount']} canonical keys")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
