using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Net.Http;
using System.Threading.Tasks;
using System.Xml.Linq;

namespace Maester.Engine
{
    /// <summary>
    /// Fills the Blog and Version panels of the dashboard from the web, on background threads, so a run never
    /// waits for them. Each makes one GET request with a five-second timeout; a failure (offline, proxy, a
    /// changed feed) leaves the panel out. The blog posts are kept in a cache file for a day.
    ///
    /// Invoke-Maester starts them only for a dashboard that is wide enough to show the panels, and never with
    /// -SkipVersionCheck.
    /// </summary>
    public static class MtConsoleFeeds
    {
        private static readonly HttpClient Client = CreateClient();

        private static HttpClient CreateClient()
        {
            var client = new HttpClient { Timeout = TimeSpan.FromSeconds(5) };
            client.DefaultRequestHeaders.UserAgent.ParseAdd("Maester");
            return client;
        }

        /// <summary>Shows the newest posts of an RSS feed in the Blog panel.</summary>
        public static Task StartBlog(MtConsoleRenderer renderer, string feedUrl, string cacheFile, int count)
        {
            return Task.Run(async () =>
            {
                try
                {
                    var posts = ReadCache(cacheFile, TimeSpan.FromHours(24));
                    if (posts == null)
                    {
                        string xml = await Client.GetStringAsync(feedUrl).ConfigureAwait(false);
                        posts = ParseFeed(xml, count);
                        WriteCache(cacheFile, posts);
                    }
                    if (posts.Count == 0) return;
                    var lines = new List<string>();
                    foreach (var post in posts)
                    {
                        if (lines.Count < count) lines.Add(post);
                    }
                    lines.Add(new Uri(feedUrl).Host + "/blog");
                    renderer.SetPanelText("Blog", "From the blog", lines.ToArray());
                }
                catch (Exception)
                {
                    // No network, a proxy that refuses, or a feed that changed: the panel is left out.
                }
            });
        }

        /// <summary>Shows in the Version panel whether a newer stable version of the module is on the PowerShell Gallery.</summary>
        public static Task StartVersion(MtConsoleRenderer renderer, string moduleName, string currentVersion)
        {
            return Task.Run(async () =>
            {
                try
                {
                    string url = "https://www.powershellgallery.com/api/v2/FindPackagesById()?id='" + Uri.EscapeDataString(moduleName) +
                        "'&$filter=IsLatestVersion and not IsPrerelease";
                    string xml = await Client.GetStringAsync(url).ConfigureAwait(false);
                    var latest = ParseGalleryVersion(xml);
                    Version current;
                    if (latest == null || !Version.TryParse(currentVersion, out current)) return;
                    string[] lines = latest > current
                        ? new[] { moduleName + " " + latest + " is available (this is " + current + ")", "Update-Module " + moduleName }
                        : new[] { moduleName + " " + current + " is the latest version" };
                    renderer.SetPanelText("Version", "Version", lines);
                }
                catch (Exception)
                {
                    // The gallery could not be reached: the panel is left out.
                }
            });
        }

        /// <summary>The newest posts of an RSS 2.0 feed as "MMM dd  title" lines.</summary>
        public static List<string> ParseFeed(string xml, int count)
        {
            var posts = new List<string>();
            var doc = XDocument.Parse(xml);
            foreach (var item in doc.Descendants("item"))
            {
                if (posts.Count >= count) break;
                string title = ((string)item.Element("title") ?? string.Empty).Trim();
                if (title.Length == 0) continue;
                DateTime published;
                string date = DateTime.TryParse((string)item.Element("pubDate"), CultureInfo.InvariantCulture, DateTimeStyles.AdjustToUniversal, out published)
                    ? published.ToString("MMM dd", CultureInfo.InvariantCulture)
                    : "      ";
                posts.Add(date + "  " + title);
            }
            return posts;
        }

        /// <summary>The version in a PowerShell Gallery FindPackagesById response, or null.</summary>
        public static Version ParseGalleryVersion(string xml)
        {
            XNamespace d = "http://schemas.microsoft.com/ado/2007/08/dataservices";
            Version latest = null;
            foreach (var element in XDocument.Parse(xml).Descendants(d + "Version"))
            {
                Version v;
                if (Version.TryParse(element.Value, out v) && (latest == null || v > latest)) latest = v;
            }
            return latest;
        }

        private static List<string> ReadCache(string cacheFile, TimeSpan maxAge)
        {
            if (string.IsNullOrEmpty(cacheFile) || !File.Exists(cacheFile)) return null;
            if (DateTime.UtcNow - File.GetLastWriteTimeUtc(cacheFile) > maxAge) return null;
            var posts = new List<string>(File.ReadAllLines(cacheFile));
            return posts.Count > 0 ? posts : null;
        }

        private static void WriteCache(string cacheFile, List<string> posts)
        {
            if (string.IsNullOrEmpty(cacheFile) || posts.Count == 0) return;
            try
            {
                Directory.CreateDirectory(Path.GetDirectoryName(cacheFile));
                File.WriteAllLines(cacheFile, posts);
            }
            catch (IOException)
            {
                // A cache that cannot be written only means the feed is read again next time.
            }
            catch (UnauthorizedAccessException)
            {
                // Same.
            }
        }
    }
}
