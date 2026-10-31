[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'Pester passes the container parameter to BeforeAll for source and built-module validation.')]
[CmdletBinding()]
param([string] $ModulePath = "$PSScriptRoot/../../Maester.psd1")

BeforeAll {
    Import-Module $ModulePath -Force
    # Real loopback HTTP, with a server-side watchdog independent of the request timeout.
    # No GitHub credentials or external addresses enter this fixture.
    if (-not ('MaesterTests.StalledGitHubResponse' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
namespace MaesterTests {
    public sealed class StalledGitHubResponse : IDisposable {
        private readonly TcpListener listener = new TcpListener(IPAddress.Loopback, 0);
        private readonly CancellationTokenSource stop = new CancellationTokenSource(TimeSpan.FromSeconds(45));
        private readonly Task server;
        public string BaseUri { get; }
        public StalledGitHubResponse(bool stallBody) {
            listener.Start();
            BaseUri = "http://127.0.0.1:" + ((IPEndPoint)listener.LocalEndpoint).Port;
            server = Serve(stallBody);
        }
        private async Task Serve(bool stallBody) {
            try {
                using var client = await listener.AcceptTcpClientAsync(stop.Token);
                using var stream = client.GetStream();
                var header = new StringBuilder();
                var octet = new byte[1];
                while (!header.ToString().EndsWith("\r\n\r\n", StringComparison.Ordinal)) {
                    if (await stream.ReadAsync(octet.AsMemory(), stop.Token) == 0) return;
                    header.Append((char)octet[0]);
                    if (header.Length > 16384) throw new InvalidOperationException("Fixture headers too large.");
                }
                if (stallBody) {
                    var response = Encoding.ASCII.GetBytes("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: 2\r\nConnection: close\r\n\r\n{");
                    await stream.WriteAsync(response.AsMemory(), stop.Token);
                    await stream.FlushAsync(stop.Token);
                }
                await Task.Delay(Timeout.Infinite, stop.Token);
            } catch (OperationCanceledException) { }
        }
        public void Dispose() {
            stop.Cancel();
            listener.Stop();
            try { server.GetAwaiter().GetResult(); } finally { stop.Dispose(); }
        }
    }
}
'@
    }
}

Describe 'GitHub transports terminate real stalled responses' {
    BeforeEach {
        $script:previousNoProxy = $env:NO_PROXY
        $env:NO_PROXY = '127.0.0.1'
        InModuleScope Maester {
            $__MtSession.GitHubAuthHeader = @{}
            $__MtSession.GitHubCache = @{}
            $__MtSession.GitHubRateLimits = $null
        }
    }
    AfterEach {
        $env:NO_PROXY = $script:previousNoProxy
        InModuleScope Maester {
            $__MtSession.GitHubConnection = $null
            $__MtSession.GitHubAuthHeader = $null
            $__MtSession.GitHubCache = @{}
            $__MtSession.GitHubRateLimits = $null
        }
    }

    It 'Times out <Transport> while <Stall> without caching a result' -ForEach @(
        @{ Transport = 'REST'; Stall = 'waiting for headers'; StallBody = $false },
        @{ Transport = 'GraphQL'; Stall = 'reading a stalled body'; StallBody = $true }
    ) {
        $server = [MaesterTests.StalledGitHubResponse]::new($StallBody)
        try {
            InModuleScope Maester -Parameters @{ BaseUri = $server.BaseUri; Transport = $Transport } {
                $__MtSession.GitHubConnection = [pscustomobject]@{ Connected = $true; Organization = 'fixture-org'; ApiBaseUri = $BaseUri; ApiVersion = '2022-11-28' }
                $watch = [System.Diagnostics.Stopwatch]::StartNew()
                $caught = $null
                try {
                    if ($Transport -eq 'REST') { Invoke-MtGitHubRequest '/orgs/fixture-org' -IncludeMetadata | Out-Null }
                    else { Invoke-MtGitHubGraphQLRequest -Query 'query Fixture{viewer{login}}' -Variables @{} -OperationName Fixture | Out-Null }
                } catch { $caught = $_ }
                $watch.Stop()
                $caught | Should -Not -BeNullOrEmpty
                $watch.Elapsed.TotalSeconds | Should -BeGreaterThan 25
                # The 45-second server watchdog must not be what terminates the request.
                $watch.Elapsed.TotalSeconds | Should -BeLessThan 43
                $__MtSession.GitHubCache.Count | Should -Be 0
            }
        } finally { $server.Dispose() }
    }
}
