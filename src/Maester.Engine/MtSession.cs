using System;
using System.Collections.Concurrent;
using System.Management.Automation.Runspaces;

namespace Maester.Engine
{
    /// <summary>
    /// Process-wide engine state. A static field on a type in this DLL is shared by every runspace in
    /// the process, so state kept here is visible to worker runspaces when tests run in parallel.
    /// </summary>
    public static class MtSession
    {
        /// <summary>
        /// Error ID prefix of the record that Add-MtTestResultDetail -SkippedBecause throws under the native
        /// engine to end a test. The engine treats a terminating error with this ID as a skip, not an error.
        /// </summary>
        public const string SkipErrorId = "MaesterTestSkipped";

        private static readonly ConcurrentDictionary<int, string> CurrentTests = new ConcurrentDictionary<int, string>();

        /// <summary>Result details stored by test ID. Safe to write from several runspaces.</summary>
        public static readonly ConcurrentDictionary<string, object> ResultDetail =
            new ConcurrentDictionary<string, object>(StringComparer.OrdinalIgnoreCase);

        /// <summary>Summary of the last engine run, readable even after Ctrl+C stopped the pipeline.</summary>
        public static MtRunSummary LastRun { get; internal set; }

        /// <summary>
        /// ID of the test running on the calling runspace, or null when no native test is running.
        /// Add-MtTestResultDetail uses this to decide whether it was called under the native engine.
        /// </summary>
        public static string GetCurrentTest()
        {
            var rs = Runspace.DefaultRunspace;
            if (rs == null) return null;
            string id;
            return CurrentTests.TryGetValue(rs.Id, out id) ? id : null;
        }

        /// <summary>
        /// Marks a test as running on the calling runspace and returns the test that was running before, if
        /// any (a test can run another test with Invoke-MtTest). Called by the engine's invocation script.
        /// </summary>
        public static string EnterTest(string testId)
        {
            var rs = Runspace.DefaultRunspace;
            if (rs == null || testId == null) return null;
            string previous;
            CurrentTests.TryGetValue(rs.Id, out previous);
            CurrentTests[rs.Id] = testId;
            return previous;
        }

        /// <summary>Restores the test that was running before EnterTest, or clears it when there was none.</summary>
        public static void ExitTest(string previousTestId)
        {
            var rs = Runspace.DefaultRunspace;
            if (rs == null) return;
            if (previousTestId != null) { CurrentTests[rs.Id] = previousTestId; return; }
            string removed;
            CurrentTests.TryRemove(rs.Id, out removed);
        }

        /// <summary>Clears the running test of the calling runspace.</summary>
        public static void ExitTest()
        {
            ExitTest(null);
        }

        /// <summary>Clears per-run state. Called at the start of every engine run.</summary>
        public static void Reset()
        {
            ResultDetail.Clear();
            CurrentTests.Clear();
        }
    }
}
