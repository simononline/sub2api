param(
    [Parameter(Position = 0)]
    [string]$Action = "package",

    [string]$RemoteHost = "",

    [string]$RemotePassword = "",

    [switch]$PromptRemote
)

$ErrorActionPreference = "Stop"

$ScriptName = "release-images.ps1"
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

function Require-Command {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        Die "missing command: $Name"
    }
}

function Invoke-Checked {
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$File,

        [Parameter(ValueFromRemainingArguments = $true)]
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
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$File,

        [Parameter(ValueFromRemainingArguments = $true)]
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
        Output = @($output)
    }
}

function Require-DockerDaemon {
    Require-Command docker

    $result = Invoke-NativeProbe docker "version" "--format" "{{.Server.Version}}"
    $serverVersion = (($result.Output | Select-Object -First 1) -as [string]).Trim()
    if ($result.ExitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace($serverVersion)) {
        return
    }

    $details = (($result.Output | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 3) -join " ")
    if ([string]::IsNullOrWhiteSpace($details)) {
        $details = "docker daemon did not respond"
    }

    Die "Docker is installed but the daemon is not reachable. Start Docker Desktop and wait for the Linux engine, then retry. Details: $details"
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
        Die "SSH proxy requested, but no proxy helper was found. Install Git for Windows, install ncat, or set SSH_PROXY_COMMAND."
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
    [System.IO.File]::WriteAllText($Path, (($Lines -join "`n") + "`n"), $encoding)
}

function Remove-DirectorySafe {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    $resolved = (Resolve-Path -LiteralPath $Path).Path
    if ([string]::IsNullOrWhiteSpace($resolved) -or $resolved.Length -lt 8) {
        Die "refusing to remove suspicious directory: $Path"
    }

    Remove-Item -LiteralPath $resolved -Recurse -Force
}

function Get-GitCommit {
    $gitResult = Invoke-NativeProbe git "-C" $RootDir "rev-parse" "--short" "HEAD"
    if ($gitResult.ExitCode -eq 0) {
        $commit = (($gitResult.Output | Select-Object -First 1) -as [string]).Trim()
        if (-not [string]::IsNullOrWhiteSpace($commit)) {
            return $commit
        }
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

    $result = Invoke-NativeProbe docker "image" "inspect" $Image
    return ($result.ExitCode -eq 0)
}

function Get-ImagePlatform {
    param([string]$Image)

    $result = Invoke-NativeProbe docker "image" "inspect" "--format" "{{.Os}}/{{.Architecture}}{{if .Variant}}/{{.Variant}}{{end}}" $Image
    if ($result.ExitCode -ne 0) {
        return ""
    }
    return (($result.Output | Select-Object -First 1) -as [string]).Trim()
}

function Test-ImageMatchesPlatform {
    param([string]$Image)

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

    $buildDir = Join-Path $DistDir ".dockerfile-build"
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
        if (Test-ImageMatchesPlatform $TargetImage) {
            Log "$Label image already exists and matches $Platform; skipping"
            return
        }

        $actual = Get-ImagePlatform $TargetImage
        Log "$Label image platform mismatch, recreating: $TargetImage ($actual)"
        Invoke-Checked docker "rmi" "-f" $TargetImage
    }

    Log "pulling $SourceImage ($Platform) and tagging $TargetImage"
    Invoke-Checked docker "pull" "--platform" $Platform $SourceImage
    Invoke-Checked docker "tag" $SourceImage $TargetImage
}

function Rebuild-Image {
    param(
        [string]$Image,
        [string]$Dockerfile,
        [string]$Label,
        [string[]]$ExtraBuildArgs = @()
    )

    Log "checking $Label image: $Image"
    if (Test-ImageExists $Image) {
        Log "$Label image already exists; Docker build cache will be reused and tag will be overwritten"
    }

    Log "building $Label image: $Image"
    $oldBuildKit = [Environment]::GetEnvironmentVariable("DOCKER_BUILDKIT", "Process")
    $env:DOCKER_BUILDKIT = First-Value (Get-EnvValue "DOCKER_BUILDKIT") "1"
    try {
        $buildDockerfile = Get-BuildDockerfile $Dockerfile $Label
        $dockerArgs = @("build", "--platform", $Platform, "-f", $buildDockerfile, "-t", $Image) + $ExtraBuildArgs + @($RootDir)
        Invoke-Checked docker @dockerArgs
    } finally {
        if ($null -eq $oldBuildKit) {
            [Environment]::SetEnvironmentVariable("DOCKER_BUILDKIT", $null, "Process")
        } else {
            $env:DOCKER_BUILDKIT = $oldBuildKit
        }
    }
}

function Build-Images {
    Require-DockerDaemon

    Log "project root: $RootDir"
    Log "image prefix: $ProjectName"
    Log "business image tag: $Tag"
    Log "target image platform: $Platform"

    Ensure-BaseImageOnce $SqlImage $PostgresSourceImage "PostgreSQL"
    Ensure-BaseImageOnce $RedisImage $RedisSourceImage "Redis"

    if (Test-Enabled $BuildBackend "BUILD_BACKEND") {
        Rebuild-Image $BackendImage (Join-Path $RootDir "deploy\Dockerfile.backend") "backend" @(
            "--build-arg", "VERSION=$Version",
            "--build-arg", "COMMIT=$Commit",
            "--build-arg", "DATE=$Date",
            "--build-arg", "GOPROXY=$GoProxy",
            "--build-arg", "GOSUMDB=$GoSumDB"
        )
    } else {
        if (-not (Test-ImageExists $BackendImage)) {
            Die "BUILD_BACKEND=0, but local backend image does not exist: $BackendImage"
        }
        Log "skipping backend build, reusing local image: $BackendImage"
    }

    if (Test-Enabled $BuildFrontend "BUILD_FRONTEND") {
        Rebuild-Image $FrontendImage (Join-Path $RootDir "deploy\Dockerfile.frontend") "frontend"
    } else {
        if (-not (Test-ImageExists $FrontendImage)) {
            Die "BUILD_FRONTEND=0, but local frontend image does not exist: $FrontendImage"
        }
        Log "skipping frontend build, reusing local image: $FrontendImage"
    }

    Log "images are ready:"
    Log "  SQL      $SqlImage"
    Log "  Redis    $RedisImage"
    Log "  Backend  $BackendImage"
    Log "  Frontend $FrontendImage"
}

function Copy-EnvIfNeeded {
    switch ($IncludeEnv.ToLowerInvariant()) {
        "auto" {
            if (Test-Path -LiteralPath $EnvFile) {
                Copy-Item -LiteralPath $EnvFile -Destination (Join-Path $PackageWorkDir "deploy.env") -Force
                Log "included deploy/.env as deploy.env; remote default policy only uses it when .env is missing"
            }
        }
        { $_ -in @("1", "true", "yes") } {
            if (-not (Test-Path -LiteralPath $EnvFile)) {
                Die "INCLUDE_ENV=$IncludeEnv, but env file was not found: $EnvFile"
            }
            Copy-Item -LiteralPath $EnvFile -Destination (Join-Path $PackageWorkDir "deploy.env") -Force
            Log "included deploy/.env as deploy.env; remote default policy only uses it when .env is missing"
        }
        { $_ -in @("0", "false", "no") } {
            Log "skipping deploy/.env package step"
        }
        default {
            Die "INCLUDE_ENV must be auto|1|0"
        }
    }
}

function Write-Manifest {
    Write-LinesUtf8NoBom (Join-Path $PackageWorkDir "manifest.env") @(
        "PROJECT_NAME=$ProjectName",
        "TAG=$Tag",
        "SQL_IMAGE=$SqlImage",
        "REDIS_IMAGE=$RedisImage",
        "BACKEND_IMAGE=$BackendImage",
        "FRONTEND_IMAGE=$FrontendImage",
        "PLATFORM=$Platform",
        "COMMIT=$Commit",
        "BUILD_DATE=$Date"
    )
}

function Package-Release {
    Require-DockerDaemon
    Require-Command tar

    if (-not (Test-Path -LiteralPath $ComposeFile)) {
        Die "compose file was not found: $ComposeFile"
    }

    Build-Images

    Remove-DirectorySafe $PackageWorkDir
    New-Item -ItemType Directory -Force -Path $DistDir | Out-Null
    New-Item -ItemType Directory -Force -Path $PackageWorkDir | Out-Null

    $imagesTar = Join-Path $PackageWorkDir "images.tar"
    Log "exporting Docker images to tar: $imagesTar"
    Invoke-Checked docker "save" "-o" $imagesTar $SqlImage $RedisImage $BackendImage $FrontendImage

    Copy-Item -LiteralPath $ComposeFile -Destination (Join-Path $PackageWorkDir "docker-compose.yml") -Force
    Write-Manifest
    Copy-EnvIfNeeded

    Log "creating release package: $PackagePath"
    if (Test-Path -LiteralPath $PackagePath) {
        Remove-Item -LiteralPath $PackagePath -Force
    }

    $oldCopyFileDisable = [Environment]::GetEnvironmentVariable("COPYFILE_DISABLE", "Process")
    $env:COPYFILE_DISABLE = "1"
    Push-Location $PackageWorkDir
    try {
        Invoke-Checked tar "-czf" $PackagePath "."
    } finally {
        Pop-Location
        if ($null -eq $oldCopyFileDisable) {
            [Environment]::SetEnvironmentVariable("COPYFILE_DISABLE", $null, "Process")
        } else {
            $env:COPYFILE_DISABLE = $oldCopyFileDisable
        }
    }

    Log "release package created: $PackagePath"
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
    if ($PromptRemote) {
        $hostPrompt = "Remote SSH host/IP"
        if (-not [string]::IsNullOrWhiteSpace($RemoteHost)) {
            $hostPrompt += " [$RemoteHost]"
        }

        $inputHost = Read-Host $hostPrompt
        if (-not [string]::IsNullOrWhiteSpace($inputHost)) {
            $script:RemoteHost = $inputHost.Trim()
        }

        $securePassword = Read-Host "Remote SSH password (leave empty to use SSH key or interactive prompt)" -AsSecureString
        $plainPassword = ConvertFrom-SecureStringToPlainText $securePassword
        if (-not [string]::IsNullOrEmpty($plainPassword)) {
            $script:RemotePassword = $plainPassword
        }
    }

    if ([string]::IsNullOrWhiteSpace($RemoteHost)) {
        Die "remote host is empty. Set -RemoteHost or REMOTE_HOST"
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

    foreach ($line in $output) {
        if (-not [string]::IsNullOrWhiteSpace($line)) {
            Write-Host $line
        }
    }

    return [pscustomobject]@{
        ExitCode = $exitCode
        Output = @($output)
    }
}

function Invoke-ScpUpload {
    param(
        [string]$Source,
        [string]$Destination
    )

    Require-Command scp

    $remote = "$RemoteUser@$RemoteHost"
    $target = "${remote}:$Destination"
    $scpArgs = @("-P", $RemotePort) + $SshOptions + @($Source, $target)
    $askPassState = Enable-AskPass

    try {
        $oldErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        try {
            & scp @scpArgs
            $exitCode = $LASTEXITCODE
        } finally {
            $ErrorActionPreference = $oldErrorActionPreference
        }
    } finally {
        Disable-AskPass $askPassState
    }

    if ($exitCode -ne 0) {
        Die "scp upload failed: $Source -> $target"
    }
}

function Quote-Sh {
    param([string]$Value)
    return "'" + $Value.Replace("'", "'\''") + "'"
}

function Join-RemotePath {
    param(
        [string]$Directory,
        [string]$Name
    )

    if ($Directory -eq "/") {
        return "/$Name"
    }

    return $Directory.TrimEnd("/") + "/" + $Name
}

function Get-RootRemoteDir {
    switch -Wildcard ($RemoteDir) {
        "~" { return "/root" }
        "~/*" { return "/root/" + $RemoteDir.Substring(2) }
        default { return $RemoteDir }
    }
}

function Get-RemoteInstallScript {
    return @'
set -eu

REMOTE_DIR="$1"
REMOTE_PACKAGE_PATH="$2"
PACKAGE_NAME="$3"
ENV_POLICY="$4"

log() {
    printf '[remote-install] %s\n' "$*"
}

die() {
    printf '[remote-install] ERROR: %s\n' "$*" >&2
    exit 1
}

find_docker() {
    if docker info >/dev/null 2>&1; then
        printf 'docker\n'
        return
    fi

    if command -v sudo >/dev/null 2>&1 && sudo -n docker info >/dev/null 2>&1; then
        printf 'sudo docker\n'
        return
    fi

    die "current remote user cannot run docker. Add the user to the docker group or configure passwordless sudo."
}

find_compose() {
    docker_cmd="$1"

    if $docker_cmd compose version >/dev/null 2>&1; then
        printf '%s compose\n' "$docker_cmd"
        return
    fi

    if command -v docker-compose >/dev/null 2>&1 && docker-compose version >/dev/null 2>&1; then
        printf 'docker-compose\n'
        return
    fi

    if command -v sudo >/dev/null 2>&1 && sudo -n docker-compose version >/dev/null 2>&1; then
        printf 'sudo docker-compose\n'
        return
    fi

    die "missing docker compose or docker-compose on remote host."
}

wait_service_healthy() {
    service="$1"
    timeout="$2"
    start_ts="$(date +%s)"

    while :; do
        cid="$($COMPOSE -f docker-compose.yml ps -q "$service" 2>/dev/null || true)"
        if [ -n "$cid" ]; then
            status="$($DOCKER inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$cid" 2>/dev/null || printf unknown)"
            case "$status" in
                healthy|running)
                    log "$service status: $status"
                    return 0
                    ;;
            esac
        fi

        now_ts="$(date +%s)"
        if [ $((now_ts - start_ts)) -ge "$timeout" ]; then
            log "$service wait timed out. Recent logs:"
            if [ -n "${cid:-}" ]; then
                $DOCKER logs --tail 80 "$cid" || true
            fi
            return 1
        fi

        sleep 3
    done
}

remove_application_containers() {
    $COMPOSE -f docker-compose.yml stop frontend backend >/dev/null 2>&1 || true
    $COMPOSE -f docker-compose.yml rm -f frontend backend >/dev/null 2>&1 || true
    $DOCKER rm -f "${PROJECT_NAME}-frontend" "${PROJECT_NAME}-backend" >/dev/null 2>&1 || true
}

DOCKER="$(find_docker)"
COMPOSE="$(find_compose "$DOCKER")"

mkdir -p "$REMOTE_DIR"

if [ -f "$REMOTE_PACKAGE_PATH" ]; then
    mv "$REMOTE_PACKAGE_PATH" "$REMOTE_DIR/$PACKAGE_NAME"
fi

cd "$REMOTE_DIR"

[ -f "$PACKAGE_NAME" ] || die "remote release package not found: $REMOTE_DIR/$PACKAGE_NAME"

log "extracting release package to $REMOTE_DIR"
tar -xzf "$PACKAGE_NAME" -C "$REMOTE_DIR"

if [ -f manifest.env ]; then
    sed -i 's/\r$//' manifest.env
fi

case "$ENV_POLICY" in
    keep)
        if [ ! -f .env ] && [ -f deploy.env ]; then
            cp deploy.env .env
            log "remote .env was missing; initialized it from deploy.env"
        elif [ -f .env ]; then
            log "keeping existing remote .env"
        fi
        ;;
    replace)
        [ -f deploy.env ] || die "REMOTE_ENV_POLICY=replace, but deploy.env is missing from the package"
        cp deploy.env .env
        log "replaced remote .env with deploy.env"
        ;;
    skip)
        log "skipping remote .env handling"
        ;;
    *)
        die "REMOTE_ENV_POLICY must be keep|replace|skip"
        ;;
esac

[ -f .env ] || die "remote .env is missing. Provide deploy/.env locally with INCLUDE_ENV=1, or create .env on the server."
[ -f docker-compose.yml ] || die "release package is missing docker-compose.yml"
[ -f images.tar ] || die "release package is missing images.tar"
[ -f manifest.env ] || die "release package is missing manifest.env"

mkdir -p data postgres_data redis_data

log "loading Docker images"
$DOCKER load -i images.tar

. ./manifest.env
export PROJECT_NAME TAG SQL_IMAGE REDIS_IMAGE BACKEND_IMAGE FRONTEND_IMAGE PLATFORM

postgres_id="$($COMPOSE -f docker-compose.yml ps -q postgres 2>/dev/null || true)"
redis_id="$($COMPOSE -f docker-compose.yml ps -q redis 2>/dev/null || true)"

if [ -n "$postgres_id" ] && [ -n "$redis_id" ]; then
    log "existing PostgreSQL/Redis containers detected; recreating only backend/frontend"
    $DOCKER start "$postgres_id" "$redis_id" >/dev/null 2>&1 || true
    remove_application_containers
    $COMPOSE -f docker-compose.yml up -d --no-deps --force-recreate backend
    wait_service_healthy backend 180
    $COMPOSE -f docker-compose.yml up -d --no-deps --force-recreate frontend
else
    log "PostgreSQL/Redis containers not fully present; starting full stack"
    remove_application_containers
    $COMPOSE -f docker-compose.yml up -d
fi

log "remote service status:"
$COMPOSE -f docker-compose.yml ps
'@
}

function Run-RemoteInstall {
    param(
        [string]$RemoteDirAbs,
        [string]$RemotePackagePath,
        [string]$PackageFileName,
        [string]$EnvPolicy
    )

    $localInstaller = Join-Path ([System.IO.Path]::GetTempPath()) ("sub2api-remote-install-" + [guid]::NewGuid().ToString("N") + ".sh")
    $remoteInstallerPath = Join-RemotePath $RemoteUploadDir ([System.IO.Path]::GetFileName($localInstaller))
    Write-Utf8NoBom $localInstaller (Get-RemoteInstallScript)

    try {
        Log "uploading remote installer script"
        Invoke-ScpUpload $localInstaller $remoteInstallerPath

        $scriptQ = Quote-Sh $remoteInstallerPath
        $remoteDirQ = Quote-Sh $RemoteDirAbs
        $remotePackageQ = Quote-Sh $RemotePackagePath
        $packageQ = Quote-Sh $PackageFileName
        $envPolicyQ = Quote-Sh $EnvPolicy

        Log "running remote installer"
        Invoke-SshRemote "sudo -n -i sh $scriptQ $remoteDirQ $remotePackageQ $packageQ $envPolicyQ" | Out-Null
    } finally {
        if (Test-Path -LiteralPath $localInstaller) {
            Remove-Item -LiteralPath $localInstaller -Force -ErrorAction SilentlyContinue
        }

        if (-not [string]::IsNullOrWhiteSpace($remoteInstallerPath)) {
            $scriptQ = Quote-Sh $remoteInstallerPath
            Invoke-SshRemote "rm -f $scriptQ" -AllowFailure | Out-Null
        }
    }
}

function Deploy-Release {
    Require-Command ssh
    Require-Command scp

    Prompt-RemoteConnectionIfNeeded
    Package-Release

    $remoteDirAbs = Get-RootRemoteDir
    $packageFileName = [System.IO.Path]::GetFileName($PackagePath)
    $remotePackagePath = Join-RemotePath $RemoteUploadDir $packageFileName
    $remoteUploadDirQ = Quote-Sh $RemoteUploadDir

    Log "remote directory: $RemoteUser@$RemoteHost`:$remoteDirAbs"
    Log "remote temporary upload path: $RemoteUser@$RemoteHost`:$remotePackagePath"

    Invoke-SshRemote "mkdir -p $remoteUploadDirQ" | Out-Null

    Log "uploading release package"
    Invoke-ScpUpload $PackagePath $remotePackagePath

    Run-RemoteInstall $remoteDirAbs $remotePackagePath $packageFileName $RemoteEnvPolicy
}

function Show-Usage {
    @"
Usage:
  powershell -ExecutionPolicy Bypass -File .\deploy\$ScriptName build
  powershell -ExecutionPolicy Bypass -File .\deploy\$ScriptName package
  powershell -ExecutionPolicy Bypass -File .\deploy\$ScriptName deploy

Actions:
  build     Build Docker images locally.
  package   Build images and create an uploadable tar.gz package. This is the default action.
  deploy    Package locally, upload to the server, docker load, then recreate backend/frontend.

Common environment overrides:
  TAG=$Tag
  PLATFORM=$Platform
  DIST_DIR=$DistDir
  PACKAGE_PATH=$PackagePath
  INCLUDE_ENV=auto|1|0
  BUILD_BACKEND=1|0
  BUILD_FRONTEND=1|0

Remote environment overrides:
  REMOTE_USER=$RemoteUser
  REMOTE_HOST=$RemoteHost
  REMOTE_PORT=$RemotePort
  REMOTE_DIR=$RemoteDir
  REMOTE_UPLOAD_DIR=$RemoteUploadDir
  REMOTE_ENV_POLICY=keep|replace|skip
  REMOTE_PASSWORD=...     Optional; SSH key auth is preferred.
  SSH_PROXY_URL=socks5://127.0.0.1:7890
  SSH_PROXY_HOST=127.0.0.1
  SSH_PROXY_PORT=7890
  SSH_PROXY_TYPE=socks5|http

Examples:
  powershell -ExecutionPolicy Bypass -File .\deploy\$ScriptName package
  powershell -ExecutionPolicy Bypass -File .\deploy\$ScriptName deploy -RemoteHost '100.97.252.20' -RemotePassword '<ssh-password>'
  powershell -ExecutionPolicy Bypass -File .\deploy\$ScriptName deploy -RemotePassword '<ssh-password>'
  `$env:SSH_PROXY_URL='socks5://127.0.0.1:7890'; powershell -ExecutionPolicy Bypass -File .\deploy\$ScriptName deploy -RemotePassword '<ssh-password>'
  `$env:TAG='0.1.119-local'; `$env:REMOTE_PASSWORD='<ssh-password>'; powershell -ExecutionPolicy Bypass -File .\deploy\$ScriptName deploy
"@
}

$ProjectName = Get-EnvValue "PROJECT_NAME" "my-sub2api"
$Tag = Get-EnvValue "TAG" "local"

$PostgresSourceImage = Get-EnvValue "POSTGRES_SOURCE_IMAGE" "postgres:18-alpine"
$RedisSourceImage = Get-EnvValue "REDIS_SOURCE_IMAGE" "redis:8-alpine"

$SqlImage = Get-EnvValue "SQL_IMAGE" "$ProjectName-postgres:18-alpine"
$RedisImage = Get-EnvValue "REDIS_IMAGE" "$ProjectName-redis:8-alpine"
$BackendImage = Get-EnvValue "BACKEND_IMAGE" "$ProjectName-backend:$Tag"
$FrontendImage = Get-EnvValue "FRONTEND_IMAGE" "$ProjectName-frontend:$Tag"

$Version = Get-EnvValue "VERSION" ""
$Commit = First-Value (Get-EnvValue "COMMIT") (Get-GitCommit)
$Date = First-Value (Get-EnvValue "DATE") ((Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ"))
$GoProxy = Get-EnvValue "GOPROXY" "https://goproxy.cn,direct"
$GoSumDB = Get-EnvValue "GOSUMDB" "sum.golang.google.cn"
$Platform = Get-EnvValue "PLATFORM" "linux/amd64"

$ComposeFile = Get-EnvValue "COMPOSE_FILE" (Join-Path $RootDir "deploy\docker-compose.my-sub2api.yml")
$EnvFile = Get-EnvValue "ENV_FILE" (Join-Path $RootDir "deploy\.env")
$DistDir = Get-EnvValue "DIST_DIR" (Join-Path $RootDir "dist")
$IncludeEnv = Get-EnvValue "INCLUDE_ENV" "auto"
$BuildBackend = Get-EnvValue "BUILD_BACKEND" "1"
$BuildFrontend = Get-EnvValue "BUILD_FRONTEND" "1"

$RemoteUser = Get-EnvValue "REMOTE_USER" "ubuntu"
$RemoteHost = First-Value $RemoteHost (Get-EnvValue "REMOTE_HOST" "43.160.239.168")
$RemotePort = Get-EnvValue "REMOTE_PORT" "22"
$RemoteDir = Get-EnvValue "REMOTE_DIR" "/root/my-sub2api"
$RemoteUploadDir = Get-EnvValue "REMOTE_UPLOAD_DIR" "/tmp"
$RemoteEnvPolicy = Get-EnvValue "REMOTE_ENV_POLICY" "keep"
$SshOptions = Add-SshProxyOptions (Split-CommandLine (Get-EnvValue "SSH_OPTS" "-o StrictHostKeyChecking=accept-new"))

$SafeTag = ($Tag -replace '[/:\\]', '_')
$PackageName = Get-EnvValue "PACKAGE_NAME" "$ProjectName-$SafeTag-$Commit.tar.gz"
$PackagePath = Get-EnvValue "PACKAGE_PATH" (Join-Path $DistDir $PackageName)
$PackageWorkDir = Get-EnvValue "PACKAGE_WORK_DIR" (Join-Path $DistDir ".release-$ProjectName-$SafeTag-$Commit")

switch ($Action.ToLowerInvariant()) {
    "build" {
        Build-Images
    }
    "package" {
        Package-Release
    }
    "deploy" {
        Deploy-Release
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
