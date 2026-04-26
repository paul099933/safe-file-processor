# Safe File Processor

**WSL2 安全文件处理通道 | Hermes Agent SKILL**

A secure file processing workflow for WSL2 that migrates files from Windows paths (`/mnt/c/`, `~/bridge/`) to a Linux hot zone, bypasses the 9P protocol performance trap, and auto-delivers results to the Windows Desktop `Hermes_Outbox`.

面向 WSL2 环境的安全文件处理工作流。将文件从 Windows 路径（`/mnt/c/`、`~/bridge/`）迁移到 Linux 热区执行处理，规避 9P 协议性能陷阱，处理完成后自动交付到 Windows 桌面 `Hermes_Outbox`。

---

## Who Is This For | 适合谁

| 适用场景 | 说明 |
|---------|------|
| **WSL2 用户** | 在 Windows 上运行 WSL2，需要在 Linux 环境下处理 Windows 文件系统的文件 |
| **Hermes Agent 用户** | 需要为 AI Agent 提供一个安全、标准化的文件处理 SKILL |
| **批量文件处理需求** | 经常需要转换图片格式、提取 PDF 文字、压缩/解压、音视频转换等 |
| **9P 性能敏感用户** | 受够了在 `/mnt/c/` 下直接执行命令的卡慢体验 |

| Use Case | Description |
|---------|-------------|
| **WSL2 users** | Running WSL2 on Windows, need to process files from the Windows filesystem in Linux |
| **Hermes Agent users** | Need a safe, standardized file-processing SKILL for AI Agent integration |
| **Batch processing needs** | Frequent image conversion, PDF text extraction, compress/decompress, audio/video conversion |
| **9P performance sensitive** | Frustrated by slow execution under `/mnt/c/` |

## Who Is This NOT For | 不适合谁

| 不适用场景 | 说明 |
|-----------|------|
| **纯 Windows 用户** | 没有安装 WSL2，或不打算使用 Linux 命令行 |
| **GUI 依赖者** | 需要图形界面拖拽、右键菜单、可视化进度条 |
| **单文件偶尔处理** | 一年只转 1-2 个文件，不值得配置环境 |
| **云端处理用户** | 已经使用在线转换工具满足需求 |

| Not For | Description |
|---------|-------------|
| **Pure Windows users** | No WSL2 installed, or unwilling to use Linux CLI |
| **GUI dependent** | Need drag-and-drop, right-click menus, visual progress bars |
| **Occasional single-file** | Only convert 1-2 files per year; not worth the setup |
| **Cloud processing users** | Already satisfied with online conversion tools |
| **Non-technical users** | Uncomfortable with command line; `bash` is a headache |

## Features | 核心特性

- **Hot-zone Isolation | 热区隔离**  
  Each task creates a `YYYYMMDD-HHMMSS-PID` subdirectory. All processing happens inside the hot zone; original files remain read-only.  
  每个任务创建 `YYYYMMDD-HHMMSS-PID` 子目录，所有操作在热区内完成，原始文件只读。

- **9P Guard | 9P 红线**  
  `sfp-process` enforces that the current working directory must be inside `SFP_HOT_ZONE`. Execution under `/mnt/c/`, `/mnt/d/`, or `~/bridge/` is rejected immediately.  
  `sfp-process` 强制检查当前目录必须在 `SFP_HOT_ZONE` 内，禁止在 `/mnt/c/`、`/mnt/d/`、`~/bridge/` 下直接执行。

- **Toolbox Verification | 工具箱检查**  
  `install.sh` probes installed CLI tools and generates `~/.config/sfp/toolbox`. `sfp-process` refuses to run if the required tool is not marked present.  
  `install.sh` 探测已安装 CLI 工具并生成 `~/.config/sfp/toolbox`，`sfp-process` 工具缺失时拒绝执行。

- **NTFS Permission Fix | NTFS 修权**  
  When delivering to the Windows Desktop, `sfp-out` automatically runs `cmd.exe attrib -R` to remove the NTFS read-only attribute.  
  交付到 Windows 桌面时，自动执行 `cmd.exe attrib -R` 移除 NTFS 只读属性。

- **Auto-cleanup | 自动清理**  
  `sfp-clean` enforces a four-layer whitelist (forbids `/`, `$HOME`, `..`, and non-hot-zone paths) before deleting the isolation directory.  
  `sfp-clean` 执行四重白名单检查（禁止根目录、`$HOME`、`..`、热区外路径）后删除隔离目录。

---

## Installation | 安装

```bash
git clone https://github.com/paul099933/safe-file-processor.git
cd safe-file-processor
./install.sh
install.sh generates ~/.config/sfp/toolbox based on detected tools (ImageMagick, FFmpeg, Pandoc, Tesseract, etc.).
install.sh 根据探测到的工具（ImageMagick、FFmpeg、Pandoc、Tesseract 等）生成 ~/.config/sfp/toolbox。
Quick Start | 快速开始
Quick Mode — sfp-convert | 快捷模式
For single-file format conversion (e.g., jpg → webp, pdf → txt). Automatically runs the full 4-stage pipeline.
单文件格式转换（如 jpg → webp、pdf → txt），自动走完 4 阶段闭环。
bash
./scripts/sfp-convert input.jpg output.webp

Atomic Mode — 4-stage manual | 原子模式（4 阶段手动）
For operation-type tasks (delete PDF pages, crop, merge, clean metadata) or when sfp-convert returns ROUTE_FAIL.
操作型场景（删除 PDF 页面、裁剪、合并、清洗元数据）或 sfp-convert 返回 ROUTE_FAIL 时使用。
bash
DIR=$(./scripts/sfp-in /mnt/c/Users/Admin/Desktop/file.pdf)
cd "$DIR"
../scripts/sfp-process pdftotext file.pdf output.txt
../scripts/sfp-out output.txt
../scripts/sfp-clean "$DIR"

Batch Mode — sfp-batch | 批量模式
For multiple files with placeholder substitution. Uses a unified hot zone and packs remaining outputs into tar.gz.
多文件占位符替换处理，统一热区，剩余输出打包为 tar.gz。
bash
./scripts/sfp-batch ~/bridge/desktop/*.jpg "convert {} {..webp}"
Placeholders | 占位符:
{} — full input path | 完整输入路径
{.} — basename without extension | 无扩展名的文件名
{..ext} — basename with new extension | 带新扩展名的文件名

Architecture | 架构
plain
safe-file-processor/
├── install.sh              # Env probe + toolbox generation
├── LICENSE
├── README.md
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

4-Stage Atomic Workflow | 4 阶段原子流程
plain
sfp-in <input>        →  MIGRATE_OK  →  isolation dir created
   ↓
sfp-process <cmd>     →  PROCESS_OK  →  9P guard + toolbox verified
   ↓
sfp-out <output>      →  DELIVER_OK  →  size>0 + desktop delivered
   ↓
sfp-clean $DIR        →  CLEAN_OK    →  4-layer whitelist passed

Safety Mechanisms | 安全机制
| Mechanism                     | Description                                                                                           | 说明                               |
| ----------------------------- | ----------------------------------------------------------------------------------------------------- | -------------------------------- |
| **9P Guard**                  | `sfp-process` rejects execution if `cwd` is outside `SFP_HOT_ZONE`.                                   | 当前目录不在热区内时拒绝执行。                  |
| **Toolbox Check**             | Reads `~/.config/sfp/toolbox` for `HAS_*` / `CAN_*` flags before running tools.                       | 执行前读取工具箱标记，缺失时拒绝。                |
| **Read-only Originals**       | Only copies in the hot zone are modified; source files are never deleted.                             | 只修改热区副本，不删除原始文件。                 |
| **No Runtime Install**        | If a tool is missing, the script outputs an install hint and aborts; it never runs `apt/brew/pip`.    | 工具缺失时输出安装提示并终止，不自动安装。            |
| **4-layer Whitelist Cleanup** | `sfp-clean` forbids `/`, `$HOME`, `..`, and paths not matching the hot-zone prefix or naming pattern. | 禁止删除根目录、`$HOME`、含 `..` 路径及非热区目录。 |

Environment Variables | 环境变量
| Variable          | Default             | Description                                  | 说明                       |
| ----------------- | ------------------- | -------------------------------------------- | ------------------------ |
| `SFP_HOT_ZONE`    | `$HOME/.sfp/hot`    | Processing hot zone directory.               | 处理热区目录。                  |
| `SFP_OUTBOX`      | `$HOME/.sfp/outbox` | Fallback outbox when desktop is unreachable. | 桌面不可达时的回退出口。             |
| `XDG_CONFIG_HOME` | `$HOME/.config`     | Base path for `sfp/toolbox` and cache files. | `sfp/toolbox` 及缓存文件的基路径。 |

Standardized Output Prefixes | 输出标准化前缀
All scripts emit machine-readable prefixes for Agent integration.
所有脚本输出机器可读的标准化前缀，供 Agent 集成使用。
| Prefix                                           | Meaning               | 含义     |
| ------------------------------------------------ | --------------------- | ------ |
| `MIGRATE_OK` / `MIGRATE_FAIL`                    | File migration result | 迁移结果   |
| `PROCESS_OK` / `PROCESS_FAIL`                    | Execution result      | 执行结果   |
| `DELIVER_OK` / `DELIVER_REJECT` / `DELIVER_FAIL` | Delivery result       | 交付结果   |
| `CLEAN_OK` / `CLEAN_REJECT`                      | Cleanup result        | 清理结果   |
| `CONVERT_OK` / `CONVERT_FAIL` / `ROUTE_FAIL`     | Quick-mode result     | 快捷模式结果 |
| `BATCH_OK` / `BATCH_PARTIAL` / `BATCH_FAIL`      | Batch-mode result     | 批量模式结果 |

License | 许可
MIT
