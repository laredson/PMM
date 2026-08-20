namespace PMM.Core;

public readonly record struct ByteRange(int Start, int End)
{
    public int Length => End - Start;

    public bool Overlaps(ByteRange other)
        => Start < other.End && other.Start < End;

    public override string ToString() => $"[{Start},{End})";
}

public static class ByteRanges
{
    public static IReadOnlyList<ByteRange> ChangedRanges(ReadOnlySpan<byte> before, ReadOnlySpan<byte> after)
    {
        if (before.Length != after.Length)
            throw new ArgumentException("ChangedRanges requires equal-length buffers.");

        var result = new List<ByteRange>();
        int start = -1;
        for (var i = 0; i < before.Length; i++)
        {
            if (before[i] != after[i])
            {
                if (start < 0) start = i;
            }
            else if (start >= 0)
            {
                result.Add(new ByteRange(start, i));
                start = -1;
            }
        }

        if (start >= 0)
            result.Add(new ByteRange(start, before.Length));

        return result;
    }

    public static IReadOnlyDictionary<int, int> LengthHistogram(IEnumerable<ByteRange> ranges)
        => ranges
            .GroupBy(r => r.Length)
            .OrderBy(g => g.Key)
            .ToDictionary(g => g.Key, g => g.Count());
}
