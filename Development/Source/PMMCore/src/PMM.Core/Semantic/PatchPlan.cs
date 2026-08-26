namespace PMM.Core.Semantic;

public sealed record SemanticBytePatch(
    string SemanticPath,
    string Part,
    int Offset,
    byte[] Expected,
    byte[] Replacement,
    IReadOnlyList<string> Sources,
    string Reason)
{
    public int Length => Replacement.Length;
    public string ExpectedHex => Convert.ToHexString(Expected).ToLowerInvariant();
    public string ReplacementHex => Convert.ToHexString(Replacement).ToLowerInvariant();
}

public sealed record UnsupportedIntent(
    string SemanticPath,
    string PropertyType,
    string Reason,
    IReadOnlyList<string> Sources);

public sealed record PatchConflict(
    string SemanticPath,
    string Reason,
    IReadOnlyList<string> Sources);

public sealed record SemanticPatchPlan(
    string AdapterId,
    IReadOnlyList<SemanticBytePatch> Patches,
    IReadOnlyList<UnsupportedIntent> Unsupported,
    IReadOnlyList<PatchConflict> Conflicts);

public sealed record SemanticPatchApplyResult(
    byte[] Output,
    IReadOnlyList<SemanticBytePatch> AppliedPatches,
    string BaseSha256,
    string OutputSha256,
    int ChangedByteCount,
    IReadOnlyList<ByteRange> ChangedRanges);
