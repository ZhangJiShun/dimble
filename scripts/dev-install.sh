#!/bin/bash
# 本地开发一键安装：编译 Release → 用固定本地证书签名 → 退出正在运行的 Dimble →
# 备份并替换 /Applications/Dimble.app → 重新打开。
# 目的：每次改完功能装一下就能看，不再碰辅助功能授权（授权认的是签名身份，身份不变就一直有效）。
#
# 用法:
#   scripts/dev-install.sh               编译、签名、安装并打开
#   scripts/dev-install.sh --no-launch   装好但不自动打开
#   scripts/dev-install.sh --build-only  只编译并签名到构建目录，不动已安装的版本（用来试跑）
#   scripts/dev-install.sh --rollback    回到上一次被替换掉的那个版本
#
# 环境变量（一般不用设）:
#   DIMBLE_INSTALL_DIR         装到哪里，默认 /Applications
#   DIMBLE_BACKUP_DIR          旧版本备份目录，默认 ~/.agents/backups/apps
#   DIMBLE_DEV_BUILD_DIR       构建目录，默认 ~/Library/Caches/dimble-dev-build（保留编译缓存）
#   DIMBLE_CODESIGN_IDENTITY   签名证书名，默认「Tokei Local Dev」（见 AGENTS.md「签名与授权」）
#   DIMBLE_XCODEGEN            xcodegen 可执行文件；默认用 PATH 里的 xcodegen
#
# 找不到固定证书时直接报错退出，不会退回 ad-hoc 签名：ad-hoc 每次编译身份都不同，
# 会让系统把辅助功能、录屏的授权当成新 App，等于每次都要重新授权。
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL_DIR="${DIMBLE_INSTALL_DIR:-/Applications}"
BACKUP_DIR="${DIMBLE_BACKUP_DIR:-$HOME/.agents/backups/apps}"
BUILD_DIR="${DIMBLE_DEV_BUILD_DIR:-$HOME/Library/Caches/dimble-dev-build}"
IDENTITY="${DIMBLE_CODESIGN_IDENTITY:-Tokei Local Dev}"
INSTALLED="$INSTALL_DIR/Dimble.app"
PROCESS_PATH="$INSTALLED/Contents/MacOS/Dimble"
LAUNCH=1
BUILD_ONLY=0
ROLLBACK=0

for arg in "$@"; do
    case "$arg" in
        --no-launch) LAUNCH=0 ;;
        --build-only) BUILD_ONLY=1 ;;
        --rollback) ROLLBACK=1 ;;
        -h|--help) sed -n '2,21p' "$0"; exit 0 ;;
        *) echo "未知参数: $arg（--help 看用法）" >&2; exit 1 ;;
    esac
done

version_of() {
    /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$1/Contents/Info.plist" 2>/dev/null || echo "unknown"
}

# 先温和地请它退出（退出流程会把菜单栏还原），10 秒后还在就强制结束。
quit_installed() {
    pgrep -f "$PROCESS_PATH" >/dev/null || return 0
    echo "==> 退出正在运行的 Dimble"
    osascript -e 'tell application "Dimble" to quit' >/dev/null 2>&1 || true
    for _ in $(seq 1 20); do
        sleep 0.5
        pgrep -f "$PROCESS_PATH" >/dev/null || return 0
    done
    pkill -TERM -f "$PROCESS_PATH" 2>/dev/null || true
    sleep 1
    pkill -KILL -f "$PROCESS_PATH" 2>/dev/null || true
    sleep 0.5
}

launch_app() {
    [ "$LAUNCH" -eq 1 ] || return 0
    echo "==> 打开 Dimble"
    open "$INSTALLED"
}

# ---------- 回退 ----------
if [ "$ROLLBACK" -eq 1 ]; then
    # 按文件名末尾的时间戳（YYYYMMDD-HHMMSS）挑最新的：不看修改时间（ditto 会保留原时间），
    # 也排除「回退时被换下来的那份」，否则连续回退会在两个版本之间来回切。
    latest="$(for f in "$BACKUP_DIR"/Dimble-*.app; do
            [ -d "$f" ] || continue
            case "$f" in */Dimble-replaced-by-rollback-*) continue ;; esac
            stamp="$(basename "$f" | sed -nE 's/.*-([0-9]{8}-[0-9]{6})\.app$/\1/p')"
            [ -n "$stamp" ] && printf '%s\t%s\n' "$stamp" "$f"
        done | sort | tail -n 1 | cut -f2- || true)"
    [ -n "$latest" ] || { echo "没有可回退的备份（$BACKUP_DIR 里没有 Dimble-*.app）" >&2; exit 1; }
    quit_installed
    if [ -d "$INSTALLED" ]; then
        mkdir -p "$BACKUP_DIR"
        mv "$INSTALLED" "$BACKUP_DIR/Dimble-replaced-by-rollback-$(version_of "$INSTALLED")-$(date +%Y%m%d-%H%M%S).app"
    fi
    ditto "$latest" "$INSTALLED"
    echo "==> 已回退到 $(version_of "$INSTALLED")（来自 $latest，备份原样保留）"
    launch_app
    exit 0
fi

# ---------- 签名证书 ----------
# 自签名证书在 find-identity 里显示 CSSMERR_TP_NOT_TRUSTED，这是正常的，不影响本地签名；
# 所以不能加 -v（-v 只列受信任的，会把它漏掉）。
if ! security find-identity -p codesigning 2>/dev/null | grep -q "\"$IDENTITY\""; then
    cat >&2 <<E
错误：钥匙串里没有签名证书「$IDENTITY」。
不退回 ad-hoc 签名：那样每次安装都要重新授权辅助功能和录屏。
证书是为 Tokei 项目建的自签名代码签名证书，重建办法见 AGENTS.md「签名与授权」。
E
    exit 1
fi

# ---------- 工程文件 ----------
# Pelmet.xcodeproj 由 project.yml 生成、不进 git：上游新增源文件后必须重新生成，否则编译找不到新文件。
XCODEGEN="${DIMBLE_XCODEGEN:-$(command -v xcodegen || true)}"
if [ -n "$XCODEGEN" ]; then
    echo "==> 生成工程文件"
    (cd "$REPO" && "$XCODEGEN" generate >/dev/null)
elif [ ! -d "$REPO/Pelmet.xcodeproj" ]; then
    echo "错误：没有 Pelmet.xcodeproj，也找不到 xcodegen（brew install xcodegen，或设 DIMBLE_XCODEGEN）" >&2
    exit 1
else
    echo "!! 没找到 xcodegen，沿用现有 Pelmet.xcodeproj；如果刚合并过上游，可能缺新文件。" >&2
fi

# ---------- 编译 ----------
echo "==> 编译 Release（构建目录: $BUILD_DIR）"
mkdir -p "$BUILD_DIR"
NEW_APP="$BUILD_DIR/Build/Products/Release/Dimble.app"
BUILD_LOG="$BUILD_DIR/last-build.log"
# 构建目录保留了上一次的产物：编译前先删掉，否则编译失败时旧版会被当成新版签名、安装。
rm -rf "$NEW_APP"
build_status=0
(cd "$REPO" && xcodebuild -project Pelmet.xcodeproj -scheme Pelmet -configuration Release \
    -destination 'platform=macOS' -derivedDataPath "$BUILD_DIR" \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= build) >"$BUILD_LOG" 2>&1 || build_status=$?
grep -E "error:|BUILD " "$BUILD_LOG" || true
[ "$build_status" -eq 0 ] || { echo "编译失败（xcodebuild 退出码 $build_status），完整日志: $BUILD_LOG；没有动已安装的版本" >&2; exit 1; }
[ -d "$NEW_APP" ] || { echo "没有生成 $NEW_APP，编译失败；完整日志: $BUILD_LOG" >&2; exit 1; }

# ---------- 签名（由内向外；不用 --deep，每个组件按自己的标识生成签名要求）----------
sign_one() {
    local out
    if ! out="$(codesign --force -s "$IDENTITY" "$1" 2>&1)"; then
        echo "错误：签名失败：$1" >&2
        echo "$out" >&2
        exit 1
    fi
}
sign_all() {
    local app="$1" sparkle
    sparkle="$app/Contents/Frameworks/Sparkle.framework"
    if [ -d "$sparkle" ]; then
        local nested
        while IFS= read -r nested; do
            sign_one "$nested"
        done < <(find "$sparkle/Versions" -mindepth 2 -maxdepth 3 \( -name '*.xpc' -o -name '*.app' -o -name 'Autoupdate' \) | sort)
        sign_one "$sparkle"
    fi
    local helper
    for helper in "$app"/Contents/Helpers/*.app; do
        [ -d "$helper" ] && sign_one "$helper"
    done
    sign_one "$app"
    codesign --verify --deep --strict "$app"
}
echo "==> 签名（$IDENTITY）"
sign_all "$NEW_APP"
echo "    $(codesign -d -r- "$NEW_APP" 2>&1 | grep designated)"

if [ "$BUILD_ONLY" -eq 1 ]; then
    echo "==> 只编译：$NEW_APP（没有动已安装的版本）"
    exit 0
fi

# ---------- 安装（旧版本先备份，备份验证通过才替换）----------
quit_installed
if [ -d "$INSTALLED" ]; then
    mkdir -p "$BACKUP_DIR"
    backup="$BACKUP_DIR/Dimble-$(version_of "$INSTALLED")-$(date +%Y%m%d-%H%M%S).app"
    installed_signed=0
    codesign --verify --deep "$INSTALLED" 2>/dev/null && installed_signed=1
    ditto "$INSTALLED" "$backup"
    if ! codesign --verify --deep "$backup" 2>/dev/null; then
        if [ "$installed_signed" -eq 1 ]; then
            # 原版签名是好的而备份不好：备份有问题，回退会指向一个坏副本，所以不替换。
            echo "!! 备份的签名校验未通过，而已安装的版本签名正常：备份可能损坏，没有替换。已安装的版本原样保留，备份在 $backup" >&2
            exit 1
        fi
        echo "!! 已安装的版本本来就没有有效签名，备份同样校验不过，继续替换。备份：$backup" >&2
    fi
    echo "==> 旧版本已备份到 $backup"
    rm -rf "$INSTALLED"
fi
mkdir -p "$INSTALL_DIR"
ditto "$NEW_APP" "$INSTALLED"
xattr -cr "$INSTALLED" 2>/dev/null || true
codesign --verify --deep --strict "$INSTALLED"
echo "==> 已安装 Dimble $(version_of "$INSTALLED") 到 $INSTALLED"
echo "    回退: scripts/dev-install.sh --rollback"
launch_app
