"""PMM-owned Unreal 5.1 editor operations. Inputs are data, never evaluated."""
import hashlib
import json
import os
import re
import traceback
import unreal

root = os.path.abspath(unreal.Paths.convert_relative_path_to_full(unreal.Paths.project_dir()))
work = os.path.join(root, "Saved", "PMM")
request_path = os.path.join(work, "request.json")
response_path = os.path.join(work, "response.json")
registry_path = os.path.join(work, "assets.json")

def name(value):
    if not isinstance(value, str) or not re.fullmatch(r"[A-Za-z][A-Za-z0-9_]{0,47}", value):
        raise ValueError("Invalid asset name")
    return value

def texture_path(value):
    return "/Game/PMM/" + name(value)

def asset_file(value):
    return os.path.join(root, "Content", "PMM", name(value) + ".uasset")

def sha256(path):
    with open(path, "rb") as stream:
        return hashlib.sha256(stream.read()).hexdigest()

def verify_texture(value, record):
    if sha256(asset_file(value)) != record["assetSha256"]:
        raise ValueError("Registered template changed outside PMM; verification required")
    return load_texture(value)

def load_texture(value):
    asset = unreal.load_asset(texture_path(value))
    if not isinstance(asset, unreal.Texture2D):
        raise ValueError("Only PMM Texture2D assets are supported")
    return asset

def import_texture(request):
    source = os.path.abspath(os.path.join(root, "SourceData", name(request["assetName"]) + ".png"))
    if not os.path.isfile(source) or os.path.getsize(source) > 4194304:
        raise ValueError("PNG source missing or too large")
    task = unreal.AssetImportTask()
    task.set_editor_property("filename", source)
    task.set_editor_property("destination_path", "/Game/PMM")
    task.set_editor_property("destination_name", name(request["assetName"]))
    task.set_editor_property("automated", True)
    task.set_editor_property("replace_existing", False)
    task.set_editor_property("save", True)
    unreal.AssetToolsHelpers.get_asset_tools().import_asset_tasks([task])
    return load_texture(request["assetName"])

def main():
    with open(request_path, encoding="utf-8-sig") as stream:
        request = json.load(stream)
    operation = request["operation"]
    registry = {}
    if os.path.isfile(registry_path):
        with open(registry_path, encoding="utf-8-sig") as stream:
            registry = json.load(stream)
    target = name(request.get("assetName", "PMMProbe"))
    if operation in ("prepare", "import_texture"):
        if target in registry:
            if registry[target]["sourceSha256"] != request["sourceSha256"]:
                raise ValueError("A different source asset already exists")
            asset = verify_texture(target, registry[target])
        else:
            if unreal.EditorAssetLibrary.does_asset_exist(texture_path(target)):
                raise ValueError("Unregistered target asset exists")
            asset = import_texture(dict(request, assetName=target))
            registry[target] = dict(sourceSha256=request["sourceSha256"], sourceName=target, recipe="texture-png-v1")
    elif operation == "duplicate":
        source = name(request["templateId"])
        if source not in registry or target in registry:
            raise ValueError("Unknown template or existing target")
        verify_texture(source, registry[source])
        if not unreal.EditorAssetLibrary.duplicate_asset(texture_path(source), texture_path(target)):
            raise RuntimeError("Texture duplication failed")
        asset = load_texture(target)
        registry[target] = dict(registry[source], templateId=source)
    elif operation == "configure":
        if target not in registry:
            raise ValueError("Unknown PMM asset")
        asset = verify_texture(target, registry[target])
        if "srgb" in request:
            asset.set_editor_property("srgb", bool(request["srgb"]))
        if "filter" in request:
            options = {"default": unreal.TextureFilter.TF_DEFAULT, "nearest": unreal.TextureFilter.TF_NEAREST,
                       "bilinear": unreal.TextureFilter.TF_BILINEAR, "trilinear": unreal.TextureFilter.TF_TRILINEAR}
            asset.set_editor_property("filter", options[request["filter"]])
    else:
        raise ValueError("Unsupported editor operation")
    registry[target]['properties'] = {'srgb': bool(asset.get_editor_property('srgb')), 'filter': str(asset.get_editor_property('filter'))}
    if not unreal.EditorAssetLibrary.save_loaded_asset(asset, False):
        raise RuntimeError("Asset could not be saved")
    registry[target]["assetSha256"] = sha256(asset_file(target))
    with open(registry_path + ".tmp", "w", encoding="utf-8") as stream:
        json.dump(registry, stream, indent=2)
    os.replace(registry_path + ".tmp", registry_path)
    return dict(success=True, asset=texture_path(target), assetClass="Texture2D", registered=list(registry))

try:
    result = main()
except Exception:
    result = dict(success=False, error=traceback.format_exc())
os.makedirs(work, exist_ok=True)
with open(response_path, "w", encoding="utf-8") as stream:
    json.dump(result, stream, indent=2)
if not result["success"]:
    raise RuntimeError(result["error"])
