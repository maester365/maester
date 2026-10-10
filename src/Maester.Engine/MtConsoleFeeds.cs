using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Net.Http;
using System.Threading.Tasks;
using System.Xml.Linq;

namespace Maester.Engine
{
    /// <summary>A post of the blog feed: the day it was published ("MMM dd", or empty), its title and its address.</summary>
    public sealed class MtBlogPost
    {
        public string Published { get; set; }
        public string Title { get; set; }
        public string Link { get; set; }
    }

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
                    string blog = new Uri(feedUrl).GetLeftPart(UriPartial.Authority) + "/blog";
                    renderer.SetPanelText("Blog", "From the blog", FormatPosts(posts, count, blog));
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
                    // An update is worth a glance: its box gets an amber border.
                    renderer.SetPanelText("Version", "Version", lines, latest > current ? "38;5;215" : null);
                }
                catch (Exception)
                {
                    // The gallery could not be reached: the panel is left out.
                }
            });
        }

        /// <summary>
        /// The lines of the Blog panel: the newest post first, each with its date dimmed and its title as a
        /// hyperlink to the post, then the address of the blog.
        /// </summary>
        public static string[] FormatPosts(IList<MtBlogPost> posts, int count, string blogUrl)
        {
            var lines = new List<string>();
            foreach (var post in posts)
            {
                if (lines.Count >= count) break;
                string date = string.IsNullOrEmpty(post.Published) ? "      " : post.Published;
                lines.Add("\u001b[2m" + date + "\u001b[0m  " + MtConsoleRenderer.Hyperlink(post.Title, post.Link));
            }
            if (!string.IsNullOrEmpty(blogUrl))
            {
                string shown = blogUrl.Substring(blogUrl.IndexOf("://", StringComparison.Ordinal) + 3);
                lines.Add("\u001b[2m" + MtConsoleRenderer.Hyperlink(shown, blogUrl) + "\u001b[0m");
            }
            return lines.ToArray();
        }

        /// <summary>The newest posts of an RSS 2.0 feed, in the order of the feed (newest first).</summary>
        public static List<MtBlogPost> ParseFeed(string xml, int count)
        {
            var posts = new List<MtBlogPost>();
            var doc = XDocument.Parse(xml);
            foreach (var item in doc.Descendants("item"))
            {
                if (posts.Count >= count) break;
                string title = Clean((string)item.Element("title"));
                if (title.Length == 0) continue;
                DateTime published;
                string date = DateTime.TryParse((string)item.Element("pubDate"), CultureInfo.InvariantCulture, DateTimeStyles.AdjustToUniversal, out published)
                    ? published.ToString("MMM dd", CultureInfo.InvariantCulture)
                    : string.Empty;
                posts.Add(new MtBlogPost { Published = date, Title = title, Link = WebLink(Clean((string)item.Element("link"))) });
            }
            return posts;
        }

        /// <summary>
        /// Text from the web made safe for a panel. Control characters become spaces, so that it cannot write
        /// escape sequences to the console. Emoji and other pictographs are left out: terminals do not agree on
        /// how wide they are, and a wrong guess pushes the border of the panel out of line.
        /// </summary>
        private static string Clean(string text)
        {
            if (string.IsNullOrEmpty(text)) return string.Empty;
            var sb = new System.Text.StringBuilder(text.Length);
            foreach (char c in text)
            {
                bool pictograph = char.IsSurrogate(c) || c == '\uFE0F' || c == '\u200D' ||
                    char.GetUnicodeCategory(c) == UnicodeCategory.OtherSymbol;
                if (pictograph) continue;
                bool space = char.IsControl(c) || char.IsWhiteSpace(c);
                if (space && sb.Length > 0 && sb[sb.Length - 1] == ' ') continue;
                sb.Append(space ? ' ' : c);
            }
            return sb.ToString().Trim();
        }

        /// <summary>The address when it is an absolute http or https one, or null.</summary>
        private static string WebLink(string link)
        {
            Uri uri;
            if (!Uri.TryCreate(link, UriKind.Absolute, out uri)) return null;
            return uri.Scheme == Uri.UriSchemeHttps || uri.Scheme == Uri.UriSchemeHttp ? uri.AbsoluteUri : null;
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

        // The cache holds one post per line: date, title and address, separated by tabs.
        private static List<MtBlogPost> ReadCache(string cacheFile, TimeSpan maxAge)
        {
            if (string.IsNullOrEmpty(cacheFile) || !File.Exists(cacheFile)) return null;
            if (DateTime.UtcNow - File.GetLastWriteTimeUtc(cacheFile) > maxAge) return null;
            var posts = new List<MtBlogPost>();
            foreach (var line in File.ReadAllLines(cacheFile))
            {
                var fields = line.Split('\t');
                // A line in another layout (an earlier version's cache) means the feed is read again.
                if (fields.Length != 3) return null;
                posts.Add(new MtBlogPost { Published = Clean(fields[0]), Title = Clean(fields[1]), Link = WebLink(fields[2]) });
            }
            return posts.Count > 0 ? posts : null;
        }

        private static void WriteCache(string cacheFile, List<MtBlogPost> posts)
        {
            if (string.IsNullOrEmpty(cacheFile) || posts.Count == 0) return;
            try
            {
                var lines = new List<string>();
                foreach (var post in posts)
                {
                    lines.Add(post.Published + "\t" + post.Title + "\t" + post.Link);
                }
                Directory.CreateDirectory(Path.GetDirectoryName(cacheFile));
                File.WriteAllLines(cacheFile, lines);
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
