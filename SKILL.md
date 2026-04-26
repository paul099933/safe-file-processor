---
name: safe-file-processor 
description: > 
  当用户需要处理文件、格式转换、批量处理、PDF提取、图片/音视频转换、 压缩解压、内容编辑（删除页面/裁剪/清洗元数据）时使用。 自动将文件迁移到隔离热区处理，结果交付到桌面 Hermes_Outbox。 
metadata: 
  hermes:
     tags: ["wsl2", "filesystem", "conversion", "batch", "pdf", "image", "video", "windows"]
---
Safe File Processor
触发条件
用户提到以下任何关键词时立即使用：
处理文件 / 转换格式 / 把 A 转成 B / 文件转格式 / 改扩展名
批量处理 / 批量转换 / 压缩 / 解压 / 打包 / 归档
PDF 转文字 / PDF 转 Word / PDF 转 TXT / 扫描件识别 / OCR
图片转换 / 图片压缩 / 视频转 GIF / 提取音频 / 音视频转换
文件太大 / Windows 文件处理慢 / 9P 卡顿
删除 PDF 页面 / 裁剪图片 / 去水印 / 掐头去尾 / 清洗元数据
合并 PDF / 加水印 / 加字幕
任何涉及 ~/bridge/、/mnt/c/、/mnt/d/ 的文件操作

核心原则（绝对禁止）
禁止在 /mnt/c/、/mnt/d/、~/bridge/ 下直接执行任何命令
原因：9P 协议性能极差，大文件会卡死
正确做法：先用 sfp-in 迁移到热区，所有操作在热区内执行
禁止自己调用 cp、mv、convert、ffmpeg、pandoc、pdftotext 等工具
原因：绕过 9P 红线检查和工具箱检查，安全风险
正确做法：通过 sfp-process 执行，或走 sfp-convert 快捷通道
即使只是改扩展名（如 txt->md），也必须走 sfp-process cp，禁止自己 cp
禁止运行时安装软件（apt/brew/pip）
工具缺失时，使用脚本输出的 install_hint 回复用户
由用户决定是否安装，Agent 不代劳
禁止删除用户原始文件
只操作热区副本，原始文件只读
热区隔离
每个任务使用 YYYYMMDD-HHMMSS-PID 子目录
任务结束必须 sfp-clean

使用方式（优先级顺序）
第一步：优先尝试快捷模式（sfp-convert）
对于任何单文件格式变更（包括扩展名变更），首先尝试：
${HERMES_SKILL_DIR}/scripts/sfp-convert <输入> <输出>
如果返回 CONVERT_OK：任务完成，无需后续步骤
如果返回 ROUTE_FAIL：降级到原子模式
强制：即使只是改扩展名（如 txt->md、jpg->jpeg），也必须走 sfp-convert
禁止：Agent 自己调用 cp、mv、重命名等命令

第二步：快捷失败时，走原子模式（4 阶段）
DIR=$(${HERMES_SKILL_DIR}/scripts/sfp-in <输入文件>)
cd "$DIR"
${HERMES_SKILL_DIR}/scripts/sfp-process <命令> [参数...]
${HERMES_SKILL_DIR}/scripts/sfp-out <输出文件>
${HERMES_SKILL_DIR}/scripts/sfp-clean "$DIR"
阶段说明：
阶段 1（sfp-in）：迁移到热区隔离目录，输出 MIGRATE_OK
阶段 2（sfp-process）：在热区内执行转换命令，禁止自己调工具
阶段 3（sfp-out）：质量门控 + 桌面探测 + NTFS 修权
阶段 4（sfp-clean）：删除隔离目录

第三步：批量处理（sfp-batch）
${HERMES_SKILL_DIR}/scripts/sfp-batch <输入目录或通配符> <命令模板>

## 批量改扩展名（如 txt→md、jpg→png）

**禁止**使用 `sfp-batch`。
**必须**使用 `for` 循环调 `sfp-convert`：

```bash
for f in ~/bridge/desktop/*.txt; do
    ${HERMES_SKILL_DIR}/scripts/sfp-convert "$f" "$(basename "$f" .txt).md"
done
```

**原因：**
- `sfp-batch` 不自动处理扩展名变更的文件名生成
- `sfp-convert` 会自动路由到正确的转换工具（或降级到原子模式）
- 每个文件独立走完整流程，确保质量门控和错误隔离

**处理结果：**
- `CONVERT_OK`：快捷模式成功，文件自动交付到 Hermes_Outbox
- `ROUTE_FAIL`：降级到原子模式，需继续执行 4 阶段流程

工具映射表（Agent 查表决策，但必须通过 sfp-process 调用）
| 场景        | 输入                      | 输出               | 命令模板                                |
| :-------- | :---------------------- | :--------------- | :---------------------------------- |
| 图片转换      | jpg/png/webp/gif/bmp    | jpg/png/webp/gif | convert {in} {out}                  |
| 音视频       | mp4/mov/avi/mkv/mp3/wav | mp4/mp3/wav/webm | ffmpeg -i {in} {out}                |
| 文档        | md/txt/html             | pdf/docx/epub    | pandoc {in} -o {out}                |
| 备注       | HTML含SVG时需 rsvg-convert | 和 texlive        | sudo apt install librsvg2-bin texlive-latex-base |
| 文本重命名     | txt/md                  | md/txt           | cp {in} {out}（**仍走 sfp-process**）   |
| PDF 文字    | pdf（文字版）                | txt              | pdftotext {in} {out}                |
| PDF 扫描    | pdf（扫描版）                | txt              | tesseract {in} {out} -l chi\_sim    |
| 压缩解压      | zip/tar/gz/7z           | 解压目录             | tar xf / unzip / 7z x               |
| 删除 PDF 页面 | pdf                     | pdf              | pdftk {in} cat ... output {out}     |
| 裁剪图片      | jpg/png                 | jpg/png          | convert {in} -crop ... {out}        |
| 裁剪视频      | mp4                     | mp4              | ffmpeg -i {in} -ss ... -t ... {out} |
| 清洗元数据     | jpg/pdf                 | jpg/pdf          | exiftool -all= {in} -o {out}        |
| 合并 PDF    | 多个 pdf                  | pdf              | pdftk {in1} {in2} cat output {out}   |
> **注意**：删除 PDF 页面、裁剪图片/视频、清洗元数据、合并 PDF 等操作型场景仅支持原子模式（4 阶段流程），不支持 `sfp-convert` 快捷模式。

PDF 文字版 vs 扫描版判断：
先执行 pdftotext -l 1 <file>
字符数 > 0 -> 文字版，用 pdftotext
字符数 = 0 -> 扫描版，用 tesseract
错误处理手册（根据脚本 stdout 前缀直接回复）
| 前缀                             | 含义          | Agent 回复话术                                      |
| :----------------------------- | :---------- | :---------------------------------------------- |
| MIGRATE\_OK                    | 迁移成功        | 继续下一步                                           |
| MIGRATE\_FAIL                  | 迁移失败        | 使用脚本输出的 reason 和 path 回复                        |
| PROCESS\_OK                    | 处理成功        | 继续交付                                            |
| PROCESS\_FAIL: reason="9P红线违反" | 在 /mnt/ 下执行 | "检测到在 Windows 路径下执行，已拒绝。请先运行 sfp-in 迁移到热区后再处理。" |
| PROCESS\_FAIL: reason="工具未安装"  | 没装工具        | "需要安装 $need，请运行：$install\_hint（脚本已提供具体命令）"      |
| PROCESS\_FAIL: reason="未知命令"   | 命令不存在       | "不支持的转换命令：\$need，请检查工具映射表。"                     |
| PROCESS\_FAIL: reason="命令执行失败" | 执行报错        | "转换命令执行失败，错误码 \$exit\_code。建议检查输入文件格式或命令参数。"    |
| DELIVER\_OK                    | 交付成功        | "文件已交付到：\$dest"                                 |
| DELIVER\_REJECT                | 质量未通过       | 使用脚本输出的 reason 和 file 回复                        |
| DELIVER\_FAIL                  | 交付失败        | 使用脚本输出的 reason 回复                               |
| CLEAN\_OK                      | 清理成功        | 流程结束                                            |
| CLEAN\_REJECT                  | 安全拦截        | 使用脚本输出的 reason 回复                               |
| CONVERT\_OK                    | 快捷模式成功      | "转换完成，文件已交付到：\$output"                          |
| CONVERT\_FAIL                  | 快捷模式失败      | 使用脚本输出的 reason 回复，或降级到原子模式                      |
| ROUTE\_FAIL                    | 无匹配路由       | 读取 references/patterns.md，走原子模式                 |
| BATCH\_PARTIAL                 | 批量部分成功      | "批量处理完成，$success 个成功，$failed 个失败。"              |

复杂场景加载条件
以下情况读取 ${HERMES_SKILL_DIR}/references/patterns.md：
sfp-convert 返回 ROUTE_FAIL（无匹配路由）
sfp-process 返回工具缺失且安装包体积 > 500MB
批量文件数量 > 20 个或总大小 > 1GB
输入为压缩包（zip/tar/7z）且需要解压后处理
热区空间不足（df 显示 < 2GB）
9P 路径迁移超时（> 30s）
交付后用户反馈文件缺失、损坏或权限问题
PDF 转换结果为空或乱码
处理大文件（> 500MB）时内存或磁盘告警
混合格式批量处理
加密或损坏的压缩包
NTFS 只读属性修复失败
桌面路径探测失败
文件名含中文/特殊字符导致交付失败