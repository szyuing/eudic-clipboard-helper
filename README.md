# 欧路词典剪贴板查词工具

这是一个 Windows 小工具。启动后会监听剪贴板，当你复制单个英文单词时，自动调用欧路词典迷你查词窗口。

## 一条命令安装

在 PowerShell 里直接执行：

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; irm https://raw.githubusercontent.com/szyuing/eudic-clipboard-helper/main/install.ps1 | iex
```

安装器会自动完成这些事情：

- 检测并安装 AutoHotkey v2
- 检测并安装欧路词典
- 下载本项目到本地
- 启动剪贴板查词助手
- 设置开机自启动

## 功能

- 监听系统剪贴板变化
- 仅处理单个英文单词（`^[A-Za-z]{1,40}$`）
- 自动调用 `eudic://lp-dict/<word>`
- 基础防抖（默认 500ms）与同词去重（默认 1500ms）
- 安装后自动开机自启动

## 运行要求

- Windows 10 或 Windows 11
- 可访问 GitHub Raw 和 `winget`
- 建议使用 PowerShell

## 本地安装位置

安装器默认把文件放到：

```text
%LOCALAPPDATA%\EudicClipboardHelper
```

开机自启动通过 Windows Startup 快捷方式完成。

## 手动启动

如果你已经下载了仓库，也可以直接：

1. 双击 `run.bat`
2. 或用 AutoHotkey v2 运行 `EudicClipboardHelper.ahk`

## 快速测试

1. 安装完成后复制 `apple`
2. 预期 1 秒内弹出欧路词典迷你查词
3. 复制 `你好`，预期不触发
4. 复制 `hello,`，预期不触发

## 常见问题

### 安装器提示找不到 winget

- 先安装 Microsoft Store 里的 App Installer

### 安装后不弹欧路词典

- 先确认欧路词典已安装成功
- 按 `Win + R` 输入 `eudic://lp-dict/test`
- 如果这里也打不开，说明欧路词典协议没有注册成功

### 想取消开机自启动

- 删除启动目录里的 `Eudic Clipboard Helper.lnk`
- 或删除 `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup` 中对应快捷方式

## 文件说明

- `install.ps1`：一键安装脚本
- `EudicClipboardHelper.ahk`：主脚本
- `run.bat`：手动启动入口
- `remand.md`：项目说明与宣传文案
