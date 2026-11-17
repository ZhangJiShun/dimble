#!/bin/bash
# 本地开发一键安装：编译 Release → 用固定本地证书签名 → 退出正在运行的 Dimble →
# 备份并替换 /Applications/Dimble.app → 重新打开。
# 目的：每次改完功能装一下就能看，不再碰辅助功能授权（授权认的是签名身份，身份不变就一直有效）。
#
# 用法:
#   scripts/dev-install.sh                     编译、签名、安装并打开
#   scripts/dev-install.sh --no-launch         装好但不自动打开
#   scripts/dev-install.sh --build-only        只编译并签名到构建目录，不动已安装的版本（用来试跑）
#   scripts/dev-install.sh --allow-downgrade   允许装比已安装版本旧的版本（默认拦截，防止在旧分支上误覆盖）
#   scripts/dev-install.sh --list-backups      只列出所有备份（版本、build 号、时间、路径），不改任何东西
#   scripts/dev-install.sh --rollback          列出备份，并回到最新的一份
#   scripts/dev-install.sh --rollback 0.4.0    回到版本 0.4.0 里时间最新的一份备份
#   scripts/dev-install.sh --rollback <路径>    回到指定的备份 .app
#
# 环境变量（一般不用设）:
#   DIMBLE_INSTALL_DIR         装到哪里，默认 /Applications
#   DIMBLE_INSTALLED           已安装的 App 完整路径，默认 $DIMBLE_INSTALL_DIR/Dimble.app（测试脚本用）
#   DIMBLE_BACKUP_DIR          旧版本备份目录，默认 ~/.agents/backups/apps
#   DIMBLE_NO_LAUNCH           设为 1 则完全不退出、不启动 Dimble 进程（测试脚本用）
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
INSTALLED="${DIMBLE_INSTALLED:-$INSTALL_DIR/Dimble.app}"
PROCESS_PATH="$INSTALLED/Contents/MacOS/Dimble"
NO_PROCESS="${DIMBLE_NO_LAUNCH:-0}"
LAUNCH=1
BUILD_ONLY=0
ROLLBACK=0
LIST_ONLY=0
ALLOW_DOWNGRADE=0
ROLLBACK_TARGET=""

plist_value() {   # plist_value <App> <键>
    /usr/libexec/PlistBuddy -c "Print :$2" "$1/Contents/Info.plist" 2>/dev/null || echo "unknown"
}
version_of() { plist_value "$1" CFBundleShortVersionString; }
build_of() { plist_value "$1" CFBundleVersion; }

# 先温和地请它退出（退出流程会把菜单栏还原），10 秒后还在就强制结束。
quit_installed() {
    [ "$NO_PROCESS" = 1 ] && return 0
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
    [ "$NO_PROCESS" = 1 ] && return 0
    echo "==> 打开 Dimble"
    open "$INSTALLED"
}

# 版本号按数字逐段比较（0.3.5 < 0.4.0 < 0.10.0），每段只取开头的数字；输出 -1 / 0 / 1（第一个 比 第二个 旧/相同/新）。
vercmp() {
    local IFS=. i x y
    local -a a b
    read -r -a a <<<"$1"
    read -r -a b <<<"$2"
    local n=${#a[@]}
    [ ${#b[@]} -gt "$n" ] && n=${#b[@]}
    for ((i = 0; i < n; i++)); do
        x="${a[i]:-0}"; y="${b[i]:-0}"
        x="${x%%[!0-9]*}"; y="${y%%[!0-9]*}"
        x=$((10#${x:-0})); y=$((10#${y:-0}))
        if [ "$x" -lt "$y" ]; then echo -1; return 0; fi
        if [ "$x" -gt "$y" ]; then echo 1; return 0; fi
    done
    echo 0
}

# 新 App 是否比已安装的旧：先比 CFBundleShortVersionString，相同再比 CFBundleVersion。输出 -1 / 0 / 1。
compare_apps() {   # compare_apps <新App> <已装App>
    local c
    c="$(vercmp "$(version_of "$1")" "$(version_of "$2")")"
    [ "$c" = 0 ] && c="$(vercmp "$(build_of "$1")" "$(build_of "$2")")"
    echo "$c"
}

check_downgrade() {   # check_downgrade <新App> <已装App>；旧于已装且没 --allow-downgrade 就返回 1
    [ -d "$2" ] || return 0
    [ "$(compare_apps "$1" "$2")" = -1 ] || return 0
    [ "$ALLOW_DOWNGRADE" -eq 1 ] && { echo "!! 新编译的版本比已安装的旧，但给了 --allow-downgrade，继续。" >&2; return 0; }
    {
        echo "错误：新编译的版本比已安装的旧，拒绝替换（防止在旧分支上误覆盖新版）。"
        echo "    新编译: $(version_of "$1") (build $(build_of "$1"))"
        echo "    已安装: $(version_of "$2") (build $(build_of "$2"))"
        echo "    当前目录: $REPO"
        echo "    当前分支: $(git -C "$REPO" rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
        echo "    确实要装旧版就加 --allow-downgrade；已安装的版本没有动。"
    } >&2
    return 1
}

# 列出可回退的备份，每行：时间戳<TAB>版本<TAB>build<TAB>路径<TAB>标记。按时间戳从旧到新。
# 时间戳取文件名末尾的 YYYYMMDD-HHMMSS：不看修改时间（ditto 会保留原时间）。
# 文件名带 replaced-by-rollback 的是「回退时被换下来的那份」，标记为 R，默认不当作回退目标，
# 否则连续回退会在两个版本之间来回切。
backup_lines() {
    local f stamp tag
    for f in "$BACKUP_DIR"/Dimble-*.app; do
        [ -d "$f" ] || continue
        stamp="$(basename "$f" | sed -nE 's/.*-([0-9]{8}-[0-9]{6})\.app$/\1/p')"
        [ -n "$stamp" ] || continue
        tag="-"
        case "$f" in
            (*/Dimble-replaced-by-rollback-*) tag="R" ;;
        esac
        printf '%s\t%s\t%s\t%s\t%s\n' "$stamp" "$(version_of "$f")" "$(build_of "$f")" "$f" "$tag"
    done | sort
}

print_backups() {
    local lines
    lines="$(backup_lines)"
    if [ -z "$lines" ]; then echo "（$BACKUP_DIR 里没有备份）"; return 0; fi
    echo "备份清单（$BACKUP_DIR，旧 → 新）:"
    printf '%s\n' "$lines" | while IFS=$'\t' read -r stamp ver bld path tag; do
        printf '  %s  版本 %s  build %s  %s%s\n' "$stamp" "$ver" "$bld" "$path" "$([ "$tag" = R ] && echo '  [回退时换下的，默认不选]')"
    done
}

# 选回退目标：空 = 最新一份；含 / 或以 .app 结尾 = 路径；否则 = 版本号。
pick_rollback() {
    local target="$1" lines
    case "$target" in
        ("")
            lines="$(backup_lines | awk -F'\t' '$5 != "R"')"
            ;;
        (*/* | *.app)
            if [ -d "$target" ]; then printf '%s\n' "$target"; return 0; fi
            return 1
            ;;
        (*)
            lines="$(backup_lines | awk -F'\t' -v v="$target" '$5 != "R" && $2 == v')"
            ;;
    esac
    [ -n "$lines" ] || return 1
    printf '%s\n' "$lines" | tail -n 1 | cut -f4
}

# 测试时 DIMBLE_SOURCE_ONLY=1 只加载上面的函数
if [ "${DIMBLE_SOURCE_ONLY:-0}" = 1 ]; then return 0 2>/dev/null || exit 0; fi

while [ $# -gt 0 ]; do
    case "$1" in
        --no-launch) LAUNCH=0 ;;
        --build-only) BUILD_ONLY=1 ;;
        --allow-downgrade) ALLOW_DOWNGRADE=1 ;;
        --list-backups) LIST_ONLY=1 ;;
        --rollback)
            ROLLBACK=1
            # 后面跟的不是以 -- 开头的参数，就是要回退到的版本号或路径
            if [ $# -gt 1 ] && [ "${2#--}" = "$2" ]; then ROLLBACK_TARGET="$2"; shift; fi
            ;;
        -h|--help) sed -n '2,/^set -euo/p' "$0" | sed '$d'; exit 0 ;;
        *) echo "未知参数: $1（--help 看用法）" >&2; exit 1 ;;
    esac
    shift
done

if [ "$LIST_ONLY" -eq 1 ]; then print_backups; exit 0; fi

# ---------- 回退 ----------
if [ "$ROLLBACK" -eq 1 ]; then
    print_backups
    latest="$(pick_rollback "$ROLLBACK_TARGET")" || latest=""
    if [ -z "$latest" ]; then
        if [ -n "$ROLLBACK_TARGET" ]; then
            echo "错误：找不到「$ROLLBACK_TARGET」对应的备份（不是版本号，也不是存在的 .app 路径）；已安装的版本没有动。" >&2
        else
            echo "错误：没有可回退的备份（$BACKUP_DIR 里没有 Dimble-*.app）" >&2
        fi
        exit 1
    fi
    echo "==> 回退目标: $latest（版本 $(version_of "$latest")，build $(build_of "$latest")）"
    quit_installed
    if [ -d "$INSTALLED" ]; then
        mkdir -p "$BACKUP_DIR"
        mv "$INSTALLED" "$BACKUP_DIR/Dimble-replaced-by-rollback-$(version_of "$INSTALLED")-$(date +%Y%m%d-%H%M%S).app"
    fi
    mkdir -p "$(dirname "$INSTALLED")"
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

# ---------- 防止装旧版 ----------
check_downgrade "$NEW_APP" "$INSTALLED" || exit 1

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
mkdir -p "$(dirname "$INSTALLED")"
ditto "$NEW_APP" "$INSTALLED"
xattr -cr "$INSTALLED" 2>/dev/null || true
codesign --verify --deep --strict "$INSTALLED"
echo "==> 已安装 Dimble $(version_of "$INSTALLED") 到 $INSTALLED"
echo "    回退: scripts/dev-install.sh --rollback"
launch_app
