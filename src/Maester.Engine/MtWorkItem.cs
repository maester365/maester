using System;
using System.Collections;
using System.Collections.Generic;
using System.Management.Automation;

namespace Maester.Engine
{
    /// <summary>One unit of work: call a PowerShell command with optional parameters on a lane.</summary>
    public sealed class MtWorkItem
    {
        /// <summary>Test ID (or instance ID). Used as the key of the result and as the "current test".</summary>
        public string Id { get; set; }

        /// <summary>Title shown by the console renderer while the item runs.</summary>
        public string Title { get; set; }

        /// <summary>Name of the function to call.</summary>
        public string Command { get; set; }

        /// <summary>Parameters splatted onto the command.</summary>
        public Hashtable Parameters { get; set; }

        /// <summary>
        /// Module whose scope the command is invoked in, so that private functions and the module's own
        /// state are used. Overrides the cmdlet's -Module. Custom native tests each run in their own
        /// dynamic module, which cannot be found by name, so the module object is passed.
        /// </summary>
        public PSModuleInfo Module { get; set; }

        /// <summary>Name of the module to invoke the command in, when no Module object is given (pool lanes).</summary>
        public string ModuleName { get; set; }

        /// <summary>'Main' runs nested on the caller's runspace; 'Pool' may run on a worker runspace.</summary>
        public string Lane { get; set; }

        /// <summary>The item must not run concurrently with any other item.</summary>
        public bool Exclusive { get; set; }

        /// <summary>Per-item timeout in seconds; null uses the cmdlet's -TimeoutSeconds, 0 means none.</summary>
        public int? TimeoutSeconds { get; set; }

        /// <summary>Opaque value carried through to the result, for the PowerShell side of the engine.</summary>
        public object Tag { get; set; }

        public MtWorkItem()
        {
            Lane = "Main";
        }

        public bool IsMainLane
        {
            get { return Exclusive || string.Equals(Lane, "Main", StringComparison.OrdinalIgnoreCase); }
        }

        public override string ToString()
        {
            return Id + " (" + Command + ")";
        }
    }

    /// <summary>
    /// How a work item ended, as seen by the scheduler. The PowerShell side turns this, together with what
    /// the test recorded through Add-MtTestResultDetail, into the final Result and reason code.
    /// </summary>
    public enum MtRunStatus
    {
        /// <summary>The item never started (run cancelled first).</summary>
        NotRun,
        /// <summary>The command returned. See ReturnKind.</summary>
        Completed,
        /// <summary>The command ended through Add-MtTestResultDetail -SkippedBecause.</summary>
        Skipped,
        /// <summary>A terminating error ended the command.</summary>
        Error,
        /// <summary>The command did not return or throw: it called exit, or break/continue left the function.</summary>
        Aborted,
        /// <summary>The per-item deadline fired.</summary>
        Timeout,
        /// <summary>The run was stopped (Ctrl+C) while the item was running.</summary>
        Cancelled
    }

    /// <summary>What a completed command returned on its output stream.</summary>
    public enum MtReturnKind
    {
        None,
        True,
        False,
        /// <summary>Nothing, or a single $null.</summary>
        Null,
        /// <summary>A single value that is not a boolean.</summary>
        NonBoolean,
        /// <summary>More than one object.</summary>
        Multiple
    }

    /// <summary>Everything the engine captured for one work item.</summary>
    public sealed class MtRunResult
    {
        public string Id { get; set; }
        public string Command { get; set; }
        public string Lane { get; set; }
        public object Tag { get; set; }
        public MtRunStatus Status { get; set; }
        public MtReturnKind ReturnKind { get; set; }

        /// <summary>Engine explanation for NotRun, Aborted, Timeout and Cancelled, and the message of a terminating error.</summary>
        public string Reason { get; set; }

        /// <summary>The objects the command wrote to its output stream.</summary>
        public List<object> Output { get; private set; }

        /// <summary>The terminating error (or the skip record) that ended the command.</summary>
        public ErrorRecord TerminatingError { get; set; }

        /// <summary>True when the terminating error came from binding the parameters of the command.</summary>
        public bool IsParameterBindingError { get; set; }

        /// <summary>Non-terminating errors written by the command.</summary>
        public List<ErrorRecord> Errors { get; private set; }
        public List<WarningRecord> Warnings { get; private set; }
        public List<InformationRecord> Information { get; private set; }
        public List<VerboseRecord> Verbose { get; private set; }
        public List<DebugRecord> Debug { get; private set; }

        public DateTime Started { get; set; }
        public TimeSpan Duration { get; set; }

        /// <summary>For a timed-out item: milliseconds between BeginStop and the pipeline stopping; -1 when it had not stopped when reported.</summary>
        public int StopLagMs { get; set; }

        public MtRunResult(MtWorkItem item)
        {
            Id = item.Id;
            Command = item.Command;
            Lane = item.IsMainLane ? "Main" : "Pool";
            Tag = item.Tag;
            Status = MtRunStatus.NotRun;
            ReturnKind = MtReturnKind.None;
            Output = new List<object>();
            Errors = new List<ErrorRecord>();
            Warnings = new List<WarningRecord>();
            Information = new List<InformationRecord>();
            Verbose = new List<VerboseRecord>();
            Debug = new List<DebugRecord>();
        }

        /// <summary>The single returned value when ReturnKind is True, False or NonBoolean.</summary>
        public object ReturnValue
        {
            get
            {
                if (Output.Count != 1) return null;
                var o = Output[0] as PSObject;
                return o != null ? o.BaseObject : Output[0];
            }
        }

        public override string ToString()
        {
            return Id + ": " + Status + (Status == MtRunStatus.Completed ? " (" + ReturnKind + ")" : "") + " in " + (int)Duration.TotalMilliseconds + " ms";
        }
    }

    public sealed class MtRunSummary
    {
        public int Total { get; set; }
        public int Completed { get; set; }
        public int Skipped { get; set; }
        public int Error { get; set; }
        public int Aborted { get; set; }
        public int Timeout { get; set; }
        public int Cancelled { get; set; }
        public int NotRun { get; set; }
        public int MaxParallel { get; set; }
        public double WallMs { get; set; }
        public bool StopRequested { get; set; }

        /// <summary>Worker runspaces that did not honour BeginStop within the grace period and were abandoned.</summary>
        public int AbandonedRunspaces { get; set; }

        public override string ToString()
        {
            return string.Format("{0} items in {1:N0} ms: completed {2}, skipped {3}, error {4}, aborted {5}, timeout {6}, cancelled {7}, not run {8}",
                Total, WallMs, Completed, Skipped, Error, Aborted, Timeout, Cancelled, NotRun);
        }
    }
}
