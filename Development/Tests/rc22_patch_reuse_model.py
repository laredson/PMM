#!/usr/bin/env python3
"""Dependency-free policy mirror for PMM RC22 patch-reuse regression cases.

This validates the intended safety boundary with synthetic identities. It is not
a PowerShell/WPF runtime test and deliberately contains no user/game payloads.
"""

from dataclasses import dataclass, field
from typing import Mapping, Sequence


@dataclass(frozen=True)
class SharedProof:
    asset: str
    mode: str
    providers: frozenset[str]


@dataclass(frozen=True)
class Patch:
    patched: tuple[SharedProof, ...]
    analyzed_shared: tuple[SharedProof, ...]
    source_hashes: Mapping[str, str]
    engine: str = "PMMCore-v0.9.0"
    mappings: str = "map-a"
    vanilla: str = "vanilla-a"
    effective_order: str = "order-independent"
    production_recipes: str = "ckl-a"
    recipe_outputs: Mapping[str, str] = field(default_factory=dict)
    decisions: tuple[str, ...] = ()


def _by_asset(items: Sequence[SharedProof]) -> dict[str, SharedProof]:
    result: dict[str, SharedProof] = {}
    for item in items:
        key = item.asset.lower().replace("\\", "/")
        assert key not in result, f"duplicate asset proof: {item.asset}"
        result[key] = item
    return result


def fast_reuse(
    patch: Patch,
    current_shared: Sequence[SharedProof],
    current_hashes: Mapping[str, str],
    *,
    engine: str = "PMMCore-v0.9.0",
    mappings: str = "map-a",
    vanilla: str = "vanilla-a",
    effective_order: str = "order-independent",
    production_recipes: str = "ckl-a",
) -> bool:
    """Mirror the schema-9 automatic pre-adapter proof."""
    if patch.decisions:
        return False
    if any(item.mode == "KnownRecipeAuto" for item in patch.patched):
        if patch.production_recipes != production_recipes:
            return False
    if (patch.engine, patch.mappings, patch.vanilla, patch.effective_order) != (
        engine,
        mappings,
        vanilla,
        effective_order,
    ):
        return False
    stored = _by_asset(patch.analyzed_shared)
    current = _by_asset(current_shared)
    if stored.keys() != current.keys():
        return False
    for key, proof in stored.items():
        now = current[key]
        if proof.providers != now.providers:
            return False
        if proof.mode != now.mode:
            return False
        for provider in proof.providers:
            if current_hashes.get(provider) != patch.source_hashes.get(provider):
                return False
    return True


def analyzed_recipe_reuse(
    patch: Patch,
    current_plan: Sequence[SharedProof],
    current_hashes: Mapping[str, str],
    decisions: Sequence[str] = (),
    recipe_outputs: Mapping[str, str] | None = None,
) -> bool:
    """Mirror post-Analyze comparison of output-producing assets only."""
    stored = _by_asset(patch.patched)
    current = _by_asset(
        tuple(item for item in current_plan if item.mode not in {"Identical", "PackageChoice"})
    )
    if stored.keys() != current.keys() or tuple(decisions) != patch.decisions:
        return False
    for key, proof in stored.items():
        now = current[key]
        if (proof.mode, proof.providers) != (now.mode, now.providers):
            return False
        if proof.mode == "KnownRecipeAuto":
            if patch.recipe_outputs.get(key) != (recipe_outputs or {}).get(key):
                return False
        for provider in proof.providers:
            if current_hashes.get(provider) != patch.source_hashes.get(provider):
                return False
    return True


def migrate_semiauto(version: int, sound: str, enabled: bool) -> tuple[int, bool]:
    if version < 3:
        return 3, sound != "None"
    return version, enabled


def main() -> None:
    merge = SharedProof("Pal/A.uasset", "RelocatableAuto", frozenset({"ConflictA.pak", "ConflictB.pak"}))
    identical = SharedProof("Pal/I.uasset", "Identical", frozenset({"ConflictA.pak", "HelperC.pak"}))
    recipe = SharedProof("Pal/R.uasset", "KnownRecipeAuto", frozenset({"RecipeA.pak", "RecipeB.pak"}))
    hashes = {
        "ConflictA.pak": "a1",
        "ConflictB.pak": "b1",
        "HelperC.pak": "c1",
        "UniqueBigInventory.pak": "u1",
        "UniqueNewMod.pak": "u2",
        "RecipeA.pak": "r1",
        "RecipeB.pak": "r2",
    }
    recipe_evidence = {"pal/r.uasset": "recipe-output-a"}
    patch = Patch((merge, recipe), (merge, identical, recipe), hashes, recipe_outputs=recipe_evidence)

    # Unique source membership is deliberately irrelevant to overlay identity.
    assert fast_reuse(patch, (merge, identical, recipe), hashes)
    without_unique = {key: value for key, value in hashes.items() if key != "UniqueBigInventory.pak"}
    assert fast_reuse(patch, (merge, identical, recipe), without_unique)
    with_new_unique = dict(without_unique, **{"AnotherUnique.pak": "u3"})
    assert fast_reuse(patch, (merge, identical, recipe), with_new_unique)
    assert analyzed_recipe_reuse(patch, (merge, identical, recipe), with_new_unique, recipe_outputs=recipe_evidence)

    # Output-relevant changes fail closed.
    changed_hash = dict(hashes, **{"ConflictB.pak": "b2"})
    assert not fast_reuse(patch, (merge, identical, recipe), changed_hash)
    new_provider = SharedProof(merge.asset, merge.mode, merge.providers | {"NewProvider.pak"})
    assert not fast_reuse(patch, (new_provider, identical, recipe), dict(hashes, **{"NewProvider.pak": "n1"}))
    new_shared = SharedProof("Pal/New.uasset", "Identical", frozenset({"ConflictA.pak", "UniqueNewMod.pak"}))
    assert not fast_reuse(patch, (merge, identical, recipe, new_shared), hashes)
    assert not fast_reuse(patch, (merge, identical, recipe), hashes, mappings="map-b")
    assert not fast_reuse(patch, (merge, identical, recipe), hashes, vanilla="vanilla-b")
    assert not fast_reuse(patch, (merge, identical, recipe), hashes, effective_order="winner-b")
    assert not fast_reuse(patch, (merge, identical, recipe), hashes, production_recipes="ckl-b")
    changed_mode = SharedProof(merge.asset, "BinaryAuto", merge.providers)
    assert not analyzed_recipe_reuse(patch, (changed_mode, identical, recipe), hashes, recipe_outputs=recipe_evidence)
    assert not analyzed_recipe_reuse(patch, (merge, identical, recipe), hashes, recipe_outputs={"pal/r.uasset": "recipe-output-b"})

    decision_patch = Patch((merge,), (merge, identical), hashes, decisions=("provider-a",))
    assert not fast_reuse(decision_patch, (merge, identical), hashes)
    assert analyzed_recipe_reuse(decision_patch, (merge, identical), hashes, ("provider-a",))
    assert not analyzed_recipe_reuse(decision_patch, (merge, identical), hashes, ("provider-b",))

    assert migrate_semiauto(2, "Ok", False) == (3, True)
    assert migrate_semiauto(2, "None", False) == (3, False)
    assert migrate_semiauto(3, "Ok", False) == (3, False)
    print("RC22_REGRESSION_MODEL_OK")


if __name__ == "__main__":
    main()
