# safe-file-processor

**WSL2 Safe File Processing Workflow | Hermes Agent SKILL**

A secure file processing workflow for WSL2 that migrates files from Windows paths (`/mnt/c/`, `~/bridge/`) to a Linux hot zone, bypasses the 9P protocol performance trap, and auto-delivers results to the Windows Desktop `Hermes_Outbox`.

---

## Who Is This For

| Use Case | Description |
| --- | --- |
| **WSL2 users** | Running WSL2 on Windows, need to process files from the Windows filesystem in Linux |
| **Hermes Agent users** | Need a safe, standardized file-processing SKILL for AI Agent integration |
| **Batch processing needs** | Frequent image conversion, PDF text extraction, compress/decompress, audio/video conversion |
| **9P performance sensitive** | Frustrated by slow execution under `/mnt/c/` |

## Who Is This NOT For

| Not For | Description |
| --- | --- |
| **Pure Windows users** | No WSL2 installed, or unwilling to use Linux CLI |
| **GUI dependent** | Need drag-and-drop, right-click menus, visual progress bars |
| **Occasional single-file** | Only convert 1-2 files per year; not worth the setup |
| **Cloud processing users** | Already satisfied with online conversion tools |
| **Non-technical users** | Uncomfortable with command line; `bash` is a headache |

## Features

- **Hot-zone Isolation**

  Each task creates a `YYYYMMDD-HHMMSS-PID` subdirectory. All processing happens inside the hot zone; original files remain read-only.

- **9P Guard**

  `sfp-process` enforces that the current working directory must be inside `SFP_HOT_ZONE`. Execution under `/mnt/c/`, `/mnt/d/`, or `~/bridge/` is rejected immediately.

- **Toolbox Verification**

  `install.sh` probes installed CLI tools and generates `~/.config/sfp/toolbox`. `sfp-process` refuses to run if the required tool is not marked present.

- **NTFS Permission Fix**

  When delivering to the Windows Desktop, `sfp-out` automatically runs `cmd.exe attrib -R` to remove the NTFS read-only attribute.

- **Auto-cleanup**

  `sfp-clean` enforces a four-layer whitelist (forbids `/`, `$HOME`, `..`, and non-hot-zone paths) before deleting the isolation directory.

---

## Installation

```bash
git clone https://github.com/paul099933/safe-file-processor.git
cd safe-file-processor
./install.sh
```

`install.sh` generates `~/.config/sfp/toolbox` based on detected tools (ImageMagick, FFmpeg, Pandoc, Tesseract, etc.).

## Quick Start

### Quick Mode — `sfp-convert`

For single-file format conversion (e.g., jpg → webp, pdf → txt). Automatically runs the full 4-stage pipeline.

```bash
./scripts/sfp-convert input.jpg output.webp
```

### Atomic Mode — 4-stage manual

For operation-type tasks (delete PDF pages, crop, merge, clean metadata) or when `sfp-convert` returns `ROUTE_FAIL`.

```bash
DIR=$(./scripts/sfp-in /mnt/c/Users/Admin/Desktop/file.pdf)
cd "$DIR"
../scripts/sfp-process pdftotext file.pdf output.txt
../scripts/sfp-out output.txt
../scripts/sfp-clean "$DIR"
```

### Batch Mode — `sfp-batch`

For multiple files with placeholder substitution. Uses a unified hot zone and packs remaining outputs into `tar.gz`.

```bash
./scripts/sfp-batch ~/bridge/desktop/*.jpg "convert {} {..webp}"
```

**Placeholders:**

- `{}` — full input path
- `{.}` — basename without extension
- `{..ext}` — basename with new extension

---

## Architecture

```
safe-file-processor/
├── install.sh              # Env probe + toolbox generation
├── LICENSE
├── README.md
├── README.zh.md            # Chinese version
├── SKILL.md                # Hermes Agent calling specification
├── references/
│   └── patterns.md         # Complex scenario extensions
└── scripts/
    ├── sfp-in              # Stage 1: migrate to hot-zone isolation dir
    ├── sfp-process         # Stage 2: 9P guard + toolbox check + execute
    ├── sfp-out             # Stage 3: quality gate + desktop probe + NTFS fix
    ├── sfp-clean           # Stage 4: 4-layer whitelist safe cleanup
    ├── sfp-convert         # Quick mode: auto 4-stage closed loop
    └── sfp-batch           # Batch mode: unified hot zone + tar delivery
```

## 4-Stage Atomic Workflow

```
sfp-in <input>        →  MIGRATE_OK  →  isolation dir created
   ↓
sfp-process <cmd>     →  PROCESS_OK  →  9P guard + toolbox verified
   ↓
sfp-out <output>      →  DELIVER_OK  →  size>0 + desktop delivered
   ↓
sfp-clean $DIR        →  CLEAN_OK    →  4-layer whitelist passed
```

## Safety Mechanisms

| Mechanism | Description |
| --- | --- |
| **9P Guard** | `sfp-process` rejects execution if `cwd` is outside `SFP_HOT_ZONE`. |
| **Toolbox Check** | Reads `~/.config/sfp/toolbox` for `HAS_*` / `CAN_*` flags before running tools. |
| **Read-only Originals** | Only copies in the hot zone are modified; source files are never deleted. |
| **No Runtime Install** | If a tool is missing, the script outputs an install hint and aborts; it never runs `apt/brew/pip`. |
| **4-layer Whitelist Cleanup** | `sfp-clean` forbids `/`, `$HOME`, `..`, and paths not matching the hot-zone prefix or naming pattern. |

## Environment Variables

| Variable | Default | Description |
| --- | --- | --- |
| `SFP_HOT_ZONE` | `$HOME/.sfp/hot` | Processing hot zone directory. |
| `SFP_OUTBOX` | `$HOME/.sfp/outbox` | Fallback outbox when desktop is unreachable. |
| `XDG_CONFIG_HOME` | `$HOME/.config` | Base path for `sfp/toolbox` and cache files. |

## Standardized Output Prefixes

All scripts emit machine-readable prefixes for Agent integration.

| Prefix | Meaning |
| --- | --- |
| `MIGRATE_OK` / `MIGRATE_FAIL` | File migration result |
| `PROCESS_OK` / `PROCESS_FAIL` | Execution result |
| `DELIVER_OK` / `DELIVER_REJECT` / `DELIVER_FAIL` | Delivery result |
| `CLEAN_OK` / `CLEAN_REJECT` | Cleanup result |
| `CONVERT_OK` / `CONVERT_FAIL` / `ROUTE_FAIL` | Quick-mode result |
| `BATCH_OK` / `BATCH_PARTIAL` / `BATCH_FAIL` | Batch-mode result |

## License

MIT
