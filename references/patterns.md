load_when:
"sfp-convert 返回 ROUTE_FAIL（无匹配路由）"
"sfp-process 返回工具缺失且安装包体积 > 500MB"
"批量文件数量 > 20 个或总大小 > 1GB"
"输入为压缩包且需要解压后处理"
"热区空间不足（df 显示 < 2GB）"
"9P 路径迁移超时（> 30s）"
"交付后用户反馈文件缺失、损坏或权限问题"
"PDF 转换结果为空或乱码（扫描版 vs 文字版判断失败）"
"处理大文件（> 500MB）时内存或磁盘告警"
"混合格式批量处理"
"加密或损坏的压缩包"
"NTFS 只读属性修复失败"
"桌面路径探测失败"
"文件名含中文/特殊字符导致交付失败"
Safe File Processor - 扩展模式库
1. 大工具安装策略（内存/磁盘敏感）
ImageMagick（~200MB）
bash
复制
# 精简版，省 100MB+
sudo apt install imagemagick --no-install-recommends
替代方案：若完全无法安装，用 ffmpeg 处理图片：
bash
复制
ffmpeg -i input.jpg output.png
FFmpeg（~300MB）
bash
复制
# 只装必要解码器
sudo apt install ffmpeg --no-install-recommends
替代方案：小视频可用 avconv（如系统残留），或降低质量在线处理（不推荐）。
Pandoc + TeX Live（> 1GB）
bash
复制
# 只装 pandoc，不装 texlive
sudo apt install pandoc

# PDF 输出改用轻量引擎
sudo apt install wkhtmltopdf   # ~50MB
# 或
sudo apt install weasyprint    # ~100MB
LibreOffice（> 500MB）
bash
复制
# 只装 writer 组件
sudo apt install libreoffice-writer --no-install-recommends
替代方案：pandoc 转 docx 不需要 LibreOffice，优先用 pandoc。
Tesseract + 中文包（~400MB）
bash
复制
# 先装英文版应急
sudo apt install tesseract-ocr

# 中文包单独下载（可选）
sudo apt install tesseract-ocr-chi-sim
替代方案：无 OCR 时，扫描版 PDF 直接交付图片，告知用户"需手动 OCR"。
2. 性能陷阱与绕过
9P 路径迁移超时（> 30s）
症状：sfp-in /mnt/c/Users/.../file.pdf 卡死
根因：Windows Defender / 杀毒软件实时扫描
绕过方案：
bash
复制
# 方案 A：rsync 替代 cp（跳过部分元数据）
rsync -av --no-perms --no-times "/mnt/c/..." "$SFP_HOT_ZONE/"

# 方案 B：先复制到 /tmp（tmpfs，极快），再 sfp-in
cp "/mnt/c/..." /tmp/ && sfp-in /tmp/file.pdf

# 方案 C：让用户拖入 WSL 文件系统后再处理
热区空间不足（< 2GB）
症状：sfp-in 或处理中报 "No space left on device"
绕过方案：
bash
复制
# 方案 A：临时切换热区到外置盘
SFP_HOT_ZONE=/mnt/d/sfp-hot sfp-in file.mp4

# 方案 B：流式处理（处理一个交付一个，不堆积）
for f in ~/bridge/desktop/*.jpg; do
    DIR=$(sfp-in "$f")
    convert "$DIR/$(basename "$f")" -quality 85 "$DIR/out.webp"
    sfp-out "$DIR/out.webp"
    sfp-clean "$DIR"
done

# 方案 C：降低质量减少体积
convert input.jpg -resize 50% -quality 70 output.jpg
ffmpeg -i input.mp4 -crf 28 -preset fast output.mp4
/tmp 是 tmpfs（内存盘，默认 50% 内存）
症状：大文件（> 2GB）处理时内存爆炸
绕过：默认热区是 $HOME/.sfp/hot（ext4），不要设置 SFP_HOT_ZONE=/tmp。如已设置：
bash
复制
SFP_HOT_ZONE=$HOME/.sfp/hot sfp-in large.mp4
3. 复杂格式处理（标准路由失败时）
PDF → Word（pandoc 不支持，需 LibreOffice）
bash
复制
DIR=$(sfp-in input.pdf)
cd "$DIR"

# 方案 A：LibreOffice 直接转
libreoffice --headless --convert-to docx input.pdf

# 方案 B：先转 txt，轻量交付
pdftotext input.pdf output.txt

sfp-out output.docx   # 或 output.txt
sfp-clean "$DIR"
扫描版 PDF → 可编辑文本
bash
复制
DIR=$(sfp-in scan.pdf)
cd "$DIR"

# 先转图片
pdftoppm -png scan.pdf page

# 逐页 OCR
for p in page-*.png; do
    tesseract "$p" "${p%.png}" -l chi_sim
done

# 合并文本
cat page-*.txt > output.txt
sfp-out output.txt
sfp-clean "$DIR"
加密 ZIP / 损坏压缩包
bash
复制
DIR=$(sfp-in archive.zip)
cd "$DIR"

# 测试是否加密
unzip -t archive.zip 2>&1 | grep -q "encrypted" && echo "加密文件，需要密码"

# 尝试修复
zip -FF archive.zip --out fixed.zip
unzip -o fixed.zip -d extracted/

sfp-clean "$DIR"
4. 批量优化策略
超大量文件（> 100 个）
问题：逐个 sfp-in 创建 100 个隔离目录，管理混乱
方案：统一热区 + 子目录隔离
bash
复制
BATCH_DIR="$HOME/.sfp/hot/batch_$(date +%s)"
mkdir -p "$BATCH_DIR"
for f in ~/bridge/desktop/*.jpg; do
    cp "$f" "$BATCH_DIR/"
done

# 批量处理
mogrify -format webp -quality 85 "$BATCH_DIR"/*.jpg

# 统一交付
for f in "$BATCH_DIR"/*.webp; do sfp-out "$f"; done
sfp-clean "$BATCH_DIR"
混合格式批量（jpg + png + gif 混在一个目录）
问题：sfp-batch 按扩展名分组可能遗漏
方案：用 file 命令识别真实格式
bash
复制
find "$BATCH_DIR" -type f | while read f; do
    mime=$(file --mime-type -b "$f")
    case "$mime" in
        image/jpeg) convert "$f" "${f%.jpg}.webp" ;;
        image/png)  convert "$f" "${f%.png}.webp" ;;
        image/gif)  convert "$f" "${f%.gif}.webp" ;;
    esac
done
5. 交付异常处理
NTFS 只读属性修复失败
症状：cmd.exe attrib -R 返回错误，Windows 下打不开
绕过方案：
bash
复制
# 方案 A：PowerShell 修权
powershell.exe -Command "Set-ItemProperty -Path 'C:\Users\...\file' -Name IsReadOnly -Value \$false"

# 方案 B：交付到 WSL 出口，让用户手动复制
cp output.file ~/.sfp/outbox/
chmod 644 ~/.sfp/outbox/output.file
echo "文件已保存到 WSL 目录，请手动复制到 Windows"
桌面路径探测失败（非 WSL 或 PowerShell 不可用）
症状：powershell.exe 不存在或返回空
绕过：
bash
复制
# 自动回退到 WSL 出口
sfp-out output.file

# 或用户指定
SFP_OUTBOX=/mnt/d/output sfp-out output.file
文件名含中文/特殊字符导致交付失败
症状：cp 成功但 Windows 下显示乱码
绕过：
bash
复制
safe_name=$(echo "$filename" | iconv -f UTF-8 -t ASCII//TRANSLIT | tr ' ' '_')
cp "$file" "$safe_name"
sfp-out "$safe_name"
sfp-in 自动转义特殊字符（关键发现）
症状：sfp-process 返回 PROCESS_FAIL，提示文件不存在，但文件明明已迁移
根因：sfp-in 会自动将文件名中的空格、括号等特殊字符转换为下划线
示例：新建文本文档 (1).txt → 新建文本文档_(1).txt
正确处理流程：
bash
复制
# 错误做法（直接使用原始文件名）
DIR=$(sfp-in "/mnt/c/.../新建文本文档 (1).txt")
cd "$DIR"
sfp-process cp "新建文本文档 (1).txt" "新建文本文档 (1).md"   # ❌ 失败！

# 正确做法（提取 sfp-in 返回的实际文件名）
MIGRATE_OUTPUT=$(sfp-in "/mnt/c/.../新建文本文档 (1).txt")
# 解析 MIGRATE_OK: dest="/path/新建文本文档_(1).txt"
MIGRATED_FILE=$(echo "$MIGRATE_OUTPUT" | grep -oP 'dest="\K[^"]+' | xargs basename)
# MIGRATED_FILE = "新建文本文档_(1).txt" （空格和括号已转义）
cd "$DIR"
sfp-process cp "$MIGRATED_FILE" "${MIGRATED_FILE%.txt}.md"   # ✓ 成功
批量处理特殊字符文件的完整方案：
bash
复制
for f in ~/bridge/desktop/*.txt; do
    # 阶段 1：迁移并提取实际文件名
    result=$(sfp-in "$f")
    [ ! "$result" =~ MIGRATE_OK ] && continue
    
    # 提取热区路径和实际文件名（已转义）
    hot_path=$(echo "$result" | grep -oP 'dest="\K[^"]+')
    hot_dir=$(dirname "$hot_path")
    migrated_name=$(basename "$hot_path")
    
    # 阶段 2：使用转义后的文件名处理
    md_name="${migrated_name%.txt}.md"
    (cd "$hot_dir" && sfp-process cp "$migrated_name" "$md_name")
    
    # 阶段 3：交付
    sfp-out "$hot_dir/$md_name"
    
    # 阶段 4：清理
    sfp-clean "$hot_dir"
done
6. 特定格式陈痛与解决
HTML → PDF 转换失败（缺少 SVG 和 LaTeX 引擎）
症状：pandoc 报错 "rsvg-convert not found" 或 "pdflatex not found"
根因：HTML 中包含 SVG 图片时需要渲染引擎
完整安装（推荐）：
bash
复制
sudo apt install pandoc librsvg2-bin texlive-latex-base
轻量替代方案（省 1GB）：
bash
复制
sudo apt install pandoc wkhtmltopdf   # ~50MB，但对复杂 HTML 支持较差
PDF 扫描版检测阈值问题
症状：sfp-convert 返回 CONVERT_OK 但输出文件为空（1 字节）
根因：sfp-convert 使用 pdftotext -l 1 | wc -c 检测，1 字符被判为"文字版"
解决：检查输出文件大小，为空时手动走 OCR 流程
bash
复制
# sfp-convert 后验证
if [ $(stat -c%s "$output.txt") -lt 10 ]; then
    echo "PDF 可能为扫描版，需要 OCR"
    # 走原子模式 tesseract 处理
fi
注意：sfp-convert 内置 OCR 支持（当 CHAR_COUNT=0 时自动切换到 ocr-pdf），需要 tesseract 工具箱标记 CAN_OCR=1
7. 质量门控绕过（紧急交付）
文件大小为 0 但必须交付（调试/日志场景）
bash
复制
# 强制交付（跳过质量门控）
SFP_BYPASS_GATE=1 sfp-out debug.log
PDF 页数为 0 但实际有效（某些生成器不写入页数元数据）
bash
复制
# 用文件大小宕底
[ $(stat -c%s output.pdf) -gt 1024 ] && SFP_BYPASS_GATE=1 sfp-out output.pdf