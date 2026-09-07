# bzip3 vs RAR

A compression benchmark of **bzip3 1.5.3** against **RAR 7.23** on 1.5 GB of real, already-on-disk binary files.

Published because this comparison does not seem to exist. bzip3's own README benchmarks it against xz, bzip2, zstd and lrzip; the 2025 round-ups compare it to xz, zstd and brotli. RAR is absent from all of them. The one place both appear is Matt Mahoney's [Large Text Compression Benchmark](https://mattmahoney.net/dc/text.html), where the RAR entry is WinRAR **3.60b3** from 2006 running RAR4 PPMd with a 128 MB dictionary — not RAR5 `-m5` with a 1 GB dictionary, and the input there is a single plain-text file.

So: modern RAR, maximum settings, binary data.

## Environment

| | |
|---|---|
| CPU | Intel Core i5-8300H, 4 cores / 8 threads, 2.30 GHz |
| RAM | 64 GB |
| Disk | MLD M300 NVMe SSD (inputs and outputs both on it) |
| OS | Windows 11 Pro 10.0.26200 |
| RAR | 7.23 (`Rar.exe`, 64-bit) |
| bzip3 | 1.5.3, compiled locally from the release tarball with GCC 15.2.0 (MinGW-w64) |

bzip3 was built from source rather than using the published `bzip3-x86_64.exe`, so that the binary under test provably corresponds to the source that was read:

```
gcc -O3 -std=gnu11 -DPTHREAD -include version_local.h -I src/bzip3-1.5.3/include \
    -o bzip3-local.exe src/bzip3-1.5.3/src/main.c src/bzip3-1.5.3/src/libbz3.c \
    -lpthread -static -s
```

`version_local.h` is a one-line file containing `#define VERSION "1.5.3"` — it only replaces the macro that autotools would otherwise supply. The build produced no warnings, and a compress/decompress round trip on 12 MB of real data returned a byte-identical SHA-256.

## Test data

Five files already present on the machine, chosen to sit near 100/200/300/400/500 MB and to be in formats that are *not* pre-compressed containers. Native DLLs and an Electron `asar` archive (which is a plain concatenation with a header, no compression) qualify; game archives, `.lightdb`/`.raw` texture blobs, media and installers were measured beforehand and rejected because a gzip probe over three slices of each showed 88–99 % residual size, i.e. their payloads are already compressed.

| Target | File | Size (bytes) | What it is |
|---|---|---:|---|
| 100 MB | `cublas64_12.dll` | 104,883,712 | NVIDIA cuBLAS, from a PyTorch/ComfyUI distribution |
| 200 MB | `xul.dll` | 206,193,280 | Thunderbird 155.0 core library |
| 300 MB | `vivaldi.dll` | 315,247,016 | Vivaldi 8.2.4133.47 core library |
| 400 MB | `app.asar` | 431,096,742 | Electron asar bundle (MiniMax Code) |
| 500 MB | `ggml-cuda.dll` | 533,257,912 | llama.cpp CUDA backend, from LM Studio |
| | **Total** | **1,590,678,662** | |

## Commands

```
rar a -m5 -md1g -ep -o+ -idq <archive.rar> <input>
bzip3 -e -f -b 511 <input> <archive.bz3>
bzip3 -e -f -b 32 -j 8 <input> <archive.bz3>
```

`-m5` is RAR's best compression mode and `-md1g` its largest dictionary. bzip3 has no compression levels; block size is the equivalent knob, so `-b 511` (the maximum, 511 MiB) is bzip3's "best" setting. Note the consequence: at 511 MiB every one of these files fits in a single block, and bzip3 parallelises per block, so `-j` has nothing to spread and that column runs on **one core**. The third column, `-b 32 -j 8`, is the configuration that actually uses the machine the way RAR does.

## Results

### Compressed size

| File | Original | `rar -m5 -md1g` | `bzip3 -b 511` | `bzip3 -b 32 -j 8` |
|---|---:|---:|---:|---:|
| `cublas64_12.dll` | 104,883,712 | **48,117,237** (45.88 %) | 54,105,281 (51.59 %) | 57,574,061 (54.89 %) |
| `xul.dll` | 206,193,280 | **61,391,445** (29.77 %) | 65,589,667 (31.81 %) | 64,410,018 (31.24 %) |
| `vivaldi.dll` | 315,247,016 | 106,861,003 (33.90 %) | **106,279,605** (33.71 %) | 107,047,610 (33.96 %) |
| `app.asar` | 431,096,742 | **47,658,890** (11.06 %) | 48,364,997 (11.22 %) | 53,932,081 (12.51 %) |
| `ggml-cuda.dll` | 533,257,912 | **94,232,187** (17.67 %) | 94,599,246 (17.74 %) | 102,171,689 (19.16 %) |
| **Total** | **1,590,678,662** | **358,260,762 (22.52 %)** | 368,938,796 (23.19 %) | 385,135,459 (24.21 %) |

### Time and CPU

Wall clock, with CPU time of the process in parentheses.

| File | `rar -m5 -md1g` | `bzip3 -b 511` | `bzip3 -b 32 -j 8` |
|---|---:|---:|---:|
| `cublas64_12.dll` | 9.25 s (41.6) | 25.23 s (25.0) | 10.21 s (28.0) |
| `xul.dll` | 25.23 s (131.1) | 42.39 s (42.0) | 13.49 s (68.8) |
| `vivaldi.dll` | 54.65 s (285.2) | 84.30 s (83.5) | 24.65 s (117.7) |
| `app.asar` | 30.72 s (133.9) | 48.10 s (47.8) | 14.93 s (71.0) |
| `ggml-cuda.dll` | 48.56 s (219.4) | 73.03 s (72.5) | 19.53 s (110.8) |
| **Total** | **168.41 s** (811.2) | 273.05 s (270.8) | **82.81 s** (396.3) |
| **Throughput** | 9.01 MiB/s | 5.56 MiB/s | **18.32 MiB/s** |

## Observations

**RAR wins on size by 2.98 %** — 358.3 MB against 368.9 MB — and it spends 811 CPU seconds to do it, against bzip3's 271. Per unit of processor work, single-threaded bzip3 is three times more efficient. RAR averaged 4.8 cores busy across the run.

**Nearly the entire size gap comes from one file.** On `cublas64_12.dll` RAR is 5.99 MB ahead. Across the other four files combined the difference is 4.69 MB (310.1 MB vs 314.8 MB) — under 1.5 %.

**bzip3 wins one outright.** On `vivaldi.dll`, `-b 511` produced 106,279,605 bytes against RAR's 106,861,003, while using 83.5 CPU seconds against RAR's 285.2.

**The parallel configuration is the practical one.** `-b 32 -j 8` finishes in half of RAR's wall-clock time (82.81 s vs 168.41 s) for half the CPU (396.3 s vs 811.2 s), and gives up 1.69 percentage points of total ratio. If throughput matters, that is the trade.

**Smaller blocks are not always worse.** On `xul.dll`, `-b 32` beat `-b 511`: 64,410,018 vs 65,589,667 bytes. The other four files behaved as expected, with the larger block compressing better. Not investigated.

## Method notes

- Each input is read end to end before its runs, so all three compressors read from a warm page cache and the timings measure compression rather than disk.
- Timing is a `System.Diagnostics.Stopwatch` around process start to process exit; CPU time is `Process.TotalProcessorTime`.
- Each archive is measured and then deleted before the next run, to keep free disk space from influencing anything.
- One run per configuration. These are not averaged over repeats.
- Decompression was not timed. Only compression size and time were measured.

## Reproducing

`build.ps1` compiles bzip3 from the release tarball; `benchmark.ps1` runs the three configurations over every file in a `data\` directory and writes `result.csv`. Both are PowerShell 7 and their console output is in Turkish. Point `benchmark.ps1` at your own `data\` directory — the input files themselves are not in this repository, since they are 1.5 GB of third-party binaries.

`result.csv` and `benchmark-log.txt` are the raw output of the run reported above.
