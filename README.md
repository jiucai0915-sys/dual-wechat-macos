# dual-wechat-macos

在 macOS 上从本机已经安装的官方微信生成一个独立的第二微信应用 `WeChat2.app`，用于同时登录两个微信账号。

本仓库既可以作为 Hermes/Codex Skill 使用，也可以直接运行 Shell 脚本。仓库不包含、不下载、也不分发微信应用本体。

## 功能

- 从 `/Applications/WeChat.app` 复制生成 `/Applications/WeChat2.app`
- 将主应用 Bundle ID 修改为 `com.tencent.xinWeChat2`
- 将显示名称修改为 `WeChat2`
- 清除原签名并执行深度 ad-hoc 重签名
- 部署前后执行严格签名校验
- 验证 Bundle ID、签名、运行进程和独立数据路径
- 目标应用已存在时拒绝覆盖，避免误删现有副本

## 已验证环境

| 项目 | 已验证版本 |
| --- | --- |
| macOS | 26.4 Tahoe |
| 处理器 | Apple Silicon |
| 微信 | 4.1.10 |

其他系统版本、Intel Mac 或未来微信版本可能也能运行，但尚未在本仓库中验证。微信大版本更新后，建议重新执行完整的复制、签名、验证和启动测试。

## 使用前准备

确认官方微信已经安装在标准位置：

```bash
test -d /Applications/WeChat.app \
  && echo "已找到官方微信" \
  || echo "未找到 /Applications/WeChat.app"
```

建议至少预留约 4 GB 可用磁盘空间。部署到 `/Applications` 时，macOS 可能要求输入当前用户的管理员密码；请只在系统终端提示中输入密码，不要把密码发送给 AI 或保存到环境变量中。

## 快速开始：直接运行

克隆仓库：

```bash
git clone https://github.com/jiucai0915-sys/dual-wechat-macos.git
cd dual-wechat-macos
```

生成并立即启动第二个微信：

```bash
bash scripts/install-dual-wechat.sh --launch
```

如果只想安装、暂时不启动：

```bash
bash scripts/install-dual-wechat.sh
```

安装完成后，第二个微信位于：

```text
/Applications/WeChat2.app
```

以后可以直接启动：

```bash
open -n /Applications/WeChat2.app
```

也可以在 Finder 的“应用程序”目录中双击 `WeChat2`，或将它拖入 Dock。

## 作为 Hermes Skill 使用

安装到 Hermes Skills 目录：

```bash
mkdir -p ~/.hermes/skills/software-development

git clone \
  https://github.com/jiucai0915-sys/dual-wechat-macos.git \
  ~/.hermes/skills/software-development/dual-wechat-macos
```

重新启动 Hermes 或打开一个新对话，然后输入：

```text
请使用 dual-wechat-macos skill，帮我创建并验证第二个微信实例，安装后启动它。
```

如果没有自动发现 Skill，可以明确指定：

```text
请读取并使用 ~/.hermes/skills/software-development/dual-wechat-macos/SKILL.md，
帮我创建 /Applications/WeChat2.app，完成签名验证后启动。
```

## 作为 Codex Skill 使用

安装到个人 Codex Skills 目录：

```bash
mkdir -p ~/.codex/skills

git clone \
  https://github.com/jiucai0915-sys/dual-wechat-macos.git \
  ~/.codex/skills/dual-wechat-macos
```

重新启动 Codex 或打开一个新任务，然后输入：

```text
使用 $dual-wechat-macos 创建并验证第二个微信实例，完成后启动 WeChat2。
```

## 验证安装结果

在仓库或 Skill 目录中执行：

```bash
bash scripts/validate-dual-wechat.sh \
  /Applications/WeChat2.app \
  com.tencent.xinWeChat2
```

正常结果应包含：

```text
PASS: bundle ID = com.tencent.xinWeChat2
PASS: deep, strict signature verification
PASS: ad-hoc signature
```

启动 WeChat2 后，验证脚本还会检查运行进程和已观察到的数据路径。独立数据目录通常包括：

```text
~/Library/Containers/com.tencent.xinWeChat2
~/Library/HTTPStorages/com.tencent.xinWeChat2
```

这些目录可能需要等待 WeChat2 第一次完成启动后才会出现。

## 自定义应用名称和 Bundle ID

可以在隔离目录生成测试副本：

```bash
bash scripts/install-dual-wechat.sh \
  --destination "$PWD/WeChatTest.app" \
  --bundle-id com.tencent.xinWeChatTest \
  --display-name WeChatTest \
  --launch
```

查看安装脚本的全部参数：

```bash
bash scripts/install-dual-wechat.sh --help
```

## 已经存在 WeChat2

安装脚本不会覆盖已经存在的目标应用。如果看到：

```text
Error: destination already exists: /Applications/WeChat2.app
```

先验证现有副本是否仍然可用：

```bash
bash scripts/validate-dual-wechat.sh \
  /Applications/WeChat2.app \
  com.tencent.xinWeChat2
```

如果确实需要重新生成，先退出 WeChat2，并将旧应用重命名为备份：

```bash
pkill -f -x '/Applications/WeChat2.app/Contents/MacOS/WeChat' || true

sudo mv \
  /Applications/WeChat2.app \
  /Applications/WeChat2.backup.app
```

然后重新运行安装脚本：

```bash
bash scripts/install-dual-wechat.sh --launch
```

确认新版本能够正常启动和登录后，再自行决定是否删除备份。

## 微信更新后的处理

官方微信更新后，`WeChat2.app` 不会自动同步原版微信的新程序文件。建议执行以下流程：

1. 退出 WeChat2。
2. 将现有 `/Applications/WeChat2.app` 重命名备份。
3. 从更新后的 `/Applications/WeChat.app` 重新运行安装脚本。
4. 重新验证 Bundle ID、签名、启动和数据路径。
5. 确认新副本工作正常后再处理备份。

## 常见问题

### Gatekeeper 阻止启动

先运行验证脚本。确认 Bundle ID 和严格签名验证均通过后，再移除本机生成副本的隔离属性：

```bash
xattr -rd com.apple.quarantine /Applications/WeChat2.app
open -n /Applications/WeChat2.app
```

也可以在 Finder 中右键 `WeChat2.app`，选择“打开”。

### 签名验证失败

不要继续使用签名损坏的副本。将其重命名备份或在确认不需要后移除，再从官方 `/Applications/WeChat.app` 重新生成。

### 找不到独立数据目录

先确保 WeChat2 已经真正启动：

```bash
pgrep -fl -x '/Applications/WeChat2.app/Contents/MacOS/WeChat'
```

完成第一次启动后，再次运行验证脚本。数据目录可能不会在进程刚出现时立即创建。

## 限制与安全说明

- 本工具只修改用户本机复制出的微信副本，不修改原版 `/Applications/WeChat.app`。
- ad-hoc 重签名会移除腾讯原始开发者签名和 entitlements。
- 主聊天实例在已验证环境中可以运行，但系统分享扩展、文件提供器、自动更新或其他依赖原签名的功能可能受限。
- 不要分发生成后的 `WeChat2.app`，也不要把微信应用包提交到本仓库。
- 不要将管理员密码、账号信息、聊天数据或其他私人文件提交到 Issue 或日志中。
- 本项目与腾讯或微信官方无关；WeChat 和微信相关商标及软件权利归其各自权利人所有。

## 仓库结构

```text
dual-wechat-macos/
├── .gitignore
├── README.md
├── SKILL.md
├── agents/
│   └── openai.yaml
└── scripts/
    ├── install-dual-wechat.sh
    └── validate-dual-wechat.sh
```

## License

本仓库目前尚未添加开源许可证。在添加明确许可证之前，默认版权规则仍然适用。
