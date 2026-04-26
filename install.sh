#!/bin/bash

# ============================================
# Safe File Processor - 安装与环境检查（三合一）
# 职责：
#   1. 探测 CLI 工具 → 生成 ~/.config/sfp/toolbox
#   2. 检查环境路径 → 输出状态报告
#   3. 零硬编码：所有路径通过环境变量覆盖
# ============================================

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/sfp"
TOOLBOX_FILE="$CONFIG_DIR/toolbox"
mkdir -p "$CONFIG_DIR"

# --- 颜色 ---
G='\033[0;32m'; R='\033[0;31m'; Y='\033[0;33m'; NC='\033[0m'
pass()  { echo -e "${G}✓${NC} $1"; }
fail()  { echo -e "${R}✗${NC} $1"; }
warn()  { echo -e "${Y}⚠${NC} $1"; }

# --- 计数器（用 let 避免 (( )) 的 exit code 陷阱）---
OK=0; WARN=0; ERR=0
inc_ok()   { let "OK+=1";   }
inc_warn() { let "WARN+=1"; }
inc_err()  { let "ERR+=1";  }

# ============================================
# Part 1: 工具探测 → toolbox
# ============================================

check_tool() {
    local var="$1" cmd="$2"
    if command -v "$cmd" >/dev/null 2>&1; then
        echo "${var}=1" >> "$TOOLBOX_FILE"
        echo "1"
    else
        echo "${var}=0" >> "$TOOLBOX_FILE"
        echo "0"
    fi
}

echo "# Safe File Processor Toolbox - $(date)" > "$TOOLBOX_FILE"

HAS_IMAGEMAGICK=$(check_tool "HAS_IMAGEMAGICK" "convert")
HAS_FFMPEG=$(check_tool "HAS_FFMPEG" "ffmpeg")
HAS_PANDOC=$(check_tool "HAS_PANDOC" "pandoc")
HAS_PDFTOTEXT=$(check_tool "HAS_PDFTOTEXT" "pdftotext")
HAS_TESSERACT=$(check_tool "HAS_TESSERACT" "tesseract")
HAS_7ZIP=$(check_tool "HAS_7ZIP" "7z")
HAS_JQ=$(check_tool "HAS_JQ" "jq")

# 派生能力
CAN_PDF_OUTPUT="0"
if [ "$HAS_PANDOC" = "1" ] && { command -v xelatex >/dev/null 2>&1 || command -v wkhtmltopdf >/dev/null 2>&1; }; then
    CAN_PDF_OUTPUT="1"
fi
echo "CAN_PDF_OUTPUT=${CAN_PDF_OUTPUT}" >> "$TOOLBOX_FILE"

CAN_OCR="0"
if [ "$HAS_TESSERACT" = "1" ] && tesseract --list-langs 2>/dev/null | grep -q "chi_sim"; then
    CAN_OCR="1"
fi
echo "CAN_OCR=${CAN_OCR}" >> "$TOOLBOX_FILE"

echo "CAN_PDF_TEXT=${HAS_PDFTOTEXT}" >> "$TOOLBOX_FILE"

# ============================================
# Part 2: 环境检查报告
# ============================================

echo ""
echo "=========================================="
echo "  Safe File Processor 环境检查报告"
echo "=========================================="
echo ""

# --- 2.1 热区 ---
HOT_ZONE="${SFP_HOT_ZONE:-$HOME/.sfp/hot}"
echo "【热区】${HOT_ZONE}"
if [ -d "$HOT_ZONE" ]; then
    pass "目录存在"; inc_ok
    if touch "$HOT_ZONE/.write_test" 2>/dev/null; then
        rm -f "$HOT_ZONE/.write_test"
        pass "可写"; inc_ok
    else
        fail "不可写"; inc_err
    fi
    AVAIL=$(df -m "$HOT_ZONE" 2>/dev/null | awk 'NR==2 {print $4}')
    if [ -n "$AVAIL" ]; then
        if [ "$AVAIL" -gt 10240 ]; then
            pass "空间充足 (${AVAIL}MB)"; inc_ok
        elif [ "$AVAIL" -gt 2048 ]; then
            warn "空间一般 (${AVAIL}MB)"; inc_warn
        else
            fail "空间不足 (${AVAIL}MB)"; inc_err
        fi
    fi
else
    warn "目录不存在（首次使用时自动创建）"; inc_warn
fi
echo ""

# --- 2.2 出口 ---
OUTBOX="${SFP_OUTBOX:-$HOME/.sfp/outbox}"
echo "【出口】${OUTBOX}"
if [ -d "$OUTBOX" ]; then
    pass "目录存在"; inc_ok
    if touch "$OUTBOX/.write_test" 2>/dev/null; then
        rm -f "$OUTBOX/.write_test"
        pass "可写"; inc_ok
    else
        fail "不可写"; inc_err
    fi
else
    warn "目录不存在（首次交付时自动创建）"; inc_warn
fi
echo ""

# --- 2.3 工具箱摘要 ---
echo "【工具箱】${TOOLBOX_FILE}"
pass "已生成"; inc_ok
echo "  基础工具:"
grep '^HAS_' "$TOOLBOX_FILE" | sed 's/^/    /'
echo "  派生能力:"
grep '^CAN_' "$TOOLBOX_FILE" | sed 's/^/    /'
echo ""

# --- 2.4 WSL2 探测 ---
if grep -qi microsoft /proc/version 2>/dev/null; then
    echo "【WSL2 探测】"
    if command -v cmd.exe >/dev/null 2>&1; then
        pass "cmd.exe 可用"; inc_ok
    else
        warn "cmd.exe 不可用（NTFS 修权失效）"; inc_warn
    fi
    if command -v powershell.exe >/dev/null 2>&1; then
        pass "powershell.exe 可用"; inc_ok
    else
        warn "powershell.exe 不可用（桌面探测回退到 WSL 出口）"; inc_warn
    fi
    echo ""
fi

# ============================================
# Part 3: 总结
# ============================================

echo "=========================================="
echo "  通过 ${OK}  警告 ${WARN}  失败 ${ERR}"
echo "=========================================="

if [ $ERR -eq 0 ]; then
    pass "环境就绪"
else
    fail "请按上述建议修复"
fi

echo ""
echo "Toolbox:      $TOOLBOX_FILE"
echo "热区默认:     $HOT_ZONE"
echo "出口默认:     $OUTBOX"
echo ""
echo "覆盖方式:"
echo "  export SFP_HOT_ZONE=/your/hot/path"
echo "  export SFP_OUTBOX=/your/out/path"