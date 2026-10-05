using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Diagnostics;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Threading;
using System.Threading.Tasks;

namespace Maester.Engine
{
    /// <summary>
    /// The scheduling core. Runs work items and reports how each one ended.
    ///
    /// Main-lane items run one at a time on the CALLER's runspace as a nested pipeline, with the caller's
    /// authentication and module instance. With -MaxParallel 1 (the 3.0 default) every item is a main-lane
    /// item: no pool and no second runspace. Pool-lane items run on a RunspacePool whose initial session
    /// state imports -PoolModule.
    ///
    /// Threading rules:
    ///  - Write* may only be called on the pipeline thread, inside Begin/Process/EndProcessing. Workers post
    ///    events to a queue that the pipeline thread drains.
    ///  - Nested pipelines are invoked synchronously on the pipeline thread.
    ///  - StopProcessing (Ctrl+C) runs on another thread. It only cancels a token and calls BeginStop on
    ///    in-flight pipelines, never the blocking Stop().
    ///  - Stream collections are read by index, never enumerated while open.
    /// </summary>
    [Cmdlet(VerbsLifecycle.Invoke, "MtEngineRun")]
    [OutputType(typeof(MtRunResult))]
    public sealed class InvokeMtEngineRunCommand : PSCmdlet
    {
        [Parameter(Mandatory = true, Position = 0, ValueFromPipeline = true)]
        public MtWorkItem[] WorkItem { get; set; }

        /// <summary>Module whose scope items are invoked in, unless the item names its own.</summary>
        [Parameter]
        public PSModuleInfo Module { get; set; }

        /// <summary>Concurrent items. 1 runs everything nested on the caller's runspace.</summary>
        [Parameter]
        [ValidateRange(1, 64)]
        public int MaxParallel { get; set; }

        /// <summary>Default per-item timeout in seconds; 0 means none.</summary>
        [Parameter]
        [ValidateRange(0, 86400)]
        public int TimeoutSeconds { get; set; }

        /// <summary>Module paths imported into every pool runspace.</summary>
        [Parameter]
        public string[] PoolModule { get; set; }

        /// <summary>How long to wait for a stopped pool pipeline before abandoning its runspace.</summary>
        [Parameter]
        [ValidateRange(0, 60000)]
        public int StopGraceMs { get; set; }

        /// <summary>Do not replay the warning, verbose, debug and information records of each item on this cmdlet's streams.</summary>
        [Parameter]
        public SwitchParameter NoStreamReplay { get; set; }

        /// <summary>Script block called on the pipeline thread before each item starts, with the work item as $args[0].</summary>
        [Parameter]
        public ScriptBlock OnItemStarting { get; set; }

        /// <summary>Script block called on the pipeline thread after each item, with the result as $args[0].</summary>
        [Parameter]
        public ScriptBlock OnItemFinished { get; set; }

        // The invocation script. It runs in the caller's scope (nested pipeline), so every local uses the
        // reserved $__mt prefix: a test function can read the variables of its callers, and 78 built-in
        // checks read a variable before assigning it.
        //
        //  - The try/catch is the engine's: with an enclosing try, a statement-terminating error inside the
        //    test (a failed cmdlet call, a method call on $null) ends the test instead of only that statement.
        //  - The one-pass foreach catches a stray break/continue that would otherwise unwind the engine.
        //  - Preferences are set inside the body, which runs in the test's module scope: that scope's parent
        //    is the global scope, so a global Stop preference (the GitHub Actions pwsh shell sets one) would
        //    otherwise turn a test's Write-Error into a terminating error.
        //  - Exactly one MtOutcome object is written when the command returned or threw. None means it left
        //    through exit, break or a pipeline stop.
        private const string InvocationScript = @"
param($__mtId, $__mtModule, $__mtCommand, $__mtParameters)
$__mtBody = {
    param($__mtId, $__mtCommand, $__mtParameters)
    $ErrorActionPreference = 'Continue'
    $WarningPreference = 'Continue'
    [Maester.Engine.MtSession]::EnterTest($__mtId)
    try {
        $__mtReturned = $false
        foreach ($__mtOnce in 1) {
            try {
                if ($__mtParameters) { $__mtOutput = @(& $__mtCommand @__mtParameters) } else { $__mtOutput = @(& $__mtCommand) }
                $__mtReturned = $true
            } catch {
                [Maester.Engine.MtOutcome]::Threw($_)
                $__mtReturned = $null
            }
        }
        if ($__mtReturned) { [Maester.Engine.MtOutcome]::Returned($__mtOutput) }
    } finally {
        [Maester.Engine.MtSession]::ExitTest()
    }
}
if ($null -eq $__mtModule) { & $__mtBody $__mtId $__mtCommand $__mtParameters }
elseif ($__mtModule -is [string]) { & (Get-Module -Name $__mtModule | Select-Object -First 1) $__mtBody $__mtId $__mtCommand $__mtParameters }
else { & $__mtModule $__mtBody $__mtId $__mtCommand $__mtParameters }
";

        private sealed class EngineEvent
        {
            public bool Started;
            public MtWorkItem Item;
            public MtRunResult Result;
        }

        private readonly List<MtWorkItem> _items = new List<MtWorkItem>();
        private readonly CancellationTokenSource _cts = new CancellationTokenSource();
        private readonly BlockingCollection<EngineEvent> _events = new BlockingCollection<EngineEvent>();
        private readonly ConcurrentDictionary<MtWorkItem, MtRunResult> _results = new ConcurrentDictionary<MtWorkItem, MtRunResult>();
        private readonly ConcurrentDictionary<MtWorkItem, PowerShell> _inFlight = new ConcurrentDictionary<MtWorkItem, PowerShell>();
        private RunspacePool _pool;
        private volatile PowerShell _currentMain;
        private int _finishedCount;
        private int _abandoned;
        private MtRunSummary _summary;

        public InvokeMtEngineRunCommand()
        {
            MaxParallel = 1;
            TimeoutSeconds = 0;
            StopGraceMs = 2000;
        }

        protected override void ProcessRecord()
        {
            if (WorkItem == null) return;
            foreach (var w in WorkItem)
            {
                if (w == null) continue;
                if (string.IsNullOrEmpty(w.Command)) throw new PSArgumentException("A work item has no Command.");
                if (string.IsNullOrEmpty(w.Id)) w.Id = w.Command;
                _items.Add(w);
            }
        }

        protected override void EndProcessing()
        {
            var wall = Stopwatch.StartNew();
            bool usePool = MaxParallel > 1;
            _summary = new MtRunSummary { Total = _items.Count, MaxParallel = MaxParallel };
            MtSession.LastRun = _summary;

            var mainItems = new List<MtWorkItem>();
            var poolItems = new List<MtWorkItem>();
            foreach (var i in _items)
            {
                if (i.IsMainLane || !usePool) mainItems.Add(i); else poolItems.Add(i);
            }

            Task dispatcher = null;
            try
            {
                if (poolItems.Count > 0)
                {
                    _pool = CreatePool();
                    var token = _cts.Token;
                    dispatcher = Task.Run(() => Dispatch(poolItems, token));
                }

                // Main lane: sequential, nested on this thread; worker events are handled between items.
                foreach (var item in mainItems)
                {
                    DrainEvents();
                    if (_cts.IsCancellationRequested) break;
                    Starting(item);
                    var r = RunNested(item);
                    Finished(r, item);
                }

                // Wait for the pool, handling its events on the pipeline thread.
                while (_finishedCount < _items.Count && !_cts.IsCancellationRequested)
                {
                    EngineEvent ev;
                    try { ev = _events.Take(_cts.Token); }
                    catch (OperationCanceledException) { break; }
                    Handle(ev);
                }
            }
            catch (PipelineStoppedException)
            {
                // A Write* call throws this once the host marked the pipeline as stopping (a real Ctrl+C).
                // It can arrive before StopProcessing has run, so cancel here too.
                _cts.Cancel();
                foreach (var kv in _inFlight) { try { kv.Value.BeginStop(null, null); } catch { } }
                throw;
            }
            finally
            {
                if (_cts.IsCancellationRequested)
                {
                    // After a stop request every Write* throws, so only collect from here on.
                    _summary.StopRequested = true;
                    if (dispatcher != null) dispatcher.Wait(TimeSpan.FromMilliseconds(StopGraceMs + 1000));
                    EngineEvent ev;
                    while (_events.TryTake(out ev, 50))
                    {
                        if (!ev.Started) _results[ev.Item] = ev.Result;
                    }
                }
                else if (dispatcher != null)
                {
                    dispatcher.Wait();
                }
                ClosePool();
                Summarise(wall.Elapsed);
            }

            // Items that never started still get a result, so the caller always receives one per item.
            foreach (var i in _items)
            {
                if (!_results.ContainsKey(i))
                {
                    var nr = new MtRunResult(i) { Status = MtRunStatus.NotRun, Reason = "The run was stopped before this test started." };
                    _results[i] = nr;
                    _summary.NotRun++;
                    WriteObject(nr);
                }
            }
        }

        /// <summary>Called on Ctrl+C, on a thread that is not the pipeline thread.</summary>
        protected override void StopProcessing()
        {
            if (_summary != null) _summary.StopRequested = true;
            _cts.Cancel();
            var main = _currentMain;
            if (main != null) { try { main.BeginStop(null, null); } catch { } }
            foreach (var kv in _inFlight)
            {
                try { kv.Value.BeginStop(null, null); } catch { }
            }
        }

        // ------------------------------------------------------------------ events (worker -> pipeline thread)

        private void Post(bool started, MtWorkItem item, MtRunResult result)
        {
            try { _events.Add(new EngineEvent { Started = started, Item = item, Result = result }); }
            catch (InvalidOperationException) { }
        }

        private void DrainEvents()
        {
            EngineEvent ev;
            while (_events.TryTake(out ev)) Handle(ev);
        }

        private void Handle(EngineEvent ev)
        {
            if (ev.Started) Starting(ev.Item);
            else Finished(ev.Result, ev.Item);
        }

        private void Starting(MtWorkItem item)
        {
            if (OnItemStarting != null) OnItemStarting.Invoke(item);
        }

        private void Finished(MtRunResult r, MtWorkItem item)
        {
            _results[item] = r;
            Interlocked.Increment(ref _finishedCount);
            if (!NoStreamReplay.IsPresent) Replay(r);
            if (OnItemFinished != null) OnItemFinished.Invoke(r);
            WriteObject(r);
        }

        private void Replay(MtRunResult r)
        {
            for (int i = 0; i < r.Warnings.Count; i++) WriteWarning(r.Warnings[i].Message);
            for (int i = 0; i < r.Verbose.Count; i++) WriteVerbose(r.Verbose[i].Message);
            for (int i = 0; i < r.Debug.Count; i++) WriteDebug(r.Debug[i].Message);
            for (int i = 0; i < r.Information.Count; i++) WriteInformation(r.Information[i]);
        }

        private void Summarise(TimeSpan wall)
        {
            _summary.WallMs = wall.TotalMilliseconds;
            _summary.AbandonedRunspaces = _abandoned;
            foreach (var r in _results.Values)
            {
                switch (r.Status)
                {
                    case MtRunStatus.Completed: _summary.Completed++; break;
                    case MtRunStatus.Skipped: _summary.Skipped++; break;
                    case MtRunStatus.Error: _summary.Error++; break;
                    case MtRunStatus.Aborted: _summary.Aborted++; break;
                    case MtRunStatus.Timeout: _summary.Timeout++; break;
                    case MtRunStatus.Cancelled: _summary.Cancelled++; break;
                    default: _summary.NotRun++; break;
                }
            }
        }

        // ------------------------------------------------------------------ main lane

        private MtRunResult RunNested(MtWorkItem item)
        {
            var result = new MtRunResult(item) { Lane = "Main", Started = DateTime.Now };
            int timeoutSec = item.TimeoutSeconds ?? TimeoutSeconds;
            var ps = PowerShell.Create(RunspaceMode.CurrentRunspace);
            AddInvocation(ps, item, (object)Module);
            // A nested pipeline does not fill ps.Streams.Warning/Information/Verbose (they go to the host),
            // so every stream is merged into the output and sorted out afterwards, as *>&1 would.
            ps.Commands.Commands[0].MergeMyResults(PipelineResultTypes.All, PipelineResultTypes.Output);
            var output = new PSDataCollection<PSObject>();
            _currentMain = ps;
            int fired = 0;
            Timer timer = null;
            var sw = Stopwatch.StartNew();
            try
            {
                if (timeoutSec > 0)
                {
                    timer = new Timer(_ =>
                    {
                        Interlocked.Exchange(ref fired, 1);
                        try { ps.BeginStop(null, null); } catch { }
                    }, null, TimeSpan.FromSeconds(timeoutSec), Timeout.InfiniteTimeSpan);
                }
                ps.Invoke(null, output);
            }
            catch (PipelineStoppedException)
            {
                // Handled below from the stop state.
            }
            catch (Exception ex)
            {
                result.Status = MtRunStatus.Error;
                result.Reason = Unwrap(ex).Message;
                var rex = Unwrap(ex) as IContainsErrorRecord;
                if (rex != null) result.TerminatingError = rex.ErrorRecord;
            }
            finally
            {
                if (timer != null) timer.Dispose();
                result.Duration = sw.Elapsed;
                _currentMain = null;
            }

            bool stopped = fired == 1 || ps.InvocationStateInfo.State == PSInvocationState.Stopped;
            Interpret(result, output, stopped, fired == 1, timeoutSec);
            // A stop that was not our deadline is the host stopping the pipeline (Ctrl+C). It can happen before
            // StopProcessing runs, so make sure no further item starts.
            if (result.Status == MtRunStatus.Cancelled) _cts.Cancel();
            ps.Dispose();
            return result;
        }

        // ------------------------------------------------------------------ pool lane

        private RunspacePool CreatePool()
        {
            var iss = InitialSessionState.CreateDefault();
            if (PoolModule != null && PoolModule.Length > 0) iss.ImportPSModule(PoolModule);
            var pool = RunspaceFactory.CreateRunspacePool(iss);
            pool.SetMaxRunspaces(MaxParallel);
            pool.ThreadOptions = PSThreadOptions.ReuseThread;
            pool.Open();
            return pool;
        }

        private void ClosePool()
        {
            if (_pool == null) return;
            var pool = _pool;
            _pool = null;
            // Close() waits for every runspace to stop. A runspace stuck in a blocking .NET call cannot be
            // interrupted on .NET Core, so the wait is bounded and the runspace is abandoned otherwise.
            var closeTask = Task.Run(() => { try { pool.Close(); pool.Dispose(); } catch { } });
            closeTask.Wait(TimeSpan.FromMilliseconds(StopGraceMs));
        }

        private void Dispatch(List<MtWorkItem> items, CancellationToken ct)
        {
            var gate = new SemaphoreSlim(MaxParallel, MaxParallel);
            var tasks = new List<Task>();
            foreach (var item in items)
            {
                var it = item;
                try { gate.Wait(ct); }
                catch (OperationCanceledException) { break; }
                tasks.Add(Task.Run(async () =>
                {
                    try { await RunPoolItemAsync(it, ct).ConfigureAwait(false); }
                    finally { gate.Release(); }
                }));
            }
            try { Task.WaitAll(tasks.ToArray()); } catch (AggregateException) { }
        }

        private async Task RunPoolItemAsync(MtWorkItem item, CancellationToken ct)
        {
            var result = new MtRunResult(item) { Lane = "Pool", Started = DateTime.Now };
            var ps = PowerShell.Create();
            ps.RunspacePool = _pool;
            // A pool runspace has its own module instance, found by name.
            object module = Module != null ? (object)Module.Name : null;
            AddInvocation(ps, item, module);
            ps.Commands.Commands[0].MergeMyResults(PipelineResultTypes.All, PipelineResultTypes.Output);
            var output = new PSDataCollection<PSObject>();
            _inFlight[item] = ps;
            int timeoutSec = item.TimeoutSeconds ?? TimeoutSeconds;
            bool stuck = false;
            bool timedOut = false;
            bool stopped = false;
            // The deadline starts when the pipeline is running, not at BeginInvoke: a request can queue for a
            // free runspace, and the first use of a pool runspace pays the module import.
            var running = new TaskCompletionSource<bool>();
            ps.InvocationStateChanged += (s, e) =>
            {
                if (e.InvocationStateInfo.State == PSInvocationState.Running) running.TrySetResult(true);
            };
            Stopwatch sw = null;
            try
            {
                var asyncResult = ps.BeginInvoke<PSObject, PSObject>(null, output);
                var invokeTask = Task.Factory.FromAsync(asyncResult, ar => ps.EndInvoke(ar));
                if (ps.InvocationStateInfo.State == PSInvocationState.Running) running.TrySetResult(true);
                await Task.WhenAny(running.Task, invokeTask).ConfigureAwait(false);
                result.Started = DateTime.Now;
                sw = Stopwatch.StartNew();
                Post(true, item, null);

                var deadline = timeoutSec > 0 ? Task.Delay(TimeSpan.FromSeconds(timeoutSec), ct) : Task.Delay(Timeout.Infinite, ct);
                var winner = await Task.WhenAny(invokeTask, deadline).ConfigureAwait(false);
                if (winner == invokeTask)
                {
                    try { await invokeTask.ConfigureAwait(false); }
                    catch (PipelineStoppedException) { stopped = true; }
                    catch (Exception ex)
                    {
                        result.Status = MtRunStatus.Error;
                        result.Reason = Unwrap(ex).Message;
                    }
                }
                else
                {
                    stopped = true;
                    timedOut = !ct.IsCancellationRequested;
                    result.Duration = sw.Elapsed;
                    var stopSw = Stopwatch.StartNew();
                    try { ps.BeginStop(null, null); } catch { }
                    // Script code honours a stop within milliseconds; a blocking .NET call does not, and nothing
                    // on .NET Core can interrupt it. Report at the deadline and replace the runspace.
                    var done = await Task.WhenAny(invokeTask, Task.Delay(Math.Min(StopGraceMs, 250))).ConfigureAwait(false) == invokeTask;
                    if (done)
                    {
                        result.StopLagMs = (int)stopSw.Elapsed.TotalMilliseconds;
                        try { await invokeTask.ConfigureAwait(false); } catch { }
                    }
                    else
                    {
                        stuck = true;
                        result.StopLagMs = -1;
                        Interlocked.Increment(ref _abandoned);
                        try { _pool.SetMaxRunspaces(_pool.GetMaxRunspaces() + 1); } catch { }
                        var psCopy = ps;
                        var ignored = invokeTask.ContinueWith(_ => { try { psCopy.Dispose(); } catch { } });
                    }
                }
            }
            finally
            {
                if (result.Duration == TimeSpan.Zero && sw != null) result.Duration = sw.Elapsed;
                PowerShell removed;
                _inFlight.TryRemove(item, out removed);
                if (result.Status != MtRunStatus.Error) Interpret(result, Snapshot(output), stopped, timedOut, timeoutSec);
                if (stuck) result.Reason += " The test was still running after the stop request and its runspace was abandoned.";
                if (!stuck) ps.Dispose();
                Post(false, item, result);
            }
        }

        private static List<PSObject> Snapshot(PSDataCollection<PSObject> output)
        {
            var list = new List<PSObject>();
            for (int i = 0; i < output.Count; i++) list.Add(output[i]);
            return list;
        }

        // ------------------------------------------------------------------ helpers

        private static void AddInvocation(PowerShell ps, MtWorkItem item, object defaultModule)
        {
            object module = item.ModuleName != null ? (object)item.ModuleName : defaultModule;
            ps.AddScript(InvocationScript, useLocalScope: false)
              .AddArgument(item.Id)
              .AddArgument(module)
              .AddArgument(item.Command)
              .AddArgument(item.Parameters);
        }

        /// <summary>Sorts the merged output into streams and the outcome, and sets Status and ReturnKind.</summary>
        private static void Interpret(MtRunResult result, IList<PSObject> merged, bool stopped, bool timedOut, int timeoutSec)
        {
            MtOutcome outcome = null;
            if (merged != null)
            {
                for (int i = 0; i < merged.Count; i++)
                {
                    var pso = merged[i];
                    var b = pso == null ? null : pso.BaseObject;
                    if (b is MtOutcome) outcome = (MtOutcome)b;
                    else if (b is WarningRecord) result.Warnings.Add((WarningRecord)b);
                    else if (b is InformationRecord) result.Information.Add((InformationRecord)b);
                    else if (b is VerboseRecord) result.Verbose.Add((VerboseRecord)b);
                    else if (b is DebugRecord) result.Debug.Add((DebugRecord)b);
                    else if (b is ErrorRecord) result.Errors.Add((ErrorRecord)b);
                    // Anything else is output of the invocation script itself, not of the test. Ignore it.
                }
            }

            if (timedOut)
            {
                result.Status = MtRunStatus.Timeout;
                result.Reason = "The test did not finish within " + timeoutSec + " seconds.";
                return;
            }
            if (outcome == null)
            {
                if (result.Status == MtRunStatus.Error) return;
                if (stopped)
                {
                    result.Status = MtRunStatus.Cancelled;
                    result.Reason = "The run was stopped while this test was running.";
                }
                else
                {
                    result.Status = MtRunStatus.Aborted;
                    result.Reason = "The test ended without returning a value or throwing (exit, break or continue outside a loop).";
                }
                return;
            }

            if (outcome.Error != null)
            {
                result.TerminatingError = outcome.Error;
                var fqid = outcome.Error.FullyQualifiedErrorId ?? string.Empty;
                if (fqid.StartsWith(MtSession.SkipErrorId, StringComparison.Ordinal))
                {
                    result.Status = MtRunStatus.Skipped;
                    result.Reason = outcome.Error.Exception != null ? outcome.Error.Exception.Message : null;
                }
                else
                {
                    result.Status = MtRunStatus.Error;
                    result.Reason = outcome.Error.Exception != null ? outcome.Error.Exception.Message : outcome.Error.ToString();
                    result.IsParameterBindingError = outcome.Error.Exception is ParameterBindingException;
                }
                return;
            }

            result.Status = MtRunStatus.Completed;
            if (outcome.Output != null)
            {
                foreach (var o in outcome.Output) result.Output.Add(o);
            }
            result.ReturnKind = Classify(result.Output);
        }

        private static MtReturnKind Classify(List<object> output)
        {
            if (output.Count == 0) return MtReturnKind.Null;
            if (output.Count > 1) return MtReturnKind.Multiple;
            var o = output[0];
            var b = o is PSObject ? ((PSObject)o).BaseObject : o;
            if (b == null) return MtReturnKind.Null;
            if (b is bool) return (bool)b ? MtReturnKind.True : MtReturnKind.False;
            return MtReturnKind.NonBoolean;
        }

        private static Exception Unwrap(Exception ex)
        {
            var agg = ex as AggregateException;
            if (agg != null && agg.InnerExceptions.Count > 0) ex = agg.InnerExceptions[0];
            return ex;
        }
    }

    /// <summary>
    /// Written once by the invocation script to say how the test ended. Public only because the script
    /// creates it; not part of Maester's supported surface.
    /// </summary>
    public sealed class MtOutcome
    {
        public object[] Output { get; private set; }
        public ErrorRecord Error { get; private set; }

        private MtOutcome() { }

        public static MtOutcome Returned(object[] output)
        {
            return new MtOutcome { Output = output ?? new object[0] };
        }

        public static MtOutcome Threw(ErrorRecord error)
        {
            return new MtOutcome { Error = error };
        }
    }
}
