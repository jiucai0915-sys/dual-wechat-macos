---
name: dual-wechat-macos
description: 在 macOS 上创建、验证和启动第二个独立微信应用实例。用户要求双开微信、制作 WeChat2.app、修改微信 Bundle ID、重新签名微信副本，或排查双开微信签名与数据目录问题时使用。
---

# macOS 双开微信

通过复制官方 `WeChat.app`、修改主应用 Bundle ID、执行 ad-hoc 重签名，创建可独立启动的第二个微信应用。不要分发修改后的微信应用包；只在用户本机从其已安装的官方微信生成副本。

## 安全原则

- 先验证源应用位于 `/Applications/WeChat.app`，再执行任何复制或签名操作。
- 默认使用 `/Applications/WeChat2.app`、Bundle ID `com.tencent.xinWeChat2` 和显示名 `WeChat2`。
- 目标应用已存在时停止，不要擅自删除或覆盖。先让用户备份、重命名或明确处理旧副本。
- 不要读取、保存或传递管理员密码。让 `sudo` 在终端中正常提示。
- 使用 `ditto --noextattr --noacl` 复制应用，避免把原应用的 ACL 和扩展属性带入可修改副本。
- 不要修改或删除原版 `/Applications/WeChat.app`。

## 创建第二个微信

优先执行随附脚本，避免手工步骤遗漏：

```bash
bash scripts/install-dual-wechat.sh
```

脚本会执行以下流程：

1. 检查 macOS、源应用和必需系统工具。
2. 在临时目录复制官方微信。
3. 把主应用的 Bundle ID 改为 `com.tencent.xinWeChat2`，显示名改为 `WeChat2`。
4. 清除旧签名和扩展属性，然后进行深度 ad-hoc 重签名。
5. 严格验证临时副本后，再部署到 `/Applications/WeChat2.app`。
6. 再次验证部署结果。默认不自动启动。

需要安装后启动时执行：

```bash
bash scripts/install-dual-wechat.sh --launch
```

需要在隔离目录测试或使用其他名称时，显式传参：

```bash
bash scripts/install-dual-wechat.sh \
  --destination "$PWD/WeChatTest.app" \
  --bundle-id com.tencent.xinWeChatTest \
  --display-name WeChatTest \
  --launch
```

## 验证现有副本

先运行静态验证：

```bash
bash scripts/validate-dual-wechat.sh /Applications/WeChat2.app com.tencent.xinWeChat2
```

再启动并确认进程：

```bash
open -n /Applications/WeChat2.app
pgrep -fl -x '/Applications/WeChat2.app/Contents/MacOS/WeChat'
```

再次运行验证脚本。运行后的输出应满足：

- Bundle ID 为 `com.tencent.xinWeChat2`。
- `codesign --verify --deep --strict` 通过。
- 签名为 ad-hoc，且没有 TeamIdentifier。
- 进程路径位于 `/Applications/WeChat2.app/Contents/MacOS/WeChat`。
- 数据路径使用 `~/Library/Containers/com.tencent.xinWeChat2` 或 `~/Library/HTTPStorages/com.tencent.xinWeChat2`。目录可能要等应用首次完成启动后才出现。

## 使用与维护

直接启动第二个实例：

```bash
open -n /Applications/WeChat2.app
```

微信更新后，原版和副本不会自动保持二进制一致。先退出第二个实例并备份需要保留的内容，再从新版官方微信重新生成副本。

ad-hoc 重签名会移除腾讯开发者签名和原有 entitlements。主聊天实例在已验证版本上可以运行，但系统分享扩展、文件提供器、自动更新或其他依赖原签名的集成功能可能受限。不要承诺未来微信版本必然兼容；每次大版本更新后重新完成复制、签名、严格校验和启动测试。

若 Gatekeeper 阻止本机生成的副本，先确认路径和签名验证结果正确，再移除该副本的隔离属性：

```bash
xattr -rd com.apple.quarantine /Applications/WeChat2.app
```

该流程已在 macOS 26.4（Tahoe）、Apple Silicon、微信 4.1.10 上完成复制、重签名、严格签名校验、启动和独立数据路径验证。
