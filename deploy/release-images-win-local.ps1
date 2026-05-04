param(
    [Parameter(Position = 0)]
    [string]$Action = "up",

    [string]$RemoteHost = "",

    [string]$RemotePassword = "",

    [switch]$PromptRemote,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ExtraArgs = @()
)

$ErrorActionPreference = "Stop"

$ScriptName = "release-images-win-local.ps1"
$ScriptDir = $PSScriptRoot
$RootDir = (Resolve-Path (Join-Path $ScriptDir "..")).Path

function Log {
    param([string]$Message)
    Write-Host "[$ScriptName] $Message"
}

function Die {
    param([string]$Message)
    throw "[$ScriptName] ERROR: $Message"
}

function Get-EnvValue {
    param(
        [string]$Name,
        [string]$Default = ""
    )

    $value = [Environment]::GetEnvironmentVariable($Name, "Process")
    if ([string]::IsNullOrEmpty($value)) {
        return $Default
    }
    return $value
}

function First-Value {
    foreach ($candidate in $args) {
        if (-not [string]::IsNullOrEmpty([string]$candidate)) {
            return [string]$candidate
        }
    }
    return ""
}

function Use-DockerHubMirror {
    param(
        [string]$Image,
        [string]$Mirror
    )

    if ([string]::IsNullOrWhiteSpace($Mirror)) {
        return $Image
    }

    if ($Image -match "/") {
        $firstSegment = ($Image -split "/")[0]
        if ($firstSegment -match "[\.:]" -or $firstSegment -eq "localhost") {
            return $Image
        }
    }

    $prefix = ($Mirror -replace "^https?://", "").TrimEnd("/")
    if ($Image -notmatch "/") {
        return "$prefix/library/$Image"
    }
    return "$prefix/$Image"
}

function Require-Command {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        Die "missing command: $Name"
    }
}

function Invoke-Checked {
    param(
        [string]$File,
        [string[]]$Arguments
    )

    $oldErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        & $File @Arguments
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $oldErrorActionPreference
    }

    if ($exitCode -ne 0) {
        Die "command failed: $File $($Arguments -join ' ')"
    }
}

function Invoke-NativeProbe {
    param(
        [string]$File,
        [string[]]$Arguments
    )

    $oldErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = @(& $File @Arguments 2>&1 | ForEach-Object { [string]$_ })
        $exitCode = $LASTEXITCODE
    } catch {
        $output = @([string]$_)
        $exitCode = 1
    } finally {
        $ErrorActionPreference = $oldErrorActionPreference
    }

    return [pscustomobject]@{
        ExitCode = $exitCode
        Output = $output
    }
}

function Require-DockerDaemon {
    Require-Command docker

    $result = Invoke-NativeProbe docker @("version", "--format", "{{.Server.Version}}")
    $serverVersion = (($result.Output | Select-Object -First 1) -as [string]).Trim()
    if ($result.ExitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace($serverVersion)) {
        return
    }

    $details = (($result.Output | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 3) -join " ")
    if ([string]::IsNullOrWhiteSpace($details)) {
        $details = "docker daemon did not respond"
    }

    Die "Docker is installed but the daemon is not reachable. Start Docker Desktop and wait for the Linux engine, then retry. If you intentionally use another Docker daemon, switch your Docker context or DOCKER_HOST before running. Details: $details"
}

function Split-CommandLine {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return @()
    }

    $items = New-Object System.Collections.Generic.List[string]
    $current = New-Object System.Text.StringBuilder
    $quote = [char]0
    $doubleQuote = [char]34
    $singleQuote = [char]39

    for ($i = 0; $i -lt $Value.Length; $i++) {
        $ch = $Value[$i]

        if ($quote -ne [char]0) {
            if ($ch -eq $quote) {
                $quote = [char]0
            } else {
                [void]$current.Append($ch)
            }
            continue
        }

        if ($ch -eq $doubleQuote -or $ch -eq $singleQuote) {
            $quote = $ch
            continue
        }

        if ([char]::IsWhiteSpace($ch)) {
            if ($current.Length -gt 0) {
                $items.Add($current.ToString())
                [void]$current.Clear()
            }
            continue
        }

        [void]$current.Append($ch)
    }

    if ($quote -ne [char]0) {
        Die "unterminated quote in SSH_OPTS"
    }

    if ($current.Length -gt 0) {
        $items.Add($current.ToString())
    }

    return $items.ToArray()
}

function Test-SshOptionsHaveProxy {
    param([string[]]$Options)

    for ($i = 0; $i -lt $Options.Count; $i++) {
        $option = $Options[$i]
        if ($option -in @("-J", "ProxyJump")) {
            return $true
        }
        if ($option -like "ProxyCommand=*" -or $option -like "ProxyJump=*") {
            return $true
        }
        if ($option -eq "-o" -and $i + 1 -lt $Options.Count) {
            $next = $Options[$i + 1]
            if ($next -like "ProxyCommand=*" -or $next -like "ProxyJump=*") {
                return $true
            }
        }
    }

    return $false
}

function Quote-ProxyCommandPart {
    param([string]$Value)

    if ($Value -match '[\s"]') {
        return '"' + ($Value -replace '"', '\"') + '"'
    }
    return $Value
}

function Find-SshProxyProgram {
    $configured = Get-EnvValue "SSH_PROXY_PROGRAM"
    if (-not [string]::IsNullOrWhiteSpace($configured)) {
        return $configured
    }

    $knownPaths = @(
        "C:\Program Files\Git\mingw64\bin\connect.exe",
        "C:\Program Files\Git\usr\bin\connect.exe",
        "C:\Program Files (x86)\Git\mingw64\bin\connect.exe",
        "C:\Program Files (x86)\Git\usr\bin\connect.exe"
    )
    foreach ($path in $knownPaths) {
        if (Test-Path -LiteralPath $path) {
            return $path
        }
    }

    foreach ($name in @("connect.exe", "connect", "ncat.exe", "ncat")) {
        $command = Get-Command $name -ErrorAction SilentlyContinue
        if ($null -ne $command) {
            return $command.Source
        }
    }

    return ""
}

function Convert-ToSshProxyProgramPath {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path) -or -not ($Path -match '\s')) {
        return $Path
    }

    try {
        $resolved = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
        $fso = New-Object -ComObject Scripting.FileSystemObject
        $file = $fso.GetFile($resolved)
        if (-not [string]::IsNullOrWhiteSpace($file.ShortPath) -and -not ($file.ShortPath -match '\s')) {
            return [string]$file.ShortPath
        }
    } catch {
        return $Path
    }

    return $Path
}

function New-SshProxyCommand {
    param(
        [string]$ProxyType,
        [string]$ProxyHost,
        [string]$ProxyPort
    )

    $type = $ProxyType.ToLowerInvariant()
    if ($type -in @("socks", "socks5", "socks5h")) {
        $type = "socks5"
    } elseif ($type -ne "http") {
        Die "SSH_PROXY_TYPE must be socks5|http"
    }

    $program = Find-SshProxyProgram
    if ([string]::IsNullOrWhiteSpace($program)) {
        Die "SSH proxy requested, but no proxy helper was found. Install Git for Windows or set SSH_PROXY_COMMAND."
    }

    $programForCommand = Convert-ToSshProxyProgramPath $program
    $leaf = [System.IO.Path]::GetFileName($programForCommand).ToLowerInvariant()
    $quotedProgram = Quote-ProxyCommandPart $programForCommand
    $proxy = "$ProxyHost`:$ProxyPort"

    if ($leaf -in @("connect.exe", "connect")) {
        $flag = "-S"
        if ($type -eq "http") {
            $flag = "-H"
        }
        return "$quotedProgram $flag $proxy %h %p"
    }

    if ($leaf -in @("ncat.exe", "ncat")) {
        return "$quotedProgram --proxy $proxy --proxy-type $type %h %p"
    }

    Die "unsupported SSH_PROXY_PROGRAM: $program. Use SSH_PROXY_COMMAND for a custom helper."
}

function Add-SshProxyOptions {
    param([string[]]$Options)

    if (Test-SshOptionsHaveProxy $Options) {
        return $Options
    }

    $proxyCommand = Get-EnvValue "SSH_PROXY_COMMAND"
    if (-not [string]::IsNullOrWhiteSpace($proxyCommand)) {
        return $Options + @("-o", "ProxyCommand=$proxyCommand")
    }

    $proxyUrl = First-Value (Get-EnvValue "SSH_PROXY_URL") (Get-EnvValue "SSH_PROXY")
    $proxyType = Get-EnvValue "SSH_PROXY_TYPE" "socks5"
    $proxyHost = Get-EnvValue "SSH_PROXY_HOST"
    $proxyPort = Get-EnvValue "SSH_PROXY_PORT"

    if (-not [string]::IsNullOrWhiteSpace($proxyUrl)) {
        try {
            $uri = [System.Uri]$proxyUrl
            if (-not $uri.IsAbsoluteUri -or [string]::IsNullOrWhiteSpace($uri.Host) -or $uri.Port -le 0) {
                throw "invalid proxy URL"
            }
            $proxyType = $uri.Scheme
            $proxyHost = $uri.Host
            $proxyPort = [string]$uri.Port
        } catch {
            if ($proxyUrl -match '^([^:]+):(\d+)$') {
                $proxyHost = $Matches[1]
                $proxyPort = $Matches[2]
            } else {
                Die "SSH_PROXY_URL must look like socks5://127.0.0.1:7890 or 127.0.0.1:7890"
            }
        }
    }

    if ([string]::IsNullOrWhiteSpace($proxyHost) -and -not [string]::IsNullOrWhiteSpace($proxyPort)) {
        $proxyHost = "127.0.0.1"
    }

    if ([string]::IsNullOrWhiteSpace($proxyHost) -and [string]::IsNullOrWhiteSpace($proxyPort)) {
        return $Options
    }
    if ([string]::IsNullOrWhiteSpace($proxyHost) -or [string]::IsNullOrWhiteSpace($proxyPort)) {
        Die "set both SSH_PROXY_HOST and SSH_PROXY_PORT, or use SSH_PROXY_URL"
    }

    $proxyCommand = New-SshProxyCommand $proxyType $proxyHost $proxyPort
    Log "using SSH proxy: ${proxyType}://$proxyHost`:$proxyPort"
    return $Options + @("-o", "ProxyCommand=$proxyCommand")
}

function Start-NativeProcess {
    param(
        [string]$File,
        [string[]]$Arguments
    )

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $File
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true

    if ($null -ne $startInfo.GetType().GetProperty("ArgumentList")) {
        foreach ($argument in $Arguments) {
            [void]$startInfo.ArgumentList.Add($argument)
        }
    } else {
        $quoted = foreach ($argument in $Arguments) {
            if ([string]::IsNullOrEmpty($argument)) {
                '""'
            } elseif ($argument -notmatch '[\s"]') {
                $argument
            } else {
                '"' + ($argument -replace '(\\*)"', '$1$1\"' -replace '(\\+)$', '$1$1') + '"'
            }
        }
        $startInfo.Arguments = ($quoted -join " ")
    }

    return [System.Diagnostics.Process]::Start($startInfo)
}

function Get-GitCommit {
    $output = & git -C $RootDir rev-parse --short HEAD 2>$null
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($output)) {
        return ($output | Select-Object -First 1).Trim()
    }
    return "docker"
}

function Test-Enabled {
    param(
        [string]$Value,
        [string]$Name
    )

    switch ($Value.ToLowerInvariant()) {
        "1" { return $true }
        "true" { return $true }
        "yes" { return $true }
        "on" { return $true }
        "0" { return $false }
        "false" { return $false }
        "no" { return $false }
        "off" { return $false }
        default { Die "$Name must be 1|0" }
    }
}

function Test-ImageExists {
    param([string]$Image)

    $result = Invoke-NativeProbe docker @("images", "--quiet", $Image)
    if ($result.ExitCode -ne 0) {
        return $false
    }

    $imageId = $result.Output | Select-Object -First 1
    return (-not [string]::IsNullOrWhiteSpace(($imageId -as [string])))
}

function Get-ImagePlatform {
    param([string]$Image)

    $result = Invoke-NativeProbe docker @("image", "inspect", "--format", "{{.Os}}/{{.Architecture}}{{if .Variant}}/{{.Variant}}{{end}}", $Image)
    if ($result.ExitCode -ne 0) {
        return ""
    }
    return (($result.Output | Select-Object -First 1) -as [string]).Trim()
}

function Test-ImageMatchesPlatform {
    param(
        [string]$Image,
        [string]$Platform
    )

    $actual = Get-ImagePlatform $Image
    return ($actual -eq $Platform -or $actual.StartsWith("$Platform/"))
}

function Get-BuildDockerfile {
    param(
        [string]$Dockerfile,
        [string]$Label
    )

    $skipSyntax = Get-EnvValue "SKIP_DOCKERFILE_SYNTAX" "1"
    if (-not (Test-Enabled $skipSyntax "SKIP_DOCKERFILE_SYNTAX")) {
        return $Dockerfile
    }

    $firstLine = [System.IO.File]::ReadLines($Dockerfile) | Select-Object -First 1
    if ($firstLine -notmatch '^\s*#\s*syntax=') {
        return $Dockerfile
    }

    $buildDir = Join-Path $RuntimeDir "build"
    New-Item -ItemType Directory -Force -Path $buildDir | Out-Null

    $fallbackDockerfile = Join-Path $buildDir ("$([System.IO.Path]::GetFileName($Dockerfile)).nosyntax")
    $lines = [System.IO.File]::ReadAllLines($Dockerfile)
    if ($lines.Length -le 1) {
        return $Dockerfile
    }

    Write-LinesUtf8NoBom $fallbackDockerfile $lines[1..($lines.Length - 1)]
    Log "using $Label Dockerfile without syntax directive: $fallbackDockerfile"
    return $fallbackDockerfile
}

function Ensure-BaseImageOnce {
    param(
        [string]$TargetImage,
        [string]$SourceImage,
        [string]$Label
    )

    Log "checking $Label image: $TargetImage"
    if (Test-ImageExists $TargetImage) {
        if (Test-ImageMatchesPlatform $TargetImage $Platform) {
            Log "$Label image already exists for $Platform"
            return
        }

        $actual = Get-ImagePlatform $TargetImage
        Log "$Label image platform mismatch, recreating: $TargetImage ($actual)"
        Invoke-Checked docker @("rmi", "-f", $TargetImage)
    }

    Log "pulling $SourceImage ($Platform) and tagging $TargetImage"
    Invoke-Checked docker @("pull", "--platform", $Platform, $SourceImage)
    Invoke-Checked docker @("tag", $SourceImage, $TargetImage)
}

function Rebuild-Image {
    param(
        [string]$Image,
        [string]$Dockerfile,
        [string]$Label,
        [string[]]$BuildArgs = @()
    )

    Log "building $Label image: $Image"
    if ([string]::IsNullOrEmpty($env:DOCKER_BUILDKIT)) {
        $env:DOCKER_BUILDKIT = "1"
    }

    $buildDockerfile = Get-BuildDockerfile $Dockerfile $Label
    $arguments = @("build", "--platform", $Platform, "-f", $buildDockerfile, "-t", $Image) + $BuildArgs + @($RootDir)
    Invoke-Checked docker $arguments
}

function Build-Images {
    Require-DockerDaemon

    Log "project dir: $RootDir"
    Log "image prefix: $ProjectName"
    Log "business tag: $Tag"
    Log "target platform: $Platform"
    Log "docker hub mirror: $DockerHubMirror"
    Log "apk mirror: $ApkMirror"
    Log "npm registry: $NpmRegistry"
    Log "source images:"
    Log "  Redis    $RedisSourceImage"
    Log "  Go       $GolangImage"
    Log "  Alpine   $AlpineImage"
    Log "  Postgres $PostgresImage"
    Log "  Node     $NodeImage"
    Log "  Nginx    $NginxImage"

    Ensure-BaseImageOnce $RedisImage $RedisSourceImage "Redis"

    if (Test-Enabled $BuildBackend "BUILD_BACKEND") {
        Rebuild-Image $BackendImage (Join-Path $RootDir "deploy\Dockerfile.backend") "backend" @(
            "--build-arg", "GOLANG_IMAGE=$GolangImage",
            "--build-arg", "ALPINE_IMAGE=$AlpineImage",
            "--build-arg", "POSTGRES_IMAGE=$PostgresImage",
            "--build-arg", "VERSION=$Version",
            "--build-arg", "COMMIT=$Commit",
            "--build-arg", "DATE=$Date",
            "--build-arg", "GOPROXY=$GoProxy",
            "--build-arg", "GOSUMDB=$GoSumDB",
            "--build-arg", "APK_MIRROR=$ApkMirror"
        )
    } else {
        if (-not (Test-ImageExists $BackendImage)) {
            Die "BUILD_BACKEND=0 but backend image is missing: $BackendImage"
        }
        Log "skipping backend build and reusing $BackendImage"
    }

    if (Test-Enabled $BuildFrontend "BUILD_FRONTEND") {
        Rebuild-Image $FrontendImage (Join-Path $RootDir "deploy\Dockerfile.frontend") "frontend" @(
            "--build-arg", "NODE_IMAGE=$NodeImage",
            "--build-arg", "NGINX_IMAGE=$NginxImage",
            "--build-arg", "NPM_REGISTRY=$NpmRegistry"
        )
    } else {
        if (-not (Test-ImageExists $FrontendImage)) {
            Die "BUILD_FRONTEND=0 but frontend image is missing: $FrontendImage"
        }
        Log "skipping frontend build and reusing $FrontendImage"
    }

    Log "images ready:"
    Log "  Redis    $RedisImage"
    Log "  Backend  $BackendImage"
    Log "  Frontend $FrontendImage"
}

function Read-DotEnvValue {
    param(
        [string]$Key,
        [string]$File
    )

    if (-not (Test-Path -LiteralPath $File)) {
        return ""
    }

    foreach ($line in [System.IO.File]::ReadLines($File)) {
        if ($line -match "^\s*#") {
            continue
        }
        if ($line -match "^\s*$([regex]::Escape($Key))=(.*)$") {
            $value = $Matches[1].TrimEnd("`r")
            if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) {
                $value = $value.Substring(1, $value.Length - 2)
            }
            return $value
        }
    }

    return ""
}

function Convert-ToDockerHostPath {
    param([string]$Path)

    return ((Resolve-Path -LiteralPath $Path).Path -replace "\\", "/")
}

function Write-Utf8NoBom {
    param(
        [string]$Path,
        [string]$Content
    )

    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $encoding)
}

function Write-LinesUtf8NoBom {
    param(
        [string]$Path,
        [string[]]$Lines
    )

    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllLines($Path, $Lines, $encoding)
}

function Add-RuntimeEnvLine {
    param(
        [System.Collections.Generic.List[string]]$Lines,
        [string]$Key,
        [AllowNull()][string]$Value
    )

    if ($null -eq $Value) {
        $Value = ""
    }
    $Lines.Add("$Key=$Value")
}

function Write-RuntimeEnv {
    New-Item -ItemType Directory -Force -Path $RuntimeDir, (Join-Path $RuntimeDir "data"), (Join-Path $RuntimeDir "redis_data") | Out-Null

    $databaseUser = First-Value (Get-EnvValue "DATABASE_USER") (Read-DotEnvValue "DATABASE_USER" $EnvFile) (Read-DotEnvValue "POSTGRES_USER" $EnvFile) "sub2api"
    $databasePassword = First-Value (Get-EnvValue "DATABASE_PASSWORD") (Read-DotEnvValue "DATABASE_PASSWORD" $EnvFile) (Read-DotEnvValue "POSTGRES_PASSWORD" $EnvFile)
    $databaseDbName = First-Value (Get-EnvValue "DATABASE_DBNAME") (Read-DotEnvValue "DATABASE_DBNAME" $EnvFile) (Read-DotEnvValue "POSTGRES_DB" $EnvFile) "sub2api"
    $databaseSslMode = First-Value (Get-EnvValue "DATABASE_SSLMODE") (Read-DotEnvValue "DATABASE_SSLMODE" $EnvFile) "disable"
    $redisPassword = First-Value (Get-EnvValue "REDIS_PASSWORD") (Read-DotEnvValue "REDIS_PASSWORD" $EnvFile)
    $redisDb = First-Value (Get-EnvValue "REDIS_DB") (Read-DotEnvValue "REDIS_DB" $EnvFile) "0"
    $adminEmail = First-Value (Get-EnvValue "ADMIN_EMAIL") (Read-DotEnvValue "ADMIN_EMAIL" $EnvFile) "admin@sub2api.local"
    $adminPassword = First-Value (Get-EnvValue "ADMIN_PASSWORD") (Read-DotEnvValue "ADMIN_PASSWORD" $EnvFile)
    $jwtSecret = First-Value (Get-EnvValue "JWT_SECRET") (Read-DotEnvValue "JWT_SECRET" $EnvFile)
    $totpKey = First-Value (Get-EnvValue "TOTP_ENCRYPTION_KEY") (Read-DotEnvValue "TOTP_ENCRYPTION_KEY" $EnvFile)

    if ([string]::IsNullOrEmpty($databasePassword)) {
        Die "database password is empty. Set DATABASE_PASSWORD or POSTGRES_PASSWORD in $EnvFile"
    }

    $lines = New-Object System.Collections.Generic.List[string]
    Add-RuntimeEnvLine $lines "COMPOSE_PROJECT_NAME" $ComposeProjectName
    Add-RuntimeEnvLine $lines "PROJECT_NAME" $ProjectName
    Add-RuntimeEnvLine $lines "LOCAL_OS" $LocalOs
    Add-RuntimeEnvLine $lines "BACKEND_IMAGE" $BackendImage
    Add-RuntimeEnvLine $lines "FRONTEND_IMAGE" $FrontendImage
    Add-RuntimeEnvLine $lines "REDIS_IMAGE" $RedisImage
    Add-RuntimeEnvLine $lines "BIND_HOST" $BindHost
    Add-RuntimeEnvLine $lines "SERVER_PORT" $ServerPort
    Add-RuntimeEnvLine $lines "SERVER_MODE" $ServerMode
    Add-RuntimeEnvLine $lines "RUN_MODE" $RunMode
    Add-RuntimeEnvLine $lines "TZ" $TimeZone
    Add-RuntimeEnvLine $lines "DATA_DIR_HOST" (Convert-ToDockerHostPath (Join-Path $RuntimeDir "data"))
    Add-RuntimeEnvLine $lines "REDIS_DATA_DIR_HOST" (Convert-ToDockerHostPath (Join-Path $RuntimeDir "redis_data"))

    Add-RuntimeEnvLine $lines "AUTO_SETUP" "true"
    Add-RuntimeEnvLine $lines "DATABASE_HOST" $AppDatabaseHost
    Add-RuntimeEnvLine $lines "DATABASE_PORT" $AppDatabasePort
    Add-RuntimeEnvLine $lines "DATABASE_USER" $databaseUser
    Add-RuntimeEnvLine $lines "DATABASE_PASSWORD" $databasePassword
    Add-RuntimeEnvLine $lines "DATABASE_DBNAME" $databaseDbName
    Add-RuntimeEnvLine $lines "DATABASE_SSLMODE" $databaseSslMode
    Add-RuntimeEnvLine $lines "DATABASE_MAX_OPEN_CONNS" (First-Value (Get-EnvValue "DATABASE_MAX_OPEN_CONNS") (Read-DotEnvValue "DATABASE_MAX_OPEN_CONNS" $EnvFile) "50")
    Add-RuntimeEnvLine $lines "DATABASE_MAX_IDLE_CONNS" (First-Value (Get-EnvValue "DATABASE_MAX_IDLE_CONNS") (Read-DotEnvValue "DATABASE_MAX_IDLE_CONNS" $EnvFile) "10")
    Add-RuntimeEnvLine $lines "DATABASE_CONN_MAX_LIFETIME_MINUTES" (First-Value (Get-EnvValue "DATABASE_CONN_MAX_LIFETIME_MINUTES") (Read-DotEnvValue "DATABASE_CONN_MAX_LIFETIME_MINUTES" $EnvFile) "30")
    Add-RuntimeEnvLine $lines "DATABASE_CONN_MAX_IDLE_TIME_MINUTES" (First-Value (Get-EnvValue "DATABASE_CONN_MAX_IDLE_TIME_MINUTES") (Read-DotEnvValue "DATABASE_CONN_MAX_IDLE_TIME_MINUTES" $EnvFile) "5")
    Add-RuntimeEnvLine $lines "DATABASE_MIGRATION_TIMEOUT_SECONDS" (First-Value (Get-EnvValue "DATABASE_MIGRATION_TIMEOUT_SECONDS") (Read-DotEnvValue "DATABASE_MIGRATION_TIMEOUT_SECONDS" $EnvFile) "600")

    Add-RuntimeEnvLine $lines "REDIS_HOST" "redis"
    Add-RuntimeEnvLine $lines "REDIS_PORT" "6379"
    Add-RuntimeEnvLine $lines "REDIS_PASSWORD" $redisPassword
    Add-RuntimeEnvLine $lines "REDISCLI_AUTH" $redisPassword
    Add-RuntimeEnvLine $lines "REDIS_DB" $redisDb
    Add-RuntimeEnvLine $lines "REDIS_POOL_SIZE" (First-Value (Get-EnvValue "REDIS_POOL_SIZE") (Read-DotEnvValue "REDIS_POOL_SIZE" $EnvFile) "1024")
    Add-RuntimeEnvLine $lines "REDIS_MIN_IDLE_CONNS" (First-Value (Get-EnvValue "REDIS_MIN_IDLE_CONNS") (Read-DotEnvValue "REDIS_MIN_IDLE_CONNS" $EnvFile) "10")
    Add-RuntimeEnvLine $lines "REDIS_ENABLE_TLS" (First-Value (Get-EnvValue "REDIS_ENABLE_TLS") (Read-DotEnvValue "REDIS_ENABLE_TLS" $EnvFile) "false")

    Add-RuntimeEnvLine $lines "ADMIN_EMAIL" $adminEmail
    Add-RuntimeEnvLine $lines "ADMIN_PASSWORD" $adminPassword
    Add-RuntimeEnvLine $lines "JWT_SECRET" $jwtSecret
    Add-RuntimeEnvLine $lines "JWT_EXPIRE_HOUR" (First-Value (Get-EnvValue "JWT_EXPIRE_HOUR") (Read-DotEnvValue "JWT_EXPIRE_HOUR" $EnvFile) "24")
    Add-RuntimeEnvLine $lines "TOTP_ENCRYPTION_KEY" $totpKey

    Add-RuntimeEnvLine $lines "GEMINI_OAUTH_CLIENT_ID" (First-Value (Get-EnvValue "GEMINI_OAUTH_CLIENT_ID") (Read-DotEnvValue "GEMINI_OAUTH_CLIENT_ID" $EnvFile))
    Add-RuntimeEnvLine $lines "GEMINI_OAUTH_CLIENT_SECRET" (First-Value (Get-EnvValue "GEMINI_OAUTH_CLIENT_SECRET") (Read-DotEnvValue "GEMINI_OAUTH_CLIENT_SECRET" $EnvFile))
    Add-RuntimeEnvLine $lines "GEMINI_OAUTH_SCOPES" (First-Value (Get-EnvValue "GEMINI_OAUTH_SCOPES") (Read-DotEnvValue "GEMINI_OAUTH_SCOPES" $EnvFile))
    Add-RuntimeEnvLine $lines "GEMINI_QUOTA_POLICY" (First-Value (Get-EnvValue "GEMINI_QUOTA_POLICY") (Read-DotEnvValue "GEMINI_QUOTA_POLICY" $EnvFile))
    Add-RuntimeEnvLine $lines "GEMINI_CLI_OAUTH_CLIENT_SECRET" (First-Value (Get-EnvValue "GEMINI_CLI_OAUTH_CLIENT_SECRET") (Read-DotEnvValue "GEMINI_CLI_OAUTH_CLIENT_SECRET" $EnvFile))
    Add-RuntimeEnvLine $lines "ANTIGRAVITY_OAUTH_CLIENT_SECRET" (First-Value (Get-EnvValue "ANTIGRAVITY_OAUTH_CLIENT_SECRET") (Read-DotEnvValue "ANTIGRAVITY_OAUTH_CLIENT_SECRET" $EnvFile))

    Write-LinesUtf8NoBom $RuntimeEnvFile $lines.ToArray()
}

function Write-RuntimeCompose {
    New-Item -ItemType Directory -Force -Path $RuntimeDir | Out-Null

    $content = @'
services:
  frontend:
    image: ${FRONTEND_IMAGE}
    container_name: ${PROJECT_NAME}-${LOCAL_OS}-frontend
    restart: unless-stopped
    ports:
      - "${BIND_HOST}:${SERVER_PORT}:80"
    depends_on:
      backend:
        condition: service_healthy
    networks:
      - local-network
    healthcheck:
      test: ["CMD", "wget", "-q", "-T", "3", "-O", "/dev/null", "http://127.0.0.1/health"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 10s

  backend:
    image: ${BACKEND_IMAGE}
    container_name: ${PROJECT_NAME}-${LOCAL_OS}-backend
    restart: unless-stopped
    ulimits:
      nofile:
        soft: 100000
        hard: 100000
    env_file:
      - ./local.env
    environment:
      - SERVER_HOST=0.0.0.0
      - SERVER_PORT=8080
    extra_hosts:
      - "host.docker.internal:host-gateway"
    volumes:
      - type: bind
        source: ${DATA_DIR_HOST}
        target: /app/data
    depends_on:
      redis:
        condition: service_healthy
    networks:
      - local-network
    healthcheck:
      test: ["CMD", "wget", "-q", "-T", "5", "-O", "/dev/null", "http://localhost:8080/health"]
      interval: 15s
      timeout: 10s
      retries: 20
      start_period: 10m

  redis:
    image: ${REDIS_IMAGE}
    container_name: ${PROJECT_NAME}-${LOCAL_OS}-redis
    restart: unless-stopped
    env_file:
      - ./local.env
    volumes:
      - type: bind
        source: ${REDIS_DATA_DIR_HOST}
        target: /data
    command: >
      sh -c '
        redis-server
        --save 60 1
        --appendonly yes
        --appendfsync everysec
        $${REDIS_PASSWORD:+--requirepass "$$REDIS_PASSWORD"}'
    networks:
      - local-network
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 5s

networks:
  local-network:
    driver: bridge
'@

    Write-Utf8NoBom $RuntimeComposeFile $content
}

function Write-RuntimeFiles {
    Write-RuntimeEnv
    Write-RuntimeCompose
    Log "runtime compose: $RuntimeComposeFile"
    Log "runtime env: $RuntimeEnvFile"
}

function Test-PortOpen {
    param(
        [string]$HostName,
        [int]$Port
    )

    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $result = $client.BeginConnect($HostName, $Port, $null, $null)
        if (-not $result.AsyncWaitHandle.WaitOne(1000, $false)) {
            return $false
        }
        $client.EndConnect($result)
        return $true
    } catch {
        return $false
    } finally {
        $client.Close()
    }
}

function Get-RemotePasswordValue {
    return (First-Value $RemotePassword (Get-EnvValue "REMOTE_PASSWORD") (Get-EnvValue "SSHPASS"))
}

function ConvertFrom-SecureStringToPlainText {
    param([Security.SecureString]$SecureValue)

    if ($null -eq $SecureValue) {
        return ""
    }

    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureValue)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
    } finally {
        if ($ptr -ne [IntPtr]::Zero) {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
        }
    }
}

function Prompt-RemoteConnectionIfNeeded {
    $resolvedRemoteHost = First-Value $RemoteHost (Get-EnvValue "REMOTE_HOST")
    if ($PromptRemote -or [string]::IsNullOrWhiteSpace($resolvedRemoteHost)) {
        $hostPrompt = "Remote SSH host/IP"
        if (-not [string]::IsNullOrWhiteSpace($resolvedRemoteHost)) {
            $hostPrompt += " [$resolvedRemoteHost]"
        }

        $inputHost = Read-Host $hostPrompt
        if (-not [string]::IsNullOrWhiteSpace($inputHost)) {
            $script:RemoteHost = $inputHost.Trim()
        } else {
            $script:RemoteHost = $resolvedRemoteHost
        }
    } else {
        $script:RemoteHost = $resolvedRemoteHost
    }

    if ([string]::IsNullOrWhiteSpace($script:RemoteHost)) {
        Die "remote host is empty. Set -RemoteHost, REMOTE_HOST, or enter it when prompted"
    }

    $resolvedPassword = Get-RemotePasswordValue
    if ($PromptRemote -or [string]::IsNullOrEmpty($resolvedPassword)) {
        $securePassword = Read-Host "Remote SSH password (leave empty to use SSH key)" -AsSecureString
        $plainPassword = ConvertFrom-SecureStringToPlainText $securePassword
        if (-not [string]::IsNullOrEmpty($plainPassword)) {
            $script:RemotePassword = $plainPassword
        }
    }
}

function Enable-AskPass {
    $password = Get-RemotePasswordValue
    if ([string]::IsNullOrEmpty($password)) {
        return $null
    }

    $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("sub2api-ssh-askpass-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $passwordFile = Join-Path $dir "password.txt"
    $askPassFile = Join-Path $dir "askpass.cmd"

    Write-Utf8NoBom $passwordFile $password
    [System.IO.File]::WriteAllText(
        $askPassFile,
        "@echo off`r`npowershell -NoProfile -ExecutionPolicy Bypass -Command ""`$p = Get-Content -Raw -LiteralPath `$env:SUB2API_REMOTE_PASSWORD_FILE; [Console]::Out.Write(`$p)""`r`n",
        [System.Text.Encoding]::ASCII
    )

    $state = @{
        Dir = $dir
        OLD_SUB2API_REMOTE_PASSWORD_FILE = [Environment]::GetEnvironmentVariable("SUB2API_REMOTE_PASSWORD_FILE", "Process")
        OLD_SSH_ASKPASS = [Environment]::GetEnvironmentVariable("SSH_ASKPASS", "Process")
        OLD_SSH_ASKPASS_REQUIRE = [Environment]::GetEnvironmentVariable("SSH_ASKPASS_REQUIRE", "Process")
        OLD_DISPLAY = [Environment]::GetEnvironmentVariable("DISPLAY", "Process")
    }

    $env:SUB2API_REMOTE_PASSWORD_FILE = $passwordFile
    $env:SSH_ASKPASS = $askPassFile
    $env:SSH_ASKPASS_REQUIRE = "force"
    if ([string]::IsNullOrEmpty($env:DISPLAY)) {
        $env:DISPLAY = "1"
    }

    return $state
}

function Restore-EnvVar {
    param(
        [string]$Name,
        [AllowNull()][string]$Value
    )

    if ($null -eq $Value) {
        [Environment]::SetEnvironmentVariable($Name, $null, "Process")
    } else {
        [Environment]::SetEnvironmentVariable($Name, $Value, "Process")
    }
}

function Disable-AskPass {
    param($State)

    if ($null -eq $State) {
        return
    }

    Restore-EnvVar "SUB2API_REMOTE_PASSWORD_FILE" $State.OLD_SUB2API_REMOTE_PASSWORD_FILE
    Restore-EnvVar "SSH_ASKPASS" $State.OLD_SSH_ASKPASS
    Restore-EnvVar "SSH_ASKPASS_REQUIRE" $State.OLD_SSH_ASKPASS_REQUIRE
    Restore-EnvVar "DISPLAY" $State.OLD_DISPLAY

    if (Test-Path -LiteralPath $State.Dir) {
        Remove-Item -LiteralPath $State.Dir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-SshRemote {
    param(
        [string]$RemoteCommand,
        [switch]$AllowFailure
    )

    Require-Command ssh
    $remote = "$RemoteUser@$RemoteHost"
    $sshArgs = @("-p", $RemotePort) + $SshOptions + @($remote, $RemoteCommand)
    $askPassState = Enable-AskPass

    try {
        $oldErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        try {
            $output = @(& ssh @sshArgs 2>&1 | ForEach-Object { [string]$_ })
            $exitCode = $LASTEXITCODE
        } finally {
            $ErrorActionPreference = $oldErrorActionPreference
        }
    } finally {
        Disable-AskPass $askPassState
    }

    if ($exitCode -ne 0 -and -not $AllowFailure) {
        $text = ($output | Out-String).Trim()
        Die "ssh command failed on $remote. $text"
    }

    return [pscustomobject]@{
        ExitCode = $exitCode
        Output = @($output)
    }
}

function Get-RemoteDatabaseContainerIp {
    $format = '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'
    $command = "container='$RemoteDatabaseContainer'; if command -v docker >/dev/null 2>&1; then docker inspect -f '$format' `"`$container`" 2>/dev/null || sudo docker inspect -f '$format' `"`$container`"; fi"
    $result = Invoke-SshRemote $command
    foreach ($line in $result.Output) {
        $trimmed = ([string]$line).Trim()
        if (-not [string]::IsNullOrEmpty($trimmed)) {
            return $trimmed
        }
    }
    return ""
}

function Test-RemoteHostListensOnDatabasePort {
    $command = "ss -ltn 2>/dev/null | awk '{print `$4}' | grep -Eq '(:|\.)$RemoteDatabasePort$'"
    $result = Invoke-SshRemote $command -AllowFailure
    return ($result.ExitCode -eq 0)
}

function Resolve-RemoteDatabaseHost {
    switch ($RemoteDatabaseDiscovery) {
        "direct" { return $RemoteDatabaseHost }
        "container" {
            $resolved = Get-RemoteDatabaseContainerIp
            if ([string]::IsNullOrEmpty($resolved)) {
                Die "failed to resolve container IP for $RemoteDatabaseContainer on $RemoteHost"
            }
            return $resolved
        }
        "auto" {}
        default { Die "REMOTE_DATABASE_DISCOVERY must be auto|direct|container" }
    }

    if ($RemoteDatabaseHost -in @("127.0.0.1", "localhost", "::1")) {
        if (Test-RemoteHostListensOnDatabasePort) {
            return $RemoteDatabaseHost
        }

        $resolved = Get-RemoteDatabaseContainerIp
        if ([string]::IsNullOrEmpty($resolved)) {
            Die "remote host does not listen on $RemoteDatabaseHost`:$RemoteDatabasePort and container $RemoteDatabaseContainer could not be resolved"
        }
        return $resolved
    }

    return $RemoteDatabaseHost
}

function Get-PortOwnerCommandLine {
    param(
        [string]$HostName,
        [int]$Port
    )

    $connections = @(Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue)
    if ($connections.Count -eq 0) {
        return $null
    }

    $connection = $connections | Where-Object { $_.LocalAddress -eq $HostName } | Select-Object -First 1
    if ($null -eq $connection) {
        $connection = $connections | Select-Object -First 1
    }

    $process = Get-CimInstance Win32_Process -Filter "ProcessId=$($connection.OwningProcess)" -ErrorAction SilentlyContinue
    if ($null -eq $process) {
        return ""
    }
    return [string]$process.CommandLine
}

function Start-Tunnel {
    if (-not (Test-Enabled $StartTunnel "START_TUNNEL")) {
        Log "START_TUNNEL=0, skipping SSH tunnel"
        return
    }

    Require-Command ssh

    $remote = "$RemoteUser@$RemoteHost"
    $resolvedRemoteDatabaseHost = Resolve-RemoteDatabaseHost
    $forward = "$LocalDatabaseBindHost`:$LocalDatabasePort`:$resolvedRemoteDatabaseHost`:$RemoteDatabasePort"

    if (Test-PortOpen $LocalDatabaseBindHost ([int]$LocalDatabasePort)) {
        $commandLine = Get-PortOwnerCommandLine $LocalDatabaseBindHost ([int]$LocalDatabasePort)
        if (-not [string]::IsNullOrEmpty($commandLine)) {
            $expectedFragment = "$LocalDatabaseBindHost`:$LocalDatabasePort`:$resolvedRemoteDatabaseHost`:$RemoteDatabasePort"
            if ($commandLine -like "*ssh*" -and $commandLine -like "*$expectedFragment*" -and $commandLine -like "*$remote*") {
                Log "reusing local SSH tunnel on $LocalDatabaseBindHost`:$LocalDatabasePort"
                return
            }
            if ($commandLine -like "*ssh*") {
                Log "found stale SSH tunnel on $LocalDatabaseBindHost`:$LocalDatabasePort, recreating it"
                $connections = @(Get-NetTCPConnection -LocalPort ([int]$LocalDatabasePort) -State Listen -ErrorAction SilentlyContinue)
                foreach ($connection in $connections) {
                    Stop-Process -Id $connection.OwningProcess -Force -ErrorAction SilentlyContinue
                }
                Start-Sleep -Seconds 1
            } else {
                Die "local port $LocalDatabaseBindHost`:$LocalDatabasePort is already in use by another process: $commandLine"
            }
        } else {
            Die "local port $LocalDatabaseBindHost`:$LocalDatabasePort is already in use"
        }
    }

    Log "opening SSH tunnel: $forward via $remote"

    $sshArgs = @("-N", "-p", $RemotePort) + $SshOptions + @("-L", $forward, $remote)
    $sshCommand = (Get-Command ssh).Source
    $askPassState = Enable-AskPass
    try {
        $process = Start-NativeProcess $sshCommand $sshArgs
        $ready = $false
        for ($i = 0; $i -lt 20; $i++) {
            Start-Sleep -Seconds 1
            if (Test-PortOpen $LocalDatabaseBindHost ([int]$LocalDatabasePort)) {
                $ready = $true
                break
            }
            if ($process.HasExited) {
                break
            }
        }

        if (-not $ready) {
            if (-not $process.HasExited) {
                Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
            }
            Die "SSH tunnel did not become ready on $LocalDatabaseBindHost`:$LocalDatabasePort"
        }
    } finally {
        Disable-AskPass $askPassState
    }
}

function Find-Compose {
    if (Get-Command docker -ErrorAction SilentlyContinue) {
        $dockerCompose = Invoke-NativeProbe docker @("compose", "version")
        if ($dockerCompose.ExitCode -eq 0) {
            return [pscustomobject]@{
                File = "docker"
                Prefix = @("compose")
            }
        }
    }

    if (Get-Command docker-compose -ErrorAction SilentlyContinue) {
        $dockerCompose = Invoke-NativeProbe docker-compose @("version")
        if ($dockerCompose.ExitCode -eq 0) {
            return [pscustomobject]@{
                File = "docker-compose"
                Prefix = @()
            }
        }
    }

    Die "missing docker compose or docker-compose"
}

function Invoke-Compose {
    param([string[]]$Arguments)

    $compose = Find-Compose
    if ($Arguments.Count -eq 0 -or $Arguments[0] -ne "config") {
        Require-DockerDaemon
    }

    $oldConvert = $env:COMPOSE_CONVERT_WINDOWS_PATHS
    $env:COMPOSE_CONVERT_WINDOWS_PATHS = First-Value (Get-EnvValue "COMPOSE_CONVERT_WINDOWS_PATHS") "0"
    $oldErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $composeArgs = $compose.Prefix + @("--env-file", $RuntimeEnvFile, "-f", $RuntimeComposeFile) + $Arguments
        & $compose.File @composeArgs
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $oldErrorActionPreference
        if ($null -eq $oldConvert) {
            [Environment]::SetEnvironmentVariable("COMPOSE_CONVERT_WINDOWS_PATHS", $null, "Process")
        } else {
            $env:COMPOSE_CONVERT_WINDOWS_PATHS = $oldConvert
        }
    }

    if ($exitCode -ne 0) {
        Die "docker compose failed: $($Arguments -join ' ')"
    }
}

function Show-Usage {
    @"
Usage:
  .\deploy\$ScriptName up       Build images, open the SSH DB tunnel, and start local Docker services
  .\deploy\$ScriptName deploy   Same as up; Windows-friendly alias for local release
  .\deploy\$ScriptName build    Build backend/frontend and prepare the local Redis image
  .\deploy\$ScriptName tunnel   Open only the SSH tunnel to the remote PostgreSQL service
  .\deploy\$ScriptName down     Stop local Docker services
  .\deploy\$ScriptName restart  Recreate backend/frontend/redis
  .\deploy\$ScriptName ps       Show local Docker services
  .\deploy\$ScriptName logs     Follow local Docker logs
  .\deploy\$ScriptName config   Render the generated compose config

PowerShell password examples:
  .\deploy\$ScriptName deploy -RemoteHost '43.160.239.168' -RemotePassword '<ssh-password>'
  .\deploy\$ScriptName deploy -PromptRemote
  try { `$env:REMOTE_HOST='43.160.239.168'; `$env:REMOTE_PASSWORD='<ssh-password>'; .\deploy\$ScriptName deploy } finally { Remove-Item Env:REMOTE_HOST, Env:REMOTE_PASSWORD -ErrorAction SilentlyContinue }

SSH proxy examples:
  `$env:SSH_PROXY_URL='socks5://127.0.0.1:7890'; .\deploy\$ScriptName up -RemotePassword '<ssh-password>'
  `$env:SSH_PROXY_HOST='127.0.0.1'; `$env:SSH_PROXY_PORT='7890'; `$env:SSH_PROXY_TYPE='socks5'
  `$env:SSH_OPTS='-o StrictHostKeyChecking=accept-new -o ExitOnForwardFailure=yes -o "ProxyCommand=C:\Program Files\Git\mingw64\bin\connect.exe -S 127.0.0.1:7890 %h %p"'

Default services:
  frontend  http://$BindHost`:$ServerPort
  backend   $BackendImage
  redis     $RedisImage
  database  host container -> $AppDatabaseHost`:$AppDatabasePort -> ssh tunnel -> $RemoteHost`:$RemoteDatabasePort
  postgres  not started locally by this script

Common environment overrides:
  TAG=$Tag
  PLATFORM=$Platform
  ENV_FILE=$EnvFile
  LOCAL_DATABASE_PORT=$LocalDatabasePort
  REMOTE_USER=$RemoteUser
  REMOTE_HOST=$RemoteHost
  REMOTE_PORT=$RemotePort
  REMOTE_DATABASE_HOST=$RemoteDatabaseHost
  REMOTE_DATABASE_PORT=$RemoteDatabasePort
  REMOTE_DATABASE_CONTAINER=$RemoteDatabaseContainer
  REMOTE_DATABASE_DISCOVERY=$RemoteDatabaseDiscovery
  SSH_OPTS=$($SshOptions -join ' ')
  SSH_PROXY_URL=socks5://127.0.0.1:7890
  START_TUNNEL=1|0
  SKIP_DOCKERFILE_SYNTAX=1|0
  DOCKERHUB_MIRROR=$DockerHubMirror
  APK_MIRROR=$ApkMirror
  NPM_REGISTRY=$NpmRegistry
"@
}

function Open-UrlHint {
    Log "local URL: http://$BindHost`:$ServerPort"
}

$LocalOs = "win"
$Platform = Get-EnvValue "PLATFORM" "linux/amd64"
$ProjectName = Get-EnvValue "PROJECT_NAME" "my-sub2api"
$Tag = Get-EnvValue "TAG" "local"

$DockerHubMirror = Get-EnvValue "DOCKERHUB_MIRROR" "docker.1ms.run"
$ApkMirror = Get-EnvValue "APK_MIRROR" "https://mirrors.aliyun.com/alpine"
$NpmRegistry = Get-EnvValue "NPM_REGISTRY" "https://registry.npmmirror.com"

$GolangImage = Get-EnvValue "GOLANG_IMAGE" (Use-DockerHubMirror "golang:1.26.2-alpine" $DockerHubMirror)
$AlpineImage = Get-EnvValue "ALPINE_IMAGE" (Use-DockerHubMirror "alpine:3.21" $DockerHubMirror)
$PostgresImage = Get-EnvValue "POSTGRES_IMAGE" (Use-DockerHubMirror "postgres:18-alpine" $DockerHubMirror)
$NodeImage = Get-EnvValue "NODE_IMAGE" (Use-DockerHubMirror "node:24-alpine" $DockerHubMirror)
$NginxImage = Get-EnvValue "NGINX_IMAGE" (Use-DockerHubMirror "nginx:1.27-alpine" $DockerHubMirror)
$RedisSourceImage = Get-EnvValue "REDIS_SOURCE_IMAGE" (Use-DockerHubMirror "redis:8-alpine" $DockerHubMirror)
$RedisImage = Get-EnvValue "REDIS_IMAGE" "$ProjectName-redis:8-alpine"
$BackendImage = Get-EnvValue "BACKEND_IMAGE" "$ProjectName-backend:$Tag"
$FrontendImage = Get-EnvValue "FRONTEND_IMAGE" "$ProjectName-frontend:$Tag"

$Version = Get-EnvValue "VERSION" ""
$Commit = First-Value (Get-EnvValue "COMMIT") (Get-GitCommit)
$Date = First-Value (Get-EnvValue "DATE") ((Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ"))
$GoProxy = Get-EnvValue "GOPROXY" "https://goproxy.cn,direct"
$GoSumDB = Get-EnvValue "GOSUMDB" "sum.golang.google.cn"

$EnvFile = Get-EnvValue "ENV_FILE" (Join-Path $RootDir "deploy\.env")
$RuntimeDir = Get-EnvValue "RUNTIME_DIR" (Join-Path $RootDir "dist\local-docker\$LocalOs")
$RuntimeEnvFile = Join-Path $RuntimeDir "local.env"
$RuntimeComposeFile = Join-Path $RuntimeDir "docker-compose.yml"

$BuildBackend = Get-EnvValue "BUILD_BACKEND" "1"
$BuildFrontend = Get-EnvValue "BUILD_FRONTEND" "1"
$StartTunnel = Get-EnvValue "START_TUNNEL" "1"

$RemoteUser = Get-EnvValue "REMOTE_USER" "ubuntu"
$RemoteHost = First-Value $RemoteHost (Get-EnvValue "REMOTE_HOST")
$RemotePort = Get-EnvValue "REMOTE_PORT" "22"
$RemoteDatabaseHost = Get-EnvValue "REMOTE_DATABASE_HOST" "127.0.0.1"
$RemoteDatabasePort = Get-EnvValue "REMOTE_DATABASE_PORT" "5432"
$RemoteDatabaseContainer = Get-EnvValue "REMOTE_DATABASE_CONTAINER" "$ProjectName-postgres"
$RemoteDatabaseDiscovery = Get-EnvValue "REMOTE_DATABASE_DISCOVERY" "auto"
$LocalDatabaseBindHost = Get-EnvValue "LOCAL_DATABASE_BIND_HOST" "127.0.0.1"
$LocalDatabasePort = Get-EnvValue "LOCAL_DATABASE_PORT" "15432"
$AppDatabaseHost = Get-EnvValue "APP_DATABASE_HOST" "host.docker.internal"
$AppDatabasePort = Get-EnvValue "APP_DATABASE_PORT" $LocalDatabasePort
$SshOptions = Add-SshProxyOptions (Split-CommandLine (Get-EnvValue "SSH_OPTS" "-o StrictHostKeyChecking=accept-new -o ExitOnForwardFailure=yes"))

$ComposeProjectName = Get-EnvValue "COMPOSE_PROJECT_NAME" "$ProjectName-$LocalOs-local"
$BindHost = Get-EnvValue "BIND_HOST" "127.0.0.1"
$ServerPort = Get-EnvValue "SERVER_PORT" "8080"
$ServerMode = Get-EnvValue "SERVER_MODE" "debug"
$RunMode = Get-EnvValue "RUN_MODE" "standard"
$TimeZone = Get-EnvValue "TZ" "Asia/Shanghai"

switch ($Action.ToLowerInvariant()) {
    "up" {
        Prompt-RemoteConnectionIfNeeded
        Start-Tunnel
        Build-Images
        Write-RuntimeFiles
        Invoke-Compose @("up", "-d", "--remove-orphans")
        Invoke-Compose @("ps")
        Open-UrlHint
    }
    "deploy" {
        Prompt-RemoteConnectionIfNeeded
        Start-Tunnel
        Build-Images
        Write-RuntimeFiles
        Invoke-Compose @("up", "-d", "--remove-orphans")
        Invoke-Compose @("ps")
        Open-UrlHint
    }
    "build" {
        Build-Images
    }
    "tunnel" {
        Prompt-RemoteConnectionIfNeeded
        Start-Tunnel
    }
    "restart" {
        Prompt-RemoteConnectionIfNeeded
        Start-Tunnel
        Build-Images
        Write-RuntimeFiles
        Invoke-Compose @("up", "-d", "--force-recreate", "--remove-orphans")
        Invoke-Compose @("ps")
        Open-UrlHint
    }
    "down" {
        Write-RuntimeFiles
        Invoke-Compose @("down")
    }
    "ps" {
        Write-RuntimeFiles
        Invoke-Compose @("ps")
    }
    "logs" {
        Write-RuntimeFiles
        Invoke-Compose (@("logs", "-f") + $ExtraArgs)
    }
    "config" {
        Write-RuntimeFiles
        Invoke-Compose @("config")
    }
    "help" {
        Show-Usage
    }
    "-h" {
        Show-Usage
    }
    "--help" {
        Show-Usage
    }
    default {
        Show-Usage
        Die "unknown action: $Action"
    }
}
