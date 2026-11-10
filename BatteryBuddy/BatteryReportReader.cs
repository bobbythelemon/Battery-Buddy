using System;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Net;
using System.Text.RegularExpressions;

namespace BatteryBuddyWindows;

public static class BatteryReportReader
{
    private static BatteryReportData? _cache;
    private static DateTime _lastReadUtc = DateTime.MinValue;
    private static readonly TimeSpan CacheDuration = TimeSpan.FromMinutes(30);

    public static void InvalidateCache() { _cache = null; _lastReadUtc = DateTime.MinValue; }

    public static BatteryReportData Read(bool forceRefresh = false)
    {
        if (!forceRefresh && _cache is not null && DateTime.UtcNow - _lastReadUtc < CacheDuration) return _cache;

        try
        {
            string tempFile = Path.Combine(Path.GetTempPath(), $"batteryreport_{Guid.NewGuid():N}.html");
            var psi = new ProcessStartInfo
            {
                FileName = "powercfg",
                Arguments = $"/batteryreport /output "{tempFile}"",
                UseShellExecute = false,
                CreateNoWindow = true,
                RedirectStandardOutput = true,
                RedirectStandardError = true
            };
            using var process = Process.Start(psi);
            if (process is not null) process.WaitForExit(15000);
            if (!File.Exists(tempFile)) return CacheAndReturn(new BatteryReportData());
            string html = File.ReadAllText(tempFile);
            try { File.Delete(tempFile); } catch { }
            return CacheAndReturn(ParseBatteryReport(html));
        }
        catch
        {
            return CacheAndReturn(new BatteryReportData());
        }
    }

    private static BatteryReportData CacheAndReturn(BatteryReportData data) { _cache = data; _lastReadUtc = DateTime.UtcNow; return data; }

    private static BatteryReportData ParseBatteryReport(string html)
    {
        string text = HtmlToText(html).ToUpperInvariant();
        int? design = FindFirstIntAfter(text, new[] { "DESIGN CAPACITY", "DESIGN CAPACITY:" });
        int? full = FindFirstIntAfter(text, new[] { "FULL CHARGE CAPACITY", "FULL CHARGE CAPACITY:" });
        int? cycles = FindFirstIntAfter(text, new[] { "CYCLE COUNT", "CYCLE COUNT:" });
        return new BatteryReportData { DesignCapacity = design, FullChargeCapacity = full, CycleCount = cycles };
    }

    private static string HtmlToText(string html)
    {
        html = Regex.Replace(html, "<script.*?</script>", string.Empty, RegexOptions.Singleline | RegexOptions.IgnoreCase);
        html = Regex.Replace(html, "<style.*?</style>", string.Empty, RegexOptions.Singleline | RegexOptions.IgnoreCase);
        html = Regex.Replace(html, "<br\s*/?>", "
", RegexOptions.IgnoreCase);
        html = Regex.Replace(html, "</p>", "
", RegexOptions.IgnoreCase);
        html = Regex.Replace(html, "</tr>", "
", RegexOptions.IgnoreCase);
        html = Regex.Replace(html, "<[^>]+>", " ", RegexOptions.Singleline);
        html = WebUtility.HtmlDecode(html);
        html = Regex.Replace(html, "\s+", " ", RegexOptions.Singleline);
        return html;
    }

    private static int? FindFirstIntAfter(string text, string[] markers)
    {
        foreach (var marker in markers)
        {
            int idx = text.IndexOf(marker, StringComparison.OrdinalIgnoreCase);
            if (idx < 0) continue;
            string tail = text[(idx + marker.Length)..];
            var match = Regex.Match(tail, @"(\d{2,})");
            if (match.Success && int.TryParse(match.Groups[1].Value, NumberStyles.Integer, CultureInfo.InvariantCulture, out int value)) return value;
        }
        return null;
    }
}

public class BatteryReportData
{
    public int? DesignCapacity { get; set; }
    public int? FullChargeCapacity { get; set; }
    public int? CycleCount { get; set; }
}
