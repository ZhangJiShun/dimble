# Dimble 全项目体检清单（2026-11-11）

> **修复结果（同日）**：由 4 个 Sonnet 子 Agent 按文件范围并行修复，主 Agent 审查改动并统一验收。
> 除下列条目外全部已修：
> - **未做**：B5（要改 AppState 的取数接口）、C8/C9 抽公共代码（纯重构，碰最脆弱的转场，无实机）、B11 自动删旧备份（会删你的数据，要你定）、B12 关于页动画（需实测）、Panel/Panels 改名、PelmetItems 重复日志（上游代码）、§五 全部（删目录/分支要你批准）、`InputSourcePresentation` 废弃 API 警告（没有等价替代）。
> - **部分**：B1/C2 停掉了存图读图，`PanelTileArt.Image.picture` 分支保留并注明已停用；C7 关于页更新开关因 A1 已隐藏，不再加搜索项。
> - **验收**：核心包 644、引擎包 60、App 124 个测试全过；脚本测试 `test_release.py` 4/4、`test_verify_update.py` 通过；App 干净编译成功，警告从约 20 条降到 1 条；A19 新测试在旧代码上确认会失败。**全部没有实机验证。**

分支 `sync-upstream-0.3.5`。**本轮只审不改**，没有动任何代码。
做法：4 个子 Agent 分区逐文件只读审查（核心包+引擎 / App 调度+事件 / 面板+设置界面 / 附加功能+脚本+文档），主 Agent 跑测试、编译、抽查复核。
已排除重复：`AGENTS.md` §7、`docs/AUDIT-CPU-BUGS-2026-11-09.md` §四 里已知的问题不再列。

**基础状况**：核心包 642 个测试、引擎包 62 个测试全过；App 无签名编译通过，约 20 条编译警告（见 §六）；脚本自带测试 4 个挂 2 个（见 A2）。

**把握**：9–10 成 = 读代码/实跑已确证；6–8 成 = 很可能，但取决于运行时情况；3–5 成 = 怀疑，要实测。标 ✅ 的是主 Agent 亲自复核过的。

---

## 一、真坏了、会影响你使用的（按影响排序）

| # | 把握 | 问题 | 位置 | 后果 | 建议 |
|---|---|---|---|---|---|
| A1 | 8 成 ✅ | **fork 仍连着上游的更新源**，且自动检查更新是开着的 | `project.yml:104-106`、`Update/SparkleController.swift:92-117` | 上游已有 0.4.0 beta，正式版一发，菜单栏会提示更新；点了就被上游原版覆盖：本地面板样式全丢、签名换掉、辅助功能授权失效 | fork 里关掉自动检查或清空 `SUPublicEDKey`（改 project.yml 要你点头） |
| A2 | 10 成 ✅ | **本地改的 `release.sh` 让上游自带的 2 个脚本测试失败**；试跑模式（`SKIP_NOTARIZE`）不再校验更新签名 | `scripts/release.sh:91-99`、`scripts/tests/test_release.py` | 同步上游时测试一直红，掩盖真回归；发版试跑少一道签名检查 | 要么让试跑也校验签名，要么改测试承认新行为；顺带删掉恒为真的 `if` 和死掉的 else（release.sh:99,130-133） |
| A3 | 9 成 ✅ | **列表样式选「1 列」，重启后变 2 列** | `Settings/PanelPane.swift:181` vs `PanelOptions.swift:71`（`columnRange = 2...10`） | 设置当次生效、重启静默变；拖边缘也拖不到 1 | 存储下限改 1（按样式区分），或菜单去掉 1 |
| A4 | 8 成 ✅ | **`dev-install.sh --rollback` 可能退到错误版本** | `scripts/dev-install.sh:71-78` | 按修改时间挑「最新」备份，但 `ditto` 保留原时间，且 `Dimble-*.app` 也会匹配 `replaced-by-rollback` 那份；第二次回退可能在两版之间来回切 | 按文件名里的时间戳排序，排除 `replaced-by-rollback` |
| A5 | 8 成 | `dev-install.sh` 签名失败时**一句原因都不打印** | `scripts/dev-install.sh:131-139` | 证书锁住/过期时只看到脚本停在「签名」 | 保留 stderr |
| A6 | 8 成 | 选「自定义颜色」后再调色，**菜单栏的更新小圆点不跟着变** | `StatusItem/PelmetStatusItem.swift:445-454` | 只盯了 `choice` 没盯 `customHex` | `track()` 里也读 `customHex` |
| A7 | 8 成 | 命令栏搜「Show names / 显示名称」，样式是紧凑或列表时**跳过去什么都没有** | `Settings/PanelPane.swift:52-63` | 这一行只在图块样式才画，跳转没改道 | 非图块样式时改道到「样式」行 |
| A8 | 7 成 | 时钟、控制中心在布局编辑器里，**锁形角标被苹果角标盖住** | `Settings/MenuBarTab.swift:663-711` | 看不到「Pinned by macOS」提示，不知道为什么拖不动 | 两个角标二选一或分开放 |
| A9 | 7 成 | 专注、SharePlay、计时器三个额外图标的 `log stream` **断了就无限重试，每次都先重读几小时到 7 天的系统日志**，遇到「Must be admin」也照样重试 | `Extras/FocusStatus.swift:146-157`、`SharePlayStatus.swift:188-199`、`ClockTimerStatus.swift:126-137` | 系统日志服务反复重启时持续吃 CPU；`LiveActivityStatus` 已经处理好了，另外三个没跟上 | 照 LiveActivityStatus 的做法统一 |
| A10 | 6 成 | 上面四个 `log stream` 的**重试等待只增不减** | 同上 + `LiveActivityStatus.swift:263` | 用久了每次断流都要等满 60 秒才恢复，期间专注/计时器指示不更新 | 跑稳后把计数清零 |
| A11 | 6 成 | **⌘-拖拽可能认错 App**：`lastHitOwner` 多数分支不清空 | `Events/MenuBarBandMonitor.swift:37,242,1066` | 点击被微信浮层等拦下后，下次 ⌘-拖拽拿到很久以前那次的 App，可能把错的图标挪到别的分区 | 每次左键按下先清空 |
| A12 | 6 成 | 分隔符/额外图标在「显示→隐藏」快速反转时**闪一下** | `StatusItem/StatusItemFader.swift:84-89,121-127` | 淡入回调不检查是否已过时 | 回调先判 `stillCurrent()`，隐藏时撤掉动画 |
| A13 | 6 成 ✅ | **磁盘写满时日志写入会让 Dimble 闪退** | `PelmetEngine/PelmetLog.swift:76,136,142` | 旧式 `FileHandle.write(Data)` 出错抛的是 Swift 接不住的异常，一崩菜单栏图标全弹回 | 改 `try? write(contentsOf:)` |
| A14 | 5 成 | `tmutil status`、`shortcuts list` 子进程**没超时** | `Extras/TimeMachineBackup.swift:65-80,175-191`、`MediaControls.swift:1834-1850` | 备份盘无响应时时间机器图标从此不刷新；快捷指令菜单一直不出来 | 加超时 |
| A15 | 5 成 | 运行快捷指令失败**无日志** | `Extras/MediaControls.swift:1810-1815` | 快捷指令改名后点了没反应也查不到原因 | 记退出码 |
| A16 | 6 成 | 引擎快照「内容相同」判断漏比 `shownAlone` | `PelmetEngine/MenuBarEngine.swift:62-66`、`AppState.swift:5013` | 只有单独显示的图标变化时，Apply 计数可能短暂用旧数据 | 纳入比较 |
| A17 | 6 成 | `Plan` 的 `==` 不比较 `placements` | `PelmetCore/MovePlan.swift:186-188` | 测试用 `==` 时 placement 回归测不出 | 加上比较 |
| A18 | 4 成 | 合成 ⌘-拖拽每段间隔用 `try? await Task.sleep`（AGENTS.md §6 点名禁止） | `PelmetEngine/ItemMover.swift:88-188` | 上游任务若被取消，后续事件零间隔连发、拖拽落空；没确认调用方会不会被取消 | 间隔不受取消影响，且保证 mouseUp 必发 |
| A19 | 4 成 | strayPlan 把「站错边但被豁免的图标」当拖拽邻居 | `PelmetCore/MovePlan.swift:381-389` | 可能出现反复「1 not moved」 | `staying` 里同样跳过 `misplaced` |
| A20 | 4 成 | 4 个事件监听线程的 `tap/tapRunLoop` 没加锁（注释却说加了） | `Events/ClockClickRelay.swift:21-27,116-164`、`BarDragRedirect.swift:100-143` 等 | 极端时序下旧监听线程停不掉 | 统一纳入锁（见 C9） |

## 二、低效的（白干活）

| # | 把握 | 问题 | 位置 |
|---|---|---|---|
| B1 | 9 成 ✅ | 面板改用 App 原生图标后，截图存图那套**只写不读**：每次仍把所有图编码成 PNG 写盘，启动再读回来，但 `picture(for:)` 全仓没人调用 | `Panel/PanelPresenter.swift:27,2336`、`Panel/ItemPictures.swift` |
| B2 | 9 成 | 自动分组、单个自有图标放置时，白算一遍只有「Apply」按钮才用的整栏移动计划 | `App/ApplyPass.swift:413-415` |
| B3 | 8 成 | 预截图时连续两次判断「通知中心开没开」，第二次恒为 false，但每次都在主线程拉完整窗口列表 | `App/TransitionCoordinator.swift:2117-2125` |
| B4 | 7 成 | 布局编辑器拖动时，每次鼠标移动都整张重建图标板 | `Settings/EditorDragSession.swift:171-181` |
| B5 | 6 成 | 面板每次刷新（打字、拖列宽）调 3 次 `editorItems` | `Panel/PanelPresenter.swift:1050-1058` |
| B6 | 6 成 | `pendingMoveCount` 每次读都先拼一长串日志字符串再判断要不要写 | `App/AppState.swift:3089-3125` |
| B7 | 6 成 | 拖色轮每一帧都写 UserDefaults 并让整个设置窗口重绘 | `Settings/AccentPicker.swift:170-174,200-202` |
| B8 | 7 成 | 搜索页每次重绘都重新解码整份搜索历史 | `CommandBar/CommandBarController.swift:1049` |
| B9 | 7 成 | 时钟点击中继在主线程 `usleep` 60ms | `Events/ClockClickRelay.swift:507` |
| B10 | 6 成 | 遍历菜单栏时每个图标多读两次 AX 属性（且这些读没超时） | `PelmetEngine/ItemEnumerator.swift:274-279` |
| B11 | 7 成 | dev-install 每次都备份、从不清理（已 10 份 197M） | `scripts/dev-install.sh:155-158` |
| B12 | 5 成 | 关于页动画图标静止时也逐帧重绘；通用页权限都授予后仍每秒轮询 | `Settings/AnimatedAppIcon.swift:20-41`、`SettingsView.swift:1024-1034` |
| B13 | 4 成 | 解析日志每行新建一个 `DateFormatter` | `Extras/SharePlayStatus.swift:225`、`LiveActivityStatus.swift:317`、`ClockTimerStatus.swift:174` |

## 三、不一致的

**会误导行为判断的**

| # | 把握 | 问题 | 位置 |
|---|---|---|---|
| C1 | 9 成 | AGENTS.md 已过时：xcodegen 已用 brew 装在 `/opt/homebrew/bin`，文中的 `/tmp` 副本已不存在；AppState 写「4000+ 行」实为 5460；测试宿主已不启动引擎（`84cf6bd`）没记；§6「修 bug 先看」没列 11-09 的审查文档，且该文档还没进 git | `AGENTS.md:31,45,47`、§6 |
| C2 | 9 成 | AGENTS.md §3.3 写「占位图允许升级成真图一次」，实际已不会发生（`isFinal` 恒为 false，`buildContent` 永远不报缺图） | `Panel/PanelPresenter.swift:1203`、`PanelView.swift:656-679` |
| C3 | 9 成 | 点图标时注释写「遮罩揭开、菜单从真图标落下」，实际常量 `pressCoverLiftsAfterClick = false`，遮罩一直盖到菜单关闭 | `Press/ItemPress.swift:10-11,284-291`、`AppTiming.swift:314` |
| C4 | 9 成 | 同一判断两份实现：`PlacementGeometry.isPrimary` 与 `MenuBarGeometry.isInPrimaryBand` 逐字相同，不同模块各用一份 | `PlacementGeometry.swift:29`、`MenuBarPolicy.swift:286` |
| C5 | 9 成 | 「菜单栏下留多少缝」两套：`GlassPanel.gapBelowBar = 4`（命令栏）与 `PanelPresenter.gapBelowBar = 0`（面板） | `Panels/GlassPanel.swift:25`、`Panel/PanelPresenter.swift:23` |
| C6 | 6 成 | 命令栏用 AX 快照定位菜单栏图标，面板用按钮窗口实时位置；图标刚挪动后命令栏可能对不准 | `CommandBarController.swift:380-391` vs `PanelPresenter.swift:854-859` |
| C7 | 7 成 | 设置搜索漏项：关于页 3 个更新开关、通用页图标样式、启动器、Dimble items、逐屏设置都搜不到；about/displays 页名没本地化 | `CommandBar/SettingsIndex.swift:35-108` |
| C8 | 8 成 | 遮罩收尾流程写了三份（endLive/endLift/endBarCover），参数已开始分叉 | `App/TransitionCoordinator.swift:528-546,652-680,1300-1315` |
| C9 | 8 成 | 4 个事件监听各复制一份线程代码，「监听死了」的判断分两套 | `ClockClickRelay`、`BarDragRedirect`、`PointerMoveTap`、`HoverTypingTap` |
| C10 | 6 成 | 列表样式里 Always Hidden 的折叠格仍按图块画（只有 +N、居中、无名字） | `Panel/PanelView.swift:786-824`（需实机看） |
| C11 | 5 成 | 设置窗口开着时插拔显示器，显示器页不刷新 | `SettingsView.swift:1411-1419`、`PanelPane.swift:33,68` |
| C12 | 8 成 | 「私有 API 可用性会变化、能自愈」是假的：底层只检测一次 | `PelmetEngine/AssessmentMode.swift:23-27`、`MBAssessmentShim.m:11-13` |
| C13 | 6 成 | 3 个额外图标 `stop()` 不移除退出观察者（LiveActivity 会移除） | `FocusStatus.swift:42-59` 等 |
| C14 | 6 成 | `RevealReason.itemInBar` 注释说「同 hotkey」，实际有 4 秒计时 | `PelmetCore/RehideStateMachine.swift:23-24` |

**注释贴错地方（都是 8–9 成，纯阅读误导，不影响运行）**
- `SettingsStore.swift:371-373`（RevealAnimation 的说明贴在 StatusIconStyle 上）
- `BarAdoption.swift:29-52`（reconcile 的说明贴在 refill 上）
- `AgentBarEngine.swift:390-406`（openAdoptionWindow → holdsAssertion）、`:1004`（concealedItemsStillVisible → freshSnapshot）
- `AppState.swift:1713, 1830, 2496, 4040, 4210` 五处
- `TransitionCoordinator.swift:263`、`:118-126`（孤儿注释，下面没有属性）
- `ClockClickRelay.swift:268`、`OverflowToggle.swift:169`（说返回 toggle，实际返回 Bool）
- `PanelPresenter.swift:1832-1846`（setColumns → setStyle）、`RevealPresenter.swift:4`（说只有菜单栏一种）
- `SettingsView.swift:547-554, 642-648`、`CommandBarController.swift:1051`（重置历史按钮位置写错）
- `HotkeyManager.swift:40`（注释 `PELMET`，值实为 `NOOK`；只改注释别改值）
- `ItemMover.swift:171-173`（引用的 `placementPreSettle` 已不存在）
- `RehideStateMachine`、`MenuBarEngine.contentEquals` 注释与实际语义不符（见 A16、C14）

## 四、已经不需要的（死代码，全仓 grep 确认无人引用）

| 把握 | 内容 | 位置 |
|---|---|---|
| 10 成 ✅ | `reopenAdoption(for:)` 无人调用，连带 `absentBundles` 永远是空，`:3748` 的过滤、`:5028` 的移除都是死的。**需确认启动器流程是否本该调用它** | `App/AppState.swift:763,794` |
| 10 成 ✅ | `hasAppLauncher(for:)`、`pressRunning` | `App/AppState.swift:2521,3444` |
| 10 成 ✅ | `panelSlideInFade`、`panelShadeInset`；`panelSlideIn` 为 0 仍 sleep 一次 | `App/AppTiming.swift:51,65`、`AppState.swift:1975` |
| 9 成 ✅ | `pastChevron`、`meanLuma` | `PanelPresenter.swift:24`、`ConcealGhostOverlay.swift:287-302` |
| 9 成 | 面板缺图→截图那条链路（`missing`、预览的 `picture()/passKey/revision`、`PanelTileArt.Image.picture` 分支），见 B1/C2 | `PanelPresenter.swift`、`PanelPane.swift:226,321,522-536`、`PanelView.swift` |
| 9 成 ✅ | `appAcceptsSetModel`、`appMayMarkStarted`：只有测试在调，App 自己手写了同样的判断——**测试测的是没人用的副本** | `PelmetEngine/EngineLifecycle.swift:9,14` |
| 9 成 ✅ | `overflowTrappedCount`（只有测试用，AppState 注释还指着它） | `PelmetCore/PlacementGeometry.swift:65-69` |
| 9 成 | `EngineTiming.axAppTimeout`、`MessagePortLink.isListening`、`HideGranularity` 枚举与 `hideGranularity/canReorder` 字段 | 引擎/核心包 |
| 8 成 | `PanelGrid.panelSize`、`SearchHistory.frecency(of:at:)`（只有测试用） | 核心包 |
| 7 成 | `Roster.assign`（只有测试用，且对临时副本赋值不会写回） | `PelmetCore/Roster.swift:23` |
| 8 成 | `MovePlan` 里 `let runs = [run]` + 循环，旧多段设计残留 | `MovePlan.swift:257-260` |
| 9 成 | `gen-xcstrings.py` 里 `"Time Machine"` 重复定义两遍 | `scripts/gen-xcstrings.py:461,553` |
| 9 成 | 辅助程序启动时连写两条重复的 ready 日志（上游代码，可不动） | `PelmetItems/main.swift:63-65` |

## 五、仓库与磁盘卫生（只列出，未动）

| 把握 | 内容 | 建议 |
|---|---|---|
| 9 成 | 仓库根 `.build/` 占 **2.7G**：10 月 24–26 日 Codex 试验的 7 份候选构建、日志、截图、两个自编译小程序，另有 93M 的 `.build/Backups/`（可能含旧版 App） | 你确认后清理；`Backups/` 先看一眼 |
| 9 成 | `grok-merge` 分支及工作树 `/Users/jason/worktrees/Pelmet-grok-merge`（406M）已完全并入 0.3.5 | 你同意后移除 |
| 7 成 | `sync-upstream-0.3.3` 已并入 0.3.5；`main` 还缺它的 72 个提交（main 落后两轮同步）；`sync-upstream-0.3.5` 有 8 个提交未推送 | 0.3.5 合回 main 后删 0.3.3（合并/删除/推送都要你批准） |
| 9 成 | `docs/AUDIT-CPU-BUGS-2026-11-09.md` 还没进 git | 决定是否提交 |
| 6 成 | 若干 `.DS_Store`（已被忽略，不进 git） | 不用管 |

## 六、编译警告（主 Agent 实际编译所得，约 20 条，不影响运行）

- `PanelView.swift:280,354,373,517`、`MenuBarTab.swift:340,1311`：主线程属性在 Sendable 闭包里引用（Swift 6 并发警告）
- `MediaControls.swift:1953,2128`：在非主线程上下文调主线程方法 `poll()`（计时器实际在主线程触发，目前无害）
- `AppState.swift:1041`、`TransitionCoordinator.swift:1060`、`MenuBarBandMonitor.swift:618`、`HelperHosts.swift:141`：内层 `[weak self]` 被外层隐式强引用抵消
- `ConcealGhostOverlay.swift:1133,1180`：元组元素隐式重排，未来 Swift 版本会报错
- `ItemMover.swift:350`：非 Sendable 的 `DragShield` 被 Sendable 闭包捕获
- `InputSourcePresentation.swift:44`：`NSImage(iconRef:)` 自 macOS 11 起已废弃
- `ItemIDGrammar.swift:119`：多余的 `public`

## 七、没审到/没审全的部分

- `LiveMirror.swift`、`MediaControls.swift`（共约 5600 行）只看了子进程、观察者、循环相关段落。
- `MenuBarTab.swift` 后半段（1040 行后）、`SearchPane` 后半、`ShowWhen` 规则细节、`CommandBarView/Field/Corpus`、`ConcealGhostOverlay` 截图切割中段（450–890 行）只快速扫过。
- `AudioVideoPill`、`AppleMenuExtras`、`ExtraGlyphs`、`PelmetTimer` 只做了关键词扫描。
- App 测试（`PelmetTests/`）没跑（会弹录屏授权框）；`test_verify_update.py` 没跑。
- **所有条目都没有实机验证**。

## 八、已核对没问题的

- 翻译：504 个键，9 种语言齐全，占位符一致，生成结果与已提交的 `Localizable.xcstrings` 逐字节相同，无漏翻、无废键。
- 设置搜索的锚点 id 与界面 `.settingAnchor` 一一对应（漏项见 C7）。
- 本地 UI 底线（§3 第 1–4 点）：三种面板样式的 `showsNames`、拖拽幽灵、设置页预览与真实面板的居中和列宽计算，都没发现问题。
- `PelmetTests` 没有指向已删除代码的测试。
