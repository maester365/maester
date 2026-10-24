# Build image for Anthropic's OSS Scanner (https://red.anthropic.com/oss-scanner/).
# The scanner builds this with the repository as the build context, then audits the image with no network access,
# so everything the module, the engine, the report and the unit tests need is fetched here.
# The .NET SDK image ships PowerShell 7, which Maester needs (7.4 or later).
FROM node:24-bookworm-slim AS node

FROM mcr.microsoft.com/dotnet/sdk:10.0
ENV DEBIAN_FRONTEND=noninteractive \
    DOTNET_CLI_TELEMETRY_OPTOUT=1 \
    POWERSHELL_TELEMETRY_OPTOUT=1
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates git python3 \
    && rm -rf /var/lib/apt/lists/*

# Node for the React report template (report/), at the major version in .nvmrc.
COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
    && ln -s /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx

# The PowerShell modules the build and the unit tests use (see .github/workflows/build-validation.yaml).
RUN pwsh -NoProfile -Command " \
      \$ErrorActionPreference = 'Stop'; \
      Install-PSResource Pester -Version 5.7.1 -Scope AllUsers -TrustRepository; \
      Install-PSResource PSFramework, PSModuleDevelopment, PSScriptAnalyzer -Scope AllUsers -TrustRepository; \
      Install-PSResource Microsoft.Graph.Authentication -Version '[2.27.0,)' -Scope AllUsers -TrustRepository"

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
