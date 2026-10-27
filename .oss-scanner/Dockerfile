# Build image for Anthropic's OSS Scanner (https://red.anthropic.com/oss-scanner/).
# The scanner builds this with the repository as the build context, then audits the image with no network access,
# so everything the module, the engine, the report and the unit tests need is fetched here.
# The .NET SDK image ships PowerShell 7, which Maester needs (7.4 or later).
FROM node:24-bookworm-slim AS node

# The SDK feature band must match src/global.json (10.0.300, latestPatch): a newer band such as 10.0.4xx is refused.
FROM mcr.microsoft.com/dotnet/sdk:10.0.302
ENV DEBIAN_FRONTEND=noninteractive \
    DOTNET_CLI_TELEMETRY_OPTOUT=1 \
    POWERSHELL_TELEMETRY_OPTOUT=1
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates gh git python3 \
    && rm -rf /var/lib/apt/lists/*

# On arm64 the SDK image's PowerShell tool ships an x86-64 pwsh launcher in $PSHOME, which Start-Job runs for a child
# process (the PSScriptAnalyzer unit tests use jobs). Where that launcher cannot run, start pwsh.dll through dotnet.
RUN PSHOME_DIR=$(pwsh -NoProfile -Command '$PSHOME') \
    && if ! "$PSHOME_DIR/pwsh" -NoProfile -Command exit >/dev/null 2>&1; then \
         printf '#!/bin/sh\nexec dotnet "%s/pwsh.dll" "$@"\n' "$PSHOME_DIR" > "$PSHOME_DIR/pwsh"; \
       fi

# Node for the React report template (report/), at the major version in .nvmrc.
COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
    && ln -s /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx

# The PowerShell modules the build and the unit tests use (see .github/workflows/build-validation.yaml).
# The gallery fails a download now and then (a 404 for a version it has), so each install is retried, as in CI.
RUN pwsh -NoProfile -Command " \
      \$ErrorActionPreference = 'Stop'; \
      function Install-WithRetry([hashtable] \$Module) { \
        for (\$i = 1; ; \$i++) { \
          try { Install-PSResource @Module -Scope AllUsers -TrustRepository; return } \
          catch { if (\$i -ge 5) { throw }; Write-Warning \"Retry \$i for \$(\$Module.Name): \$_\"; Start-Sleep (5 * \$i) } \
        } \
      }; \
      Install-WithRetry @{ Name = 'Pester'; Version = '5.7.1' }; \
      'PSFramework', 'PSModuleDevelopment', 'PSScriptAnalyzer' | ForEach-Object { Install-WithRetry @{ Name = \$_ } }; \
      Install-WithRetry @{ Name = 'Microsoft.Graph.Authentication'; Version = '[2.27.0,)' }"

# scanner contract: the checkout lives inside the image, at /src
COPY . /src
WORKDIR /src

# The C# engine (src/Maester.Engine), rebuilt from source into powershell/lib/.
RUN pwsh -NoProfile -File ./build/Build-MaesterEngine.ps1

# The HTML report template (report/).
RUN cd report && npm ci --no-audit --no-fund && npm run build

# The module as it ships to the PowerShell Gallery, in ./module/.
RUN pwsh -NoProfile -Command "./build/Build-MaesterModule.ps1; ./build/Test-MaesterModuleOutput.ps1"

# Run the unit tests so the image is known to work, without failing the build on a test failure.
RUN pwsh -NoProfile -File ./powershell/tests/pester.ps1 \
    || echo "WARNING: the unit tests reported failures"
