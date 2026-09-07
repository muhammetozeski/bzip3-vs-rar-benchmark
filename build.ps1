$ErrorActionPreference = 'Stop'
$root = "C:\E\Claude\temp\Bzip3Benchmark"
$src  = Join-Path $root "src\bzip3-1.5.3"

# VERSION makrosunu komut satiri tirnak kacisi olmadan vermek icin kucuk bir baslik
$verHeader = Join-Path $root "version_local.h"
Set-Content -LiteralPath $verHeader -Encoding ASCII -Value '#define VERSION "1.5.3"'

$out = Join-Path $root "bzip3-local.exe"
if (Test-Path -LiteralPath $out) { Remove-Item -LiteralPath $out -Force }

$gccArgs = @(
    "-O3", "-std=gnu11", "-DPTHREAD",
    "-include", $verHeader,
    "-I", (Join-Path $src "include"),
    "-o", $out,
    (Join-Path $src "src\main.c"),
    (Join-Path $src "src\libbz3.c"),
    "-lpthread", "-static", "-s"
)

Write-Output "gcc $($gccArgs -join ' ')"
Write-Output ""
& gcc @gccArgs
$code = $LASTEXITCODE
Write-Output ""
Write-Output "gcc cikis kodu: $code"

if ($code -eq 0 -and (Test-Path -LiteralPath $out)) {
    $fi = Get-Item -LiteralPath $out
    Write-Output ("Uretildi: {0}  {1:N0} bayt" -f $fi.FullName, $fi.Length)
    Write-Output "SHA256: $((Get-FileHash -LiteralPath $out -Algorithm SHA256).Hash)"
} else {
    Write-Output "DERLEME BASARISIZ"
}
