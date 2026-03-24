# 欧路词典剪贴板查词工具（MVP）

这是一个 Windows 小工具。启动后会监听剪贴板，当你复制单个英文单词时，自动调用欧路词典迷你查词窗口。

## 1. MVP 功能

- 监听系统剪贴板变化
- 仅处理单个英文单词（`^[A-Za-z]{1,40}$`）
- 自动调用 `eudic://lp-dict/<word>`
- 基础防抖（默认 500ms）与同词去重（默认 1500ms）

## 2. 运行要求

- Windows 10 或 Windows 11
- 已安装欧路词典，且 URL Scheme 可用
- 已安装 AutoHotkey v2

注意：

- 本项目脚本使用的是 AutoHotkey v2 语法，不能用 v1 运行

建议先手工验证协议：

1. 按 `Win + R`
2. 输入 `eudic://lp-dict/test`
3. 如果能弹出欧路词典迷你查词窗口，说明协议正常

## 3. 文件说明

- `EudicClipboardHelper.ahk`：主脚本
- `run.bat`：双击启动入口
- `EudicClipboardHelper.log`：运行日志，启动和调用失败时会记录

## 4. 启动方式

方式 A（推荐）：

1. 双击 `run.bat`
2. 脚本启动后会在后台运行

方式 B：

1. 用 AutoHotkey v2 直接运行 `EudicClipboardHelper.ahk`

## 5. 快速测试（MVP）

1. 启动脚本
2. 复制 `apple`，预期 1 秒内弹出欧路词典迷你查词
3. 复制 `你好`，预期不触发
4. 复制 `hello,`，预期不触发
5. 连续两次复制 `apple`，预期不会短时间连续弹窗

## 6. 常见问题

### 双击 `run.bat` 没反应

- 请确认安装的是 AutoHotkey v2
- 请确认 `EudicClipboardHelper.ahk` 与 `run.bat` 在同一目录

### 能启动脚本，但不弹欧路词典

- 请先验证 `eudic://lp-dict/test` 是否能拉起欧路词典
- 检查欧路词典版本是否支持 URL Scheme
- 检查复制内容是否是单个英文单词

### 复制后弹窗太频繁

- MVP 已内置防抖和去重
- 如仍需更强控制，可在后续版本增加开关和白名单应用

## 7. 当前限制

- 仅支持 Windows
- 仅支持复制即触发模式
- 暂无图形界面和托盘设置页
