param(
    [string]$SourceDir = ".\MMFA Dump Media\Sounds",
    [string]$OutDir = ".\assets\sounds_ogg",
    [int]$Quality = 5
)

$ErrorActionPreference = "Stop"

$ffmpeg = Get-Command ffmpeg -ErrorAction SilentlyContinue
if ($null -eq $ffmpeg) {
    throw "ffmpeg was not found in PATH. Install ffmpeg or place ffmpeg.exe in PATH, then run this script again."
}

$sourceRoot = Resolve-Path -LiteralPath $SourceDir
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$outRoot = Resolve-Path -LiteralPath $OutDir

$inputs = Get-ChildItem -LiteralPath $sourceRoot -File | Where-Object {
    $_.Extension -match '^\.(wav|mp3|ogg)$'
}

foreach ($input in $inputs) {
    $name = [System.IO.Path]::GetFileNameWithoutExtension($input.Name)
    $output = Join-Path $outRoot ($name + ".ogg")

    Write-Host "Converting $($input.Name) -> $([System.IO.Path]::GetFileName($output))"

    & $ffmpeg.Source `
        -y `
        -hide_banner `
        -loglevel error `
        -i $input.FullName `
        -vn `
        -map_metadata -1 `
        -c:a libvorbis `
        -q:a $Quality `
        $output
}

Write-Host "Done. Converted $($inputs.Count) sound file(s) to $outRoot"
