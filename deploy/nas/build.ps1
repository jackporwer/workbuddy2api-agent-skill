[CmdletBinding()]
param(
    [string]$Version = 'latest',
    [ValidateSet('amd64', 'arm64')]
    [string]$Architecture = 'amd64',
    [switch]$PrepareOnly,
    [string]$ArchivePath,
    [string]$ChecksumsPath
)

$ErrorActionPreference = 'Stop'
Write-Host "PowerShell $($PSVersionTable.PSVersion) — $((Get-Process -Id $PID).Path)"
if ($PSVersionTable.PSVersion.Major -lt 7) {
    throw '请使用已有的 PowerShell 7；本脚本不会自动安装或切换 PowerShell。'
}

$upstreamRepository = 'linguo2625469/workbuddy2api-panel'
$requestHeaders = @{ 'User-Agent' = 'workbuddy2api-agent-skill'; 'Accept' = 'application/vnd.github+json' }
$useLocalArchive = -not [string]::IsNullOrEmpty($ArchivePath)
if ($useLocalArchive -ne (-not [string]::IsNullOrEmpty($ChecksumsPath))) {
    throw '离线准备必须同时指定 -ArchivePath 与 -ChecksumsPath。'
}
if ($useLocalArchive -and $Version -eq 'latest') {
    throw '使用本地文件时必须指定其实际 -Version；不能把未查询的本地版本称为 latest。'
}

if (-not $useLocalArchive) {
    $releaseApi = "https://api.github.com/repos/$upstreamRepository/releases/latest"
    if ($Version -ne 'latest') {
        $releaseApi = "https://api.github.com/repos/$upstreamRepository/releases/tags/$([uri]::EscapeDataString($Version))"
    }
    $releaseInfo = Invoke-RestMethod -Uri $releaseApi -Headers $requestHeaders -TimeoutSec 30
    if ($releaseInfo.draft -or $releaseInfo.prerelease) {
        throw '此脚本只准备正式 Release，不使用 draft 或 prerelease。'
    }
    $Version = [string]$releaseInfo.tag_name
}
if ($Version -notmatch '^v[0-9]+\.[0-9]+\.[0-9]+(?:[-.][A-Za-z0-9.-]+)?$') {
    throw "无法安全处理版本标签：$Version"
}
$versionNumber = $Version.Substring(1)
$archiveName = "wb2api-panel-$Version-linux-$Architecture.tar.gz"
$buildDirectory = Join-Path $PSScriptRoot "build/$Version-linux-$Architecture"
New-Item -ItemType Directory -Path $buildDirectory -Force | Out-Null
$targetArchive = Join-Path $buildDirectory $archiveName
$targetChecksums = Join-Path $buildDirectory 'checksums.txt'

if ($useLocalArchive) {
    # Require the upstream naming so a differently targeted archive is not relabeled.
    if ((Split-Path -Leaf $ArchivePath) -ne $archiveName) {
        throw "本地安装包名称应为 $archiveName；请核对版本与架构。"
    }
    Copy-Item -LiteralPath $ArchivePath -Destination $targetArchive -Force
    Copy-Item -LiteralPath $ChecksumsPath -Destination $targetChecksums -Force
} else {
    $archiveAsset = @($releaseInfo.assets | Where-Object name -eq $archiveName)
    $checksumAsset = @($releaseInfo.assets | Where-Object name -eq 'checksums.txt')
    if ($archiveAsset.Count -ne 1 -or $checksumAsset.Count -ne 1) {
        throw "原项目 $Version 缺少 $archiveName 或 checksums.txt；不能跳过校验。"
    }
    Invoke-WebRequest -Uri $archiveAsset[0].browser_download_url -Headers $requestHeaders -OutFile $targetArchive -TimeoutSec 120
    Invoke-WebRequest -Uri $checksumAsset[0].browser_download_url -Headers $requestHeaders -OutFile $targetChecksums -TimeoutSec 30
    if ((Get-Item -LiteralPath $targetArchive).Length -ne $archiveAsset[0].size) {
        throw '下载大小与 Release asset 元数据不符。'
    }
}

$expectedHash = $null
foreach ($checksumLine in Get-Content -LiteralPath $targetChecksums) {
    if ($checksumLine -match '^([0-9a-fA-F]{64})\s+\*?(.+)$' -and $Matches[2] -eq $archiveName) {
        if ($null -ne $expectedHash) { throw '校验清单中出现重复安装包条目。' }
        $expectedHash = $Matches[1]
    }
}
if ($null -eq $expectedHash) { throw '同版本校验清单中没有所选安装包。' }
$actualHash = (Get-FileHash -LiteralPath $targetArchive -Algorithm SHA256).Hash
if ($actualHash -ne $expectedHash) { throw '安装包 SHA256 不符，已中止；不会解压或执行。' }
Write-Host "Verified: $archiveName (SHA256 $actualHash)"

& tar -xzf $targetArchive -C $buildDirectory wb2api config.example.json
if ($LASTEXITCODE -ne 0) { throw '解压所选 Release 包失败。' }
if (-not (Test-Path -LiteralPath (Join-Path $buildDirectory 'wb2api'))) { throw '解压后缺少 wb2api。' }
$samplePath = Join-Path $buildDirectory 'config.example.json'
$sampleConfig = Get-Content -Raw -LiteralPath $samplePath | ConvertFrom-Json
$sampleConfig.api_key = ''
$sampleConfig | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $samplePath -Encoding utf8
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Dockerfile') -Destination (Join-Path $buildDirectory 'Dockerfile') -Force
$imageTag = "wb2api-panel:$versionNumber-linux-$Architecture"
@{ upstream = $upstreamRepository; version = $Version; architecture = $Architecture; archive_sha256 = $actualHash; image = $imageTag } |
    ConvertTo-Json | Set-Content -LiteralPath (Join-Path $buildDirectory 'build-info.json') -Encoding utf8
Write-Host "Prepared: $buildDirectory"
Write-Host "Image: $imageTag"
if ($PrepareOnly) { return }

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { throw '未找到 Docker；文件已准备，可以安装 / 启动 Docker 后重试，或使用 -PrepareOnly。' }
& docker version --format '{{.Server.Version}}'
if ($LASTEXITCODE -ne 0) { throw 'Docker 服务不可用；已保留准备好的文件。' }
& docker build --platform "linux/$Architecture" -t $imageTag $buildDirectory
if ($LASTEXITCODE -ne 0) { throw 'Docker 镜像构建失败。' }
$imageTar = Join-Path $buildDirectory "wb2api-panel-$versionNumber-linux-$Architecture.tar"
& docker save $imageTag -o $imageTar
if ($LASTEXITCODE -ne 0) { throw 'Docker 镜像导出失败。' }
$imageHash = (Get-FileHash -LiteralPath $imageTar -Algorithm SHA256).Hash
"$imageHash  $(Split-Path -Leaf $imageTar)" | Set-Content -LiteralPath "$imageTar.sha256" -Encoding ascii
Write-Host "Exported: $imageTar"
Write-Host '将 tar 导入 NAS 后，把 docker-compose.yml 的 image 设置为上述镜像名称。'
