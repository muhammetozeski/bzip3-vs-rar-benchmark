$ErrorActionPreference = 'Stop'

$root = "C:\E\Claude\temp\Bzip3Benchmark"
$data = Join-Path $root "data"
$out  = Join-Path $root "out"
$bz3  = Join-Path $root "bzip3-local.exe"
$rar  = "C:\E\kp\scoop\apps\winrar\7.23\Rar.exe"
$csv  = Join-Path $root "sonuclar.csv"

New-Item -ItemType Directory -Force $out | Out-Null

function Warm-Cache([string]$path) {
    # Dosyayi disk onbellegine al ki olcum CPU'yu olssun, diski degil
    $fs = [IO.File]::OpenRead($path)
    try {
        $buf = New-Object byte[] (4194304)
        while ($fs.Read($buf, 0, $buf.Length) -gt 0) { }
    } finally { $fs.Close() }
}

function Invoke-Timed([string]$exe, [string[]]$argList) {
    $psi = New-Object Diagnostics.ProcessStartInfo
    $psi.FileName = $exe
    foreach ($a in $argList) { $null = $psi.ArgumentList.Add($a) }
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true

    $sw = [Diagnostics.Stopwatch]::StartNew()
    $p = [Diagnostics.Process]::Start($psi)
    $so = $p.StandardOutput.ReadToEnd()
    $se = $p.StandardError.ReadToEnd()
    $p.WaitForExit()
    $sw.Stop()

    [pscustomobject]@{
        Seconds  = $sw.Elapsed.TotalSeconds
        ExitCode = $p.ExitCode
        CpuSec   = $p.TotalProcessorTime.TotalSeconds
        StdOut   = $so
        StdErr   = $se
    }
}

$results = New-Object Collections.Generic.List[object]
$files = Get-ChildItem -LiteralPath $data -File | Sort-Object Name

Write-Output "=========================================================="
Write-Output " bzip3 1.5.3 (yerel derleme)  vs  RAR 7.23  -  benchmark"
Write-Output " Baslangic: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Output "=========================================================="
Write-Output ""

foreach ($f in $files) {
    $orig = $f.Length
    Write-Output "### $($f.Name)   $('{0:N0}' -f $orig) bayt ($([math]::Round($orig/1MB,2)) MiB)"
    Warm-Cache $f.FullName

    $runs = @(
        @{ Etiket = "rar -m5 -md1g"; Exe = $rar;  Ext = ".rar"
           Args = { param($src,$dst) @("a","-m5","-md1g","-ep","-o+","-idq",$dst,$src) } },
        @{ Etiket = "bzip3 -b 511";  Exe = $bz3;  Ext = ".b511.bz3"
           Args = { param($src,$dst) @("-e","-f","-b","511",$src,$dst) } },
        @{ Etiket = "bzip3 -b 32 -j 8"; Exe = $bz3; Ext = ".b32j8.bz3"
           Args = { param($src,$dst) @("-e","-f","-b","32","-j","8",$src,$dst) } }
    )

    foreach ($r in $runs) {
        $dst = Join-Path $out ($f.BaseName + $r.Ext)
        if (Test-Path -LiteralPath $dst) { Remove-Item -LiteralPath $dst -Force }

        $argList = & $r.Args $f.FullName $dst
        $t = Invoke-Timed $r.Exe $argList

        if ($t.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $dst)) {
            Write-Output ("  {0,-18} HATA  cikis={1}" -f $r.Etiket, $t.ExitCode)
            if ($t.StdOut) { Write-Output ("    stdout: " + $t.StdOut.Trim()) }
            if ($t.StdErr) { Write-Output ("    stderr: " + $t.StdErr.Trim()) }
            continue
        }

        $csize = (Get-Item -LiteralPath $dst).Length
        $ratio = 100.0 * $csize / $orig
        $mbps  = ($orig / 1MB) / $t.Seconds

        Write-Output ("  {0,-18} {1,13:N0} bayt  %{2,6:N2}  {3,8:N2} sn  {4,6:N2} MiB/s  (CPU {5:N1} sn)" -f `
            $r.Etiket, $csize, $ratio, $t.Seconds, $mbps, $t.CpuSec)

        $results.Add([pscustomobject]@{
            Dosya        = $f.Name
            OrijinalBayt = $orig
            Arac         = $r.Etiket
            SikismisBayt = $csize
            OranYuzde    = [math]::Round($ratio,2)
            Saniye       = [math]::Round($t.Seconds,2)
            MiBps        = [math]::Round($mbps,2)
            CpuSaniye    = [math]::Round($t.CpuSec,1)
        })

        # Disk alani sinirli: olctukten sonra arsivi sil
        Remove-Item -LiteralPath $dst -Force
    }
    Write-Output ""
}

$results | Export-Csv -LiteralPath $csv -NoTypeInformation -Encoding UTF8
Write-Output "CSV yazildi: $csv"
Write-Output "Bitis: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
