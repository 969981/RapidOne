# 自动跟踪上游、编译和发布（969981/RapidOne）

工作流：[.github/workflows/upstream-sync-release.yml](../.github/workflows/upstream-sync-release.yml)

## 同步规则

- 每 15 分钟检查 `crispin81/RapidOne:main`。
- 如上游新提交不在本仓库 `main` 的历史中，以 **merge** 保留本仓库 Actions 工作流及其他提交；有冲突时停止，不强推、不覆盖历史。
- 没有新提交时直接退出，不运行耗时编译。
- 首次安装本工作流触发一个引导构建；Actions 中也可用 `workflow_dispatch` 手动强制重新发布。
- 同步时以当前 `package.json` 版本和 commit SHA 创建唯一 tag，例如 `v1.2.1-sync.abcdef123456`。
- GitHub 定时工作流为尽力调度，15 分钟是检查计划而不是严格的延迟保证。

## 已确认的上游依赖限制（2026-11-03）

当前 `package.json` 和 `src-tauri/Cargo.toml` 均引用以下 GitHub 源码依赖：

- `https://github.com/crispin81/RapidCulling-module`，分支 `module`
- `https://github.com/crispin81/RapidRetouch-module`，分支 `module`

这两个仓库通过公共 GitHub API 均无法访问（404）；首次 Actions 运行中匿名 `git ls-remote` 也返回无法读取 GitHub 用户名。无法判定它们是私有、已删除还是仅对特定用户开放。**没有获得这些源码依赖的合法读取权限，无法进行完整源码编译。**

本工作流在编译前调用 `git ls-remote` 验证它们。失败会显示明确错误，Windows/macOS/Linux 构建和发布均停止，不浪费主要编译额度，也不会把上游现成二进制伪称为自编译。

### 怎样解除限制

1. 联系上游维护者，请求两个 module 仓库（及 `module` 分支）的读取权限，或者让维护者将这两个源码模块公开。
2. 如果已获访问授权，可在 GitHub 仓库 **Settings → Secrets and variables → Actions → New repository secret** 新建 `RAPIDONE_MODULES_TOKEN`。使用只对上述仓库有 Content Read 权限的最小权限凭据。仓库不属于当前用户时，该凭据必须由上游仓库授权，普通 fork 的 `GITHUB_TOKEN` 不能自动读取它们。
3. 在 **Actions → Sync upstream and build RapidOne releases → Run workflow** 中勾选 `force_release` 后重试。不要把令牌写入仓库代码、Issue 或 Actions 日志。

注意：本工作流目前不会创建私有仓库权限，也不能替维护者授权。

## 编译与发布目标

- Windows x64：Tauri NSIS `.exe` 和 WiX `.msi`；先执行 Rust 预构建以取得 DirectML，再加入 Windows CRT / DirectML 资源。
- macOS：Apple Silicon `.dmg`。
- Linux x86_64：Ubuntu 24.04 构建环境，打包 `.AppImage`、`.deb`（及 Tauri 按配置提供的其他格式）；Linux 22.04 的 glibc 对目前的 ONNX WebGPU 运行库过旧。
- 运行 `npm ci` 和 `npm run fetch-models`，通过上游 `scripts/prepare-release.sh` 打包 uv 与 Retouch Python 引擎源代码。
- 使用 GitHub Actions Node、Cargo 和模型缓存加速后续构建。
- 先把安装包上传至 draft Release；**仅三个平台都成功**，才补充稳定下载文件名与 SHA256SUMS 并正式发布。构建失败时保留草稿供排查。

## 已知风险

- 上游 release.yml 目前仍然是手动执行且默认草稿发布；本工作流独立运行，不修改上游发布脚本的版本记录。
- 上游模型下载服务器、私有 module 源码、`ort` 预构建二进制、macOS/Windows 签名、CRT/DirectML staging 可能继续导致失败。成功执行的安装包仍应做首次启动功能测试。
- `RapidCull_android.apk` 来自另一个 Android 构建工程，当前桌面 CI **不声称**构建 Android APK。
- Actions 写入 `main` 的自动提交不会被 `GITHUB_TOKEN` 再次触发常规 push 工作流，因此本工作流自行编译与发布，避免重复触发。
