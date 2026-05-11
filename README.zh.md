# safe-file-processor

**WSL2 安全文件处理工作流 | Hermes Agent SKILL**

面向 WSL2 环境的安全文件处理工作流。将文件从 Windows 路径（`/mnt/c/`、`~/bridge/`）迁移到 Linux 热区执行处理，规避 9P 协议性能陷阱，处理完成后自动交付到 Windows 桌面 `Hermes_Outbox`。

---

## 适合谁

| 适用场景 | 说明 |
| --- | --- |
| **WSL2 用户** | 在 Windows 上运行 WSL2，需要在 Linux 环境下处理 Windows 文件系统的文件 |
| **Hermes Agent 用户** | 需要为 AI Agent 提供一个安全、标准化的文件处理 SKILL |
| **批量文件处理需求** | 经常需要转换图片格式、提取 PDF 文字、压缩/解压、音视频转换等 |
| **9P 性能敏感用户** | 受够了在 `/mnt/c/` 下直接执行命令的卡慢体验 |

## 不适合谁

| 不适用场景 | 说明 |
| --- | --- |
| **纯 Windows 用户** | 没有安装 WSL2，或不打算使用 Linux 命令行 |
| **GUI 依赖者** | 需要图形界面拖拽、右键菜单、可视化进度条 |
| **单文件偶尔处理** | 一年只转 1-2 个文件，不值得配置环境 |
| **云端处理用户** | 已经使用在线转换工具满足需求 |
| **非技术用户** | 看到命令行就头疼，不适合使用 |

## 核心特性

- **热区隔离**

  每个任务创建 `YYYYMMDD-HHMMSS-PID` 子目录，所有操作在热区内完成，原始文件只读。

- **9P 红线**

  `sfp-process` 强制检查当前目录必须在 `SFP_HOT_ZONE` 内，禁止在 `/mnt/c/`、`/mnt/d/`、`~/bridge/` 下直接执行。

- **工具箱检查**

  `install.sh` 探测已安装 CLI 工具并生成 `~/.config/sfp/toolbox`，`sfp-process` 工具缺失时拒绝执行。

- **NTFS 修权**

  交付到 Windows 桌面时，`sfp-out` 自动执行 `cmd.exe attrib -R` 移除 NTFS 只读属性。

- **自动清理**

  `sfp-clean` 执行四重白名单检查（禁止根目录、`$HOME`、`..`、热区外路径）后删除隔离目录。

---

## 安装

```bash
git clone https://github.com/paul099933/safe-file-processor.git
cd safe-file-processor
./install.sh
```

`install.sh` 根据探测到的工具（ImageMagick、FFmpeg、Pandoc、Tesseract 等）生成 `~/.config/sfp/toolbox`。

## 快速开始

### 快捷模式 — `sfp-convert`

单文件格式转换（如 jpg → webp、pdf → txt），自动走完 4 阶段闭环。

```bash
./scripts/sfp-convert input.jpg output.webp
```

### 原子模式 — 4 阶段手动

操作型场景（删除 PDF 页面、裁剪、合并、清洗元数据）或 `sfp-convert` 返回 `ROUTE_FAIL` 时使用。

```bash
DIR=$(./scripts/sfp-in /mnt/c/Users/Admin/Desktop/file.pdf)
cd "$DIR"
../scripts/sfp-process pdftotext file.pdf output.txt
../scripts/sfp-out output.txt
../scripts/sfp-clean "$DIR"
```

### 批量模式 — `sfp-batch`

多文件占位符替换处理，统一热区，剩余输出打包为 `tar.gz`。

```bash
./scripts/sfp-batch ~/bridge/desktop/*.jpg "convert {} {..webp}"
```

**占位符：**

- `{}` — 完整输入路径
- `{.}` — 无扩展名的文件名
- `{..ext}` — 带新扩展名的文件名

---

## 架构

```
safe-file-processor/
├── install.sh              # 环境探测 + 工具箱生成
├── LICENSE
├── README.md               # 英文版本
├── README.zh.md            # 中文版本
├── SKILL.md                # Hermes Agent 调用规范
├── references/
│   └── patterns.md         # 复杂场景扩展
└── scripts/
    ├── sfp-in              # 阶段 1：迁移到热区隔离目录
    ├── sfp-process         # 阶段 2：9P 红线 + 工具箱检查 + 执行
    ├── sfp-out             # 阶段 3：质量门 + 桌面探测 + NTFS 修权
    ├── sfp-clean           # 阶段 4：四重白名单安全清理
    ├── sfp-convert         # 快捷模式：自动 4 阶段闭环
    └── sfp-batch           # 批量模式：统一热区 + tar 交付
```

## 4 阶段原子流程

```
sfp-in <input>        →  MIGRATE_OK  →  隔离目录创建
   ↓
sfp-process <cmd>     →  PROCESS_OK  →  9P 红线 + 工具箱验证
   ↓
sfp-out <output>      →  DELIVER_OK  →  大小>0 + 桌面交付
   ↓
sfp-clean $DIR        →  CLEAN_OK    →  四重白名单通过
```

## 安全机制

| 机制 | 说明 |
| --- | --- |
| **9P 红线** | 当前目录不在热区内时拒绝执行。 |
| **工具箱检查** | 执行前读取工具箱标记，缺失时拒绝。 |
| **只读原始文件** | 只修改热区副本，不删除原始文件。 |
| **禁止运行时安装** | 工具缺失时输出安装提示并终止，不自动安装。 |
| **四重白名单清理** | 禁止删除根目录、`$HOME`、含 `..` 路径及非热区目录。 |

## 环境变量

| 变量 | 默认值 | 说明 |
| --- | --- | --- |
| `SFP_HOT_ZONE` | `$HOME/.sfp/hot` | 处理热区目录。 |
| `SFP_OUTBOX` | `$HOME/.sfp/outbox` | 桌面不可达时的回退出口。 |
| `XDG_CONFIG_HOME` | `$HOME/.config` | `sfp/toolbox` 及缓存文件的基路径。 |

## 输出标准化前缀

所有脚本输出机器可读的标准化前缀，供 Agent 集成使用。

| 前缀 | 含义 |
| --- | --- |
| `MIGRATE_OK` / `MIGRATE_FAIL` | 迁移结果 |
| `PROCESS_OK` / `PROCESS_FAIL` | 执行结果 |
| `DELIVER_OK` / `DELIVER_REJECT` / `DELIVER_FAIL` | 交付结果 |
| `CLEAN_OK` / `CLEAN_REJECT` | 清理结果 |
| `CONVERT_OK` / `CONVERT_FAIL` / `ROUTE_FAIL` | 快捷模式结果 |
| `BATCH_OK` / `BATCH_PARTIAL` / `BATCH_FAIL` | 批量模式结果 |

## 许可

MIT
