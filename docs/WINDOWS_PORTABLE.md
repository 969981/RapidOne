# RapidOne Windows 绿色版（ZIP）

## 下载

[当前 v1.2.1 ZIP](https://github.com/969981/RapidOne/releases/download/upstream-v1.2.1/RapidOne_1.2.1_windows_x64_portable.zip)

可在 [Releases](https://github.com/969981/RapidOne/releases) 查看后续版本。

- 文件名格式：`RapidOne_<version>_windows_x64_portable.zip`
- 独立校验清单：`RapidOne_windows_x64_portable.sha256.txt`（与上游安装包的 `SHA256SUMS.txt` 不同）
- ZIP 中包含：`RapidOne.exe`、程序资源、`Start-RapidOne-Portable.cmd`、`portable.flag`、`Data/` 和 `PORTABLE-README.txt`。

## 如何使用

1. 解压整个 ZIP 至**可写**目录，例如 `D:\\Apps\\RapidOne-Portable`；不要直接从 ZIP 内运行，也不要解压到 `Program Files`。
2. 双击 `Start-RapidOne-Portable.cmd`（不要运行 MSI 安装程序）。
3. 此启动器为程序进程设置 `APPDATA`、`LOCALAPPDATA`、`HOME`、`UV_CACHE_DIR`、`TEMP` 等环境变量，尽量将支持这些变量的缓存和 Python 引擎下载保存在 `Data/` 内。
4. `portable.flag` 作为本仓库 **重新编译的** RapidOne 可识别的便携模式标记；不要删除。
5. 如果要整体搬迁软件及已有 `Data/`，先正常退出程序，再复制整个文件夹到目标磁盘。不要在运行时复制数据库和缓存。

Windows 10 / 11 x64；Tauri 需要 Microsoft Edge WebView2 Runtime。此 ZIP 没有安装 WebView2，缺少该运行时时可能无法打开。

## 绿色包与数据完全便携的区别

**当前 v1.2.1 ZIP 从官方公开的 Windows MSI 行政解包得到，并非本仓库重新编译的程序。** 打包器没有执行 MSI 安装，也不会特意写入注册表或系统安装目录。但原程序仍可能自行访问 Windows 已知目录。

| 数据 | 当前官方 MSI 解包绿色版 | 未来源码自编译便携模式 |
| --- | --- | --- |
| 程序安装 | 解压即用，不执行安装程序 | 同左 |
| 通过环境变量定位的缓存和 Python 下载 | 启动器尝试写入 `Data/`；需实际验证 | 同左 |
| RapidOne 预设和 AI 风格 | 原版 Tauri 可能仍写系统 AppData | 已在主仓库源代码改为 `Data/Roaming/com.chriscork.rapidone/` |
| 用户导入的相机配置文件 | 原版可能写 `Documents/RapidOne/Profiles` | 已在主仓库源代码改为 `Data/Documents/RapidOne/Profiles` |
| Lensfun 更新 | 原版可能写系统 LocalAppData | 已在主仓库源代码改为 `Data/Local/com.chriscork.rapidone/lensfun` |
| Cull / Retouch 模块的数据 | 未验证；依赖上游独立模块实现 | 仍需取得两个模块源码后检查和改造 |
| 编辑记录（`.rpd`）与相片预览缓存 | 按上游设计存放在照片旁的 `sidecars/` | 暂时保持原设计，**不**搬到 `Data/` |
| RAW、照片原件及导出文件 | 在用户选定目录；不会因为是便携版自动迁移 | 同左 |

因此目前保证的是**免安装 ZIP**，并没有声称完全无外部数据写入。若把照片文件和 `sidecars/` 放在绿色版目录之外，复制绿色版目录并不能带走照片的编辑历史。

## 自动打包流程

- 工作流：[.github/workflows/upstream-sync-release.yml](../.github/workflows/upstream-sync-release.yml)，新增 `windows-portable` 任务。
- 脚本：[scripts/build-windows-portable.ps1](../scripts/build-windows-portable.ps1)。
- 先从本仓库已发布、经过上游 SHA256 验证的 MSI 下载文件。
- 在 Windows GitHub Runner 上使用 `msiexec /a` 管理员提取（只解压、不安装），找到 `RapidOne.exe`，复制整个软件目录。
- 将启动器和 `portable.flag` 加入 ZIP；计算独立 SHA256，并上传至同一 Release。
- 后续如果上游新版本发布，本仓库的 15 分钟检查和镜像任务会触发同样的 ZIP 打包；若将来可以合法取得两个私有模块的源码依赖，独立源码编译和源码绿色版构建也能使用这一打包器。

## 尚需验证

在一台没有安装 RapidOne 的 Windows 系统上，验证 ZIP 可解压启动、WebView2 依赖、RAW 加载、修图和导出、AI 首次安装、退出重开、迁移目录恢复设置，以及系统 AppData/Documents 中是否新增了程序数据。

目前 Windows Actions 证明的是 **MSI 提取、ZIP 创建、校验文件生成和 Release 上传**，不是这些端到端运行时验收。不要删除原有 RapidOne 配置、照片或 sidecars 来测试便携版。
