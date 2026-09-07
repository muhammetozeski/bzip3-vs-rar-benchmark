param(
    # Acilmis bzip3 kaynak agacinin koku (icinde src\ ve include\ olmali)
    [string]$SourceDir = (Join-Path $PSScriptRoot "src\bzip3-1.5.3"),
    # Uretilecek calistirilabilir
    [string]$OutFile = (Join-Path $PSScriptRoot "bzip3-local.exe"),
    # bzip3 surumu, VERSION makrosuna yazilir
    [string]$Version = "1.5.3"
)

$ErrorActionPreference = 'Stop'

# VERSION makrosunu komut satiri tirnak kacisi olmadan vermek icin kucuk bir baslik
$verHeader = Join-Path $PSScriptRoot "version_local.h"
Set-Content -LiteralPath $verHeader -Encoding ASCII -Value "#define VERSION `"$Version`""

if (Test-Path -LiteralPath $OutFile) { Remove-Item -LiteralPath $OutFile -Force }

$gccArgs = @(
    "-O3", "-std=gnu11", "-DPTHREAD",
    "-include", $verHeader,
    "-I", (Join-Path $SourceDir "include"),
    "-o", $OutFile,
    (Join-Path $SourceDir "src\main.c"),
    (Join-Path $SourceDir "src\libbz3.c"),
    "-lpthread", "-static", "-s"
)

Write-Output "gcc -O3 -std=gnu11 -DPTHREAD -include version_local.h -I <src>\include -o <out> <src>\src\main.c <src>\src\libbz3.c -lpthread -static -s"
Write-Output ""
& gcc @gccArgs
$code = $LASTEXITCODE
Write-Output ""
Write-Output "gcc cikis kodu: $code"

if ($code -eq 0 -and (Test-Path -LiteralPath $OutFile)) {
    $fi = Get-Item -LiteralPath $OutFile
    Write-Output ("Uretildi: {0}  {1:N0} bayt" -f $fi.Name, $fi.Length)
    Write-Output "SHA256: $((Get-FileHash -LiteralPath $OutFile -Algorithm SHA256).Hash)"
} else {
    Write-Output "DERLEME BASARISIZ"
}
