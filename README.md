# OASX 2.x

[OnmyojiAutoScript](https://github.com/pinkpig-Peppa/OnmyojiAutoScript) 的**桌面控制端**，
基于 Flutter Windows 构建。

**当前版本：v2.4.1+** —— 本分支由 `pinkpig-Peppa/OASX` 维护，新增设置页「导出诊断包」「一键体检」入口与 GitHub Actions 自动构建发布，并在 2.x 基础上保留失败任务队列过滤与 18 秒连续眼睑动画。

后续每次修复将补丁版本递增 `0.0.1`，同时递增构建号。

本次启动修复详见 [启动修复说明](./启动修复说明.md)。窗口位置配置异常或显示器断开时恢复为居中窗口；保存的 OAS 目录失效时识别相邻有效安装，无法识别则提供目录选择和重新连接入口。

## 两条获取途径

| 方式 | 适合谁 | 怎么做 |
|---|---|---|
| **下载发行包**（推荐普通用户） | 只想直接用 | 到 [GitHub Releases](https://github.com/pinkpig-Peppa/OASX/releases/latest) 下载 `oasx_<version>_windows.zip`，解压后双击 `oasx.exe` |
| **clone 本仓库** | 想改代码 / 自行构建 | `git clone`，进入 `src/` 使用 Flutter SDK 构建（仓库不再提交预编译二进制，避免与源码脱节） |

> 根目录不再保留预编译 `oasx.exe` / `*.dll` / `data/`，Windows 可执行发行包统一由 `.github/workflows/build-windows.yml` 构建并通过 GitHub Releases 分发。

## 目录结构

```
OASX/
├─ .github/workflows/            # Windows CI 自动构建与 Release 发布
├─ src/                          # ★ 完整 Flutter 工程（可重新构建）
├─ tools/                        # 资源清单同步 / 手工构建 / 版本资源工具
├─ docs/                         # 项目文档（含视觉验收页）
└─ LICENSE
```

### 发行包内插件 DLL 说明

| 文件 | 用途 |
|---|---|
| `window_manager_plugin.dll` | 无边框窗口、窗口尺寸与位置控制 |
| `system_tray_plugin.dll` | 系统托盘图标与菜单 |
| `screen_retriever_windows_plugin.dll` | 屏幕信息读取（分辨率、多屏） |
| `url_launcher_windows_plugin.dll` | 调起外部浏览器 / 链接 |
| `connectivity_plus_plugin.dll` | 网络连通性检测 |
| `super_native_extensions.dll` | 原生扩展运行时（拖放等） |
| `super_native_extensions_plugin.dll` | 原生扩展插件入口 |
| `irondash_engine_context_plugin.dll` | Flutter 引擎上下文桥接 |

## 运行要求

- Windows 10 / 11（x64）
- 发行包内已附带全部运行时依赖，无需安装 Flutter SDK
- 首次启动会自动定位 OAS 目录（见下）

解压发行包后双击 `oasx.exe` 即可启动。**请保持 `data` 目录与所有 DLL 和 exe 位于同一目录。**

## 默认 OAS 仓库

首次启动且未保存 OAS 位置时，默认使用 `..\OAS\OnmyojiAutoScript-easy-install`。

- 默认仓库：`https://github.com/pinkpig-Peppa/OnmyojiAutoScript.git`
- 默认分支：`master`

> 已保存且有效的 OAS 位置、或 `deploy.yaml` 中明确配置的仓库与分支，**优先于**上述默认值。保存的目录失效时，仅检查程序旁经过验证的 OAS 安装，不对错误目录自动执行部署。

## 从源码构建

`src/` 是完整可编译的 Flutter 工程：

```powershell
cd src
flutter pub get
flutter analyze --no-fatal-infos
flutter test
flutter build windows --release --build-name 2.4.2 --build-number 29
```

产物位于 `src\build\windows\x64\runner\Release`，将其打包或复制到目标目录运行即可。推送 `v*` tag 或在 GitHub Actions 手动触发 `Build Windows` 工作流会自动完成分析、测试、构建并上传发行包。

| 组件 | 版本 |
|---|---|
| Flutter | 3.47.5（stable） |
| Dart | 3.13.4 |

> **Windows 构建前置**：Flutter 在 Windows 上构建带插件的工程需要符号链接权限。
> 若报 `Building with plugins requires symlink support`，请开启「开发者模式」
> （设置 → 系统 → 开发者选项），或以管理员身份运行终端。

## 自动更新

应用内「检查更新」指向本仓库的 GitHub Releases：

```
https://api.github.com/repos/pinkpig-Peppa/OASX/releases/latest
```

比对本机版本与最新 release 的 tag，仅当远端更新时提示；Windows 更新采用同卷备份与选择性原地覆盖，支持跨盘符更新、保留 `logs/` 等用户文件，并在失败时自动回滚。

## 与上游的关系

本仓库基于 `tomoe1-1/OASX` 2.x 演进（2.x 完成了视觉层与工作台重做）：

- 主页加入正面人物科技风**全幅动态背景**，随窗口尺寸自适应铺满
- 启动页线稿**右下角重绘**
- 工作台与日志区**透明度重新校准**
- 恢复**左上角应用图标**

历史版本见 [Releases](https://github.com/pinkpig-Peppa/OASX/releases)。

## 2.4.1 失败任务列表

失败任务队列从这一版起只显示**启用中**的任务：

- 手动停用（暂停）的失败任务不再占一行，标题「失败任务（N）」的计数与列表口径一致。
- 记录仍保留在数据层，不会被清空；重新启用后回到列表，并显示原来的重试时间。
- 不再对停用的任务显示「下次重试」这种已经不成立的时间。

详细说明见 [2.4.1 失败任务列表](./docs/2.4.1失败任务列表.md)。

## 2.4.0 眼睛动画

主页背景与启动页的少女从这一版起会真正把眼睛睁开 —— 不是整张图淡入淡出地切换，而是眼睑本身沿连续曲线抬起。

- **主页**：18 秒一轮 —— 0.7 秒闭眼静止、3.6 秒缓慢睁开、12.5 秒保持、1.2 秒闭合。
- **启动页**：睁眼由独立 controller 驱动，与进度解耦；任务模式下进度仍来自外部任务，收尾计时改为「剩余动画时长 + 停留」。
- **减少动态效果**：停在睁开状态并保持静止，内容正确、只去掉运动。
- **实现**：5 张预渲染姿态图 + 单调 Hermite 插值（位置与斜率同时约束，不 overshoot）+ 网格变形（只移动夹着眼睑的窄带，周围头发皮肤不动）。

新增 7 张眼睑姿态 PNG。详细说明见 [2.4.0 眼睛动画](./docs/2.4.0眼睛动画.md)。

## 2.3.0 失败任务操作

失败任务队列中的每一行现在与工作台普通任务行使用同一套操作栏，不必再切回任务列表去处理。

- **立即执行**：把失败任务按「立刻运行」重新入队，等待中的排队任务完成后执行。
- **等待**：按设置的顺延时间刷新重试时间，不立即抢占。
- **打开参数**：直接进入该任务的参数页，与普通任务行一致。
- 操作栏在窄窗口（260 / 360 / 700 px 宽）下不溢出；任务被手动禁用、批量快捷调度进行中、或已有其他任务在运行时，快捷按钮自动置灰，仅保留参数入口。

修复：快捷调度写「下次执行时间」时，此前对**每个联动配置**都沿用外层传入的脚本名与任务名，导致联动配置写错任务或状态判断错误；现改为下发各自解析后的脚本与任务名，并在任一联动配置失败时如实向上返回失败，不再误报成功。

详细说明见 [2.3.0 失败任务操作](./docs/2.3.0失败任务操作.md)。

## 2.2.0 Dashboard 交互

统计页重做为可交互 Dashboard，复用原有统计模型、日期与指标选择器、HTTP / SSE 数据流与执行详情组件。

- **拖动模块网格**：按住模块左上角手柄移动到目标位置，其他模块平滑让位、松手吸附，顺序自动保存。
- **模块原位放大**：点击模块标题或右上角放大按钮，底部缩略条切换模块，关闭后恢复原位置与滚动位置。
- **顶部全局筛选**：日期、指标与排序常驻顶部，统计数字滚动过渡、图表平滑更新；日期请求期间保留上一次数据并显示加载进度。
- **图表悬停联动**：悬停任一图表时三个图表同步高亮同一任务，其余任务淡化并显示竖向参考线。
- **指标滚动吸顶**：向下滚动时汇总区连续收缩为单行固定栏，反向滚动连续还原。
- **列表详情抽屉**：点击任务行右侧滑出执行详情，列表缩窄保持可见，上下按钮切换任务。

详细说明见 [Dashboard 2.2.0 实现与验收](./docs/dashboard-2.2.0.md)，布局预览见 `docs/dashboard-preview.png`（测试数据渲染，不代表当前统计记录）。

## 2.1.0 失败任务选择

- 工作台任务选择列表纳入失败任务队列中仍处于启用状态的任务，任务失败进入重试队列后不再从可选列表消失。
- 失败任务被手动禁用后不再被自动重新纳入选择；任务重新入队时恢复可选中状态。
- 详细说明见 [2.1.0 失败任务选择](./docs/2.1.0失败任务选择.md)。

## 2.0.3 背景与跨栏缩放

- 顶部与正文透出同一个全幅动态背景，标题栏使用白色高透明圆角框。
- 继续提高工作台透明度，浅色主面板/右侧/日志内部不透明度为 50%/38%/44%。
- 背景绘制限制在当前软件区域，首次加载不再替换正文父级结构。
- 约束变化或手势取消时清理未完成的分隔条拖动，展开后恢复保存的栏宽。
- 详细说明见 [2.0.3 背景与跨栏缩放](./docs/2.0.3背景与跨栏缩放.md)。

## 2.0.2 缩放与标题栏

- 拖动外缘结束后校正 Flutter 子窗口并重发最终视口尺寸，原生窗口不再使用透明合成底色。
- 标题栏改为深蓝灰渐变、浅色操作图标及青色细线，保留头像、设置、拖动与窗口按钮。
- 本次重编 Windows 原生 runner；只替换 AOT 文件不能包含这项修复。
- 回归说明见 [2.0.2 窗口缩放与标题栏](./docs/2.0.2窗口缩放与标题栏.md)。

原生测试（Visual Studio C++ 与匹配的 Flutter SDK）：

```powershell
./tools/test_window_resize.ps1 -FlutterRoot C:\path\to\flutter
```
## 2.0.1 任务显示修复

- 配置卡分两行显示“当前任务”和“下个任务”，窄面板也保留两行。
- 旧 OAS 后端的 `schedule.running` 可能是调度候选；当前任务由 `Scheduler: Start/End task` 运行日志确认，候选保留在下个任务队列。
- 中途连接时回溯近期运行日志恢复当前任务；无法确认时显示“正在获取”，停止后显示“暂无运行任务”。
- 下个任务保留后端的调度顺序，优先待执行队列，然后等待队列，并排除当前任务。

## 仓库说明

- 本仓库仅托管**源码、工具脚本与文档**，Windows 发行包统一通过 GitHub Releases 分发
- `logs/`（本机运行日志）、`src/build/`、`src/.dart_tool/` 及根目录运行产物（`oasx.exe`、`*.dll`、`data/`）均已在 `.gitignore` 排除
- `oasx_<version>_windows.zip`（发行包）**不入库** —— 由 CI 自动构建并上传至 GitHub Release
