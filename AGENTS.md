# Dimble（目录名 Pelmet）项目规则

全局规则（`~/.agents/GLOBAL_RULES.md`）优先；本文件只补充这个项目特有的情况和约定，不豁免全局的「必须先问」。
开工前先读这份文件，再按需读 `README.md`、`docs/ARCHITECTURE-REVIEW.md`、`docs/RELEASE.md`。

> `CLAUDE.md` 是指向本文件的软链接。**只改 `AGENTS.md`**，不要把软链接换成复制出来的文件。

---

## 1. 项目是什么

macOS 菜单栏图标管理工具（曾用名 Pelmet、Pliss，现名 Dimble）：把菜单栏图标收进「隐藏区」，点箭头或悬停时展开，也能用面板、单行显示。
Swift，macOS 27 SDK，GPLv3。**这是 `fif7y/dimble`（作者 Gabriel Faucon）的 fork**，Jason 个人使用，在上游基础上有自己改的界面样式（见 §3）。

目录与名字对照（历史原因，别被绕晕）：目录、Xcode 工程、scheme、源码目录都叫 `Pelmet`；App 产品名是 `Dimble`；Bundle ID 仍是 `app.fif7y.Pelmet`；辅助小程序叫 `DimbleItems-Hidden` 和 `DimbleItems-AlwaysHidden`（源码在 `PelmetItems/`）。

### 代码地图

| 位置 | 作用 |
|---|---|
| `Packages/PelmetCore/` | 纯逻辑，有大量单元测试：设置存储、分区模型、面板网格与尺寸（`PanelGrid`/`PanelOptions`）、悬停状态机（`HoverReveal`）、面板定位（`PanelHorizontalPlacement`）、面板冻结（`PanelPresentationSession`）、重新隐藏状态机 |
| `Packages/PelmetEngine/` | 菜单栏「收敛」引擎：读取图标（辅助功能 AX）、移动图标（合成鼠标拖拽）、探针命令行 `pelmet-probe` |
| `Pelmet/App/` | `AppState`（4000+ 行的总调度）、`TransitionCoordinator`（显示/隐藏转场）、`ApplyPass`（应用布局）、`ShowRules`、`BundleRelocation` |
| `Pelmet/Panel/` `Pelmet/Panels/` | 面板：`PanelPresenter`（打开、定位、刷新）、`PanelView`（画格子）、`ItemPictures`、`GlassPanel`（毛玻璃窗口） |
| `Pelmet/Events/` | 鼠标与点击监听：`MenuBarBandMonitor`（悬停）、`PointerMoveTap`、`ClockClickRelay`、`HotkeyManager` |
| `Pelmet/StatusItem/` | 箭头图标、分隔符、遮罩 `ConcealGhostOverlay`、辅助进程管理 `HelperHosts` |
| `Pelmet/Settings/` | 设置窗口各页；`PanelPane` 是「面板」页 |
| `PelmetItems/` | 辅助小程序（承载分隔符和额外图标的独立进程） |
| `scripts/` | `dev-install.sh`（本地一键安装）、`release.sh`（正式发布）、`gen-xcstrings.py`（翻译） |
| `docs/` | 上游的设计与审查文档；`docs/panel-redesign-mockups.html` 是面板样式的效果图 |

---

## 2. 日常命令

```bash
swift test --package-path Packages/PelmetCore      # 核心逻辑测试（秒级）
swift test --package-path Packages/PelmetEngine
scripts/dev-install.sh                              # 编译、签名、备份旧版、替换 /Applications/Dimble.app、重启
scripts/dev-install.sh --build-only                 # 只编译签名，不动已安装的版本（试跑用）
scripts/dev-install.sh --rollback                   # 换回上一个版本
```

- **工程文件 `Pelmet.xcodeproj` 由 `project.yml` 生成、不进 git。** 合并上游或新增源文件后必须重新生成（`xcodegen generate`），否则编译报「找不到某个类型」。`dev-install.sh` 会自动执行。
- 本机没有装官方 xcodegen 时，曾用过 Codex 留在 `/private/tmp/codex-dimble-xcodegen-*/xcodegen/bin/xcodegen` 的副本（经用户同意）；长期应 `brew install xcodegen`（全局安装要先问）。用环境变量 `DIMBLE_XCODEGEN` 指定。
- 命令行编译（不签名，只验证能编过）：`xcodebuild -project Pelmet.xcodeproj -scheme Pelmet -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= build`。直接 `build` 会因缺 Mac Development 证书失败，这不是代码问题。
- App 工程自己的测试在 `PelmetTests/`，用同样参数把 `build` 换成 `test`。
- 日志：`~/Library/Logs/Dimble/`（最新一个文件）。看授权状态搜 `ax:`，看转场搜 `converge`、`cover`。
- 没有真机截图验证能力时，**如实说「没有实机看过」**，不要写「已验证界面」。

---

## 3. 本地改动（相对上游）与同步上游的底线

**用户的底线：同步上游时，不能改动本地已经定好的 UI 样式。** 同步时这些必须原样保留：

1. **面板样式三选一**（设置 › 面板 › 样式）：图块（原样）、紧凑（格子 38pt、图标 27pt）、列表（图标加名称并排，默认 2 列，无常驻底）。数据在 `PanelOptions.style`，尺寸在 `PanelMetrics.tight/.list`，绘制在 `PanelView` 的 `PanelTileLabel` 与 `Well`，右键菜单也有对应项。每种样式单独记自己的列数。单行（row）沿用上游已有的布局。
2. **面板在图标正下方水平居中**，放不下时被屏幕边缘推进来（`PanelHorizontalPlacement`，`PanelPresenter.place`）。居中时拖左边缘调列数按中线算宽度，被边缘推着时按右边缘算。设置页预览同步居中。
3. **面板打开期间内容冻结**（`PanelPresentationSession`）：打开那一刻的格子集合与图片定住，不乱跳。占位图允许升级成真图一次，确认消失的图标（`settleNoIcon`）会从冻结的快照里移除。
4. **悬停展开**（`HoverReveal`、设置里的悬停范围）、**面板用 App 原生图标**（`PanelItemImageSource`）。
5. 一批稳定性修复（计时器上限、辅助进程重启、引导窗口缓存、AX 超时、快捷键冲突重试、开机启动开关、退出前保存设置、事件监听失效重建、`release.sh` 的两个坑）。

**同步上游的做法：**
- 远程：`origin` 是用户自己的 fork（`ZhangJiShun/dimble`），`upstream` 是 `fif7y/dimble`。
- **在新分支上做**（如 `sync-upstream-0.3.3`），用 `git merge --no-commit <上游标签>` 合并，逐个解决冲突，**不动 `main`**。冲突多发在 `PanelPresenter.swift`、`PanelPane.swift`、`SettingsStore.swift`、`SettingsIndex.swift`、`Localizable.xcstrings`。
- 合并后：重新生成工程文件 → 重新生成翻译（`python3 scripts/gen-xcstrings.py`）→ 两个包的测试 → App 编译 → App 测试 → 逐条核对上面第 1~4 点的代码还在（可 grep `options.style`、`PanelHorizontalPlacement`、`presentation.stabilize`）。
- 合并回 `main`、推送，都要用户明确同意。

---

## 4. 签名与授权（最容易反复出问题的地方）

**铁律：任何要装到 `/Applications` 的 Dimble，必须用本机钥匙串里的自签名证书「Tokei Local Dev」签名，禁止 ad-hoc 签名。**

- 原因：macOS 把辅助功能、录屏的授权绑在 App 的**签名身份**上。固定证书加固定标识，签名要求恒为 `identifier "app.fif7y.Pelmet" and certificate leaf = H"0a713c4b…"`，换新版系统一直认。ad-hoc 每次编译身份都变，每装一次就丢一次授权，这就是「每次改功能都要重新授权」的根源。
- 这张证书是为 Tokei 项目建的，同一台 Mac 上 Codex 也用它，所以 Codex 装的版本不用重新授权。重建办法见 `~/Documents/项目/Tokei/AGENTS.md` 的「本地签名证书」。
- **查证书时不要加 `-v`**：`security find-identity -p codesigning`（不加 `-v`）。自签名证书会显示 `CSSMERR_TP_NOT_TRUSTED`，这是正常的，加了 `-v` 反而看不到，会误以为证书丢了。
- 别用钥匙串里其他项目的证书（如 `MoleGUI Dev`）给 Dimble 签名。
- 嵌套组件（Sparkle 的各个 xpc/app、`Autoupdate`、两个辅助小程序）要**由内向外逐个签**，不要用 `--deep` 一把签。`scripts/dev-install.sh` 已经按这个做。
- 直接用这个脚本装，不要手工 `ditto` 加 `codesign`。脚本找不到证书会报错退出，不会悄悄降级。

**授权相关的行为：**
- **辅助功能**：丢了之后系统设置里那条 Dimble 的开关可能仍是开着的，那是旧签名的残留。办法是在列表里选中并点「−」删除，再回 Dimble 点「授予无障碍权限」。Dimble 自己的授权流程只在「按第 2 次」时才重置旧条目。
- **录屏**：可选功能，只用于显示/隐藏时的淡入淡出遮罩，不授权也能用。macOS 约每月让所有 App 重新确认一次，**与签名无关、无法一劳永逸**。用户不在意动画就点「拒绝」。
- **不要替用户重置系统的辅助功能或录屏授权**（`tccutil`），那是修改系统隐私设置，要用户自己点。
- 装之前先退出正在运行的 Dimble（`dev-install.sh` 会做），不要让两个不同签名的副本同时跑，会互相干扰菜单栏。

---

## 5. 必须先问用户的事（本项目的具体化）

- 替换 `/Applications/Dimble.app`：用户日常在用，装之前先说明；`dev-install.sh` 会先备份到 `~/.agents/backups/apps/`，验证备份后再替换。用户明确说「装上去看」才装。
- 推送、合并回 `main`、改写历史、删分支。
- 全局安装依赖（`brew install xcodegen` 之类）、运行来历不明的可执行文件（`/tmp` 里的二进制先问）。
- 发布流程 `scripts/release.sh`（公证、Sparkle 签名、appcast）：只在用户要发版时动，不要顺手改。
- 不读不改含密钥的 `.env`、Sparkle 的 EdDSA 私钥；不把 `SPARKLE_KEY_FILE` 之类写进任何文件或回复。

---

## 6. 开发约定

- **翻译**：界面文字的唯一来源是 `scripts/gen-xcstrings.py`（9 种语言）。改文案就改脚本、重新运行，**不要手改 `Localizable.xcstrings`**，会被覆盖。英文键必须和代码里的字面量逐字节一致。新增设置项还要加到 `Pelmet/CommandBar/SettingsIndex.swift`（设置搜索）。
- **设置存储**：`SettingsStore` 按字段容错解码（`field(...)`），新字段给默认值，旧数据和未知取值只丢那一个字段。新增字段要补解码与测试。
- **面板设置页的预览**用的是真实面板视图（`previewContent`），改面板绘制要同时看设置页预览，也别忘了拖拽幽灵（`PanelDragGhost`）。
- **不要乱用 `try? await Task.sleep`**：任务被取消后它会立刻返回，会让拖拽等流程失去间隔。新代码取消后要检查 `Task.isCancelled`。
- 事件监听（CGEventTap）被系统停用后需要重建，别只在回调里 re-enable。
- 辅助功能（AX）调用在主线程时要设超时，默认 6 秒会卡死界面。
- 修 bug 先看 `docs/REVIEW-FIXES-0.3.2.md`、`docs/ISSUE-AUDIT-0.3.0.md`，避免重复。
- 提交说明用简洁中文；提交结尾带 Claude 协作署名；一次提交讲一件事。**不提交、不推送，除非用户说要。**

---

## 7. 已知未修的问题（2026-10-26 审查留下）

已修的见 git 历史（稳定性提交 `66c4c8e`）。仍未处理，动手前先和用户确认优先级：

- 引擎在 `stop()` 之后仍可能被 `setModel` 重新触发（退出窗口期）；`ItemEnumerator` 里子元素的 AX 读取没设超时、一处 `as! AXValue` 强转。
- 辅助进程通信无鉴权、无协议版本号；辅助进程的日志用 `os.Logger`，在 macOS 27 beta 上到不了统一日志。
- 快捷键冲突提示文案写「被其他 App 占用」，即使占用方是 Dimble 自己的另一个槽位。
- `ClockClickRelay` 会吞掉全屏 App 自动隐藏菜单栏时右上角的点击；`SeparatorManager` 切换样式后宽度不恢复；`AgentPositionStore` 把同一 App 的多个图标顺序写成相同值；拖拽 y 坐标写死 12。
- 设置损坏时数组整体回落默认；保存遇到 NaN 静默失败；`make-dmg.sh` 卷名冲突会操作别的卷；录屏和 Focus 子进程没有超时。
