param(
    [Parameter(Mandatory = $true)]
    [string]$RepoUrl,
    [string]$CheckoutPath = ""
)
$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$OriginalDirectory = (Get-Location).Path
if ([string]::IsNullOrWhiteSpace($CheckoutPath)) {
    $CheckoutPath = Join-Path (Split-Path $ProjectRoot -Parent) "ink-escape-github"
}
$CheckoutPath = [System.IO.Path]::GetFullPath($CheckoutPath)
if (Test-Path -LiteralPath $CheckoutPath) {
    throw "Hedef klasor zaten var: $CheckoutPath. Bos bir hedef icin -CheckoutPath kullan."
}
function Invoke-ProjectGit {
    param([string[]]$GitArguments)
    & git @GitArguments
    if ($LASTEXITCODE -ne 0) { throw "Git komutu tamamlanamadi: $($GitArguments[0])" }
}
try {
    # Clone preserves an existing README/initial commit. No force push is used.
    Invoke-ProjectGit -GitArguments @("clone", "--", $RepoUrl, $CheckoutPath)
    $Items = @("lib", "assets", "android", "ios", "test", "scripts", "docs", ".vscode", "pubspec.yaml", "pubspec.lock", "analysis_options.yaml", "README.md", ".gitignore", ".metadata")
    foreach ($Item in $Items) {
        $Source = Join-Path $ProjectRoot $Item
        if (Test-Path -LiteralPath $Source) {
            Copy-Item -LiteralPath $Source -Destination $CheckoutPath -Recurse -Force
        }
    }
    Set-Location -LiteralPath $CheckoutPath
    Invoke-ProjectGit -GitArguments @("checkout", "-B", "main")
    Invoke-ProjectGit -GitArguments @("add", ".")
    $Changes = & git status --porcelain
    if ($LASTEXITCODE -ne 0) { throw "Git durumu okunamadi." }
    if ($Changes) {
        Invoke-ProjectGit -GitArguments @("commit", "-m", "Create native Ink Escape Flutter and Flame prototype")
    }
    Invoke-ProjectGit -GitArguments @("push", "-u", "origin", "main")
    Write-Host "Push tamamlandi. Calisma klasoru: $CheckoutPath"
} finally {
    Set-Location -LiteralPath $OriginalDirectory
}
