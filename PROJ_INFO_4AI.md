# Claude Desktop Multi-Instance Project Info

## 项目概述 Project Overview

这是一个用于在 macOS 上运行多个独立 Claude Desktop 实例的工具。每个实例都有独立的配置、登录状态和 MCP 服务器设置。

This is a tool for running multiple independent Claude Desktop instances on macOS. Each instance has independent configuration, login state, and MCP server settings.

## 核心文件 Core Files

### claude_quick.sh
- **功能**: 主脚本文件，提供中英文双语界面
- **特点**: 
  - 交互式菜单和命令行两种使用方式
  - 实例管理（创建、删除、切换）
  - 应用包装器创建（独立应用图标）
  - 自动诊断和修复功能
- **注意事项**: 
  - 使用符号链接技术切换配置目录
  - 自动备份原始配置避免数据丢失
  - 包含完整的错误处理和用户引导

### README.md
- **功能**: 英文文档，包含完整的使用说明
- **内容**: 
  - 功能特性介绍
  - 安装和使用指南
  - 多种使用场景示例
  - 故障排除指南
  - 命令参考表
- **截图**: 
  - demo.png: 多窗口运行效果
  - spotlight.png: Spotlight 搜索集成效果
  - icon-name1.png/icon-name2.png: 自定义 Dock 显示名称

### README_CN.md
- **功能**: 中文文档（如果存在）
- **与英文版保持同步**

## 技术实现 Technical Implementation

### 实例隔离机制
- 使用 `~/.claude-instances/[instance_name]` 目录存储每个实例的配置
- 通过符号链接动态切换 `~/Library/Application Support/Claude` 目录
- 自动备份机制防止配置丢失

### 应用包装器（App Wrapper）
- 在 `/Applications/Claude-[instance].app` 创建独立应用
- 包含自定义 Info.plist 和启动脚本
- 支持 Spotlight 搜索和 Launchpad 启动
- 在 Dock 中显示自定义名称

### 配置管理
- 每个实例独立的 `claude_desktop_config.json`
- 支持不同的 MCP 服务器配置
- 保持独立的登录状态和聊天历史

## 目录结构 Directory Structure

```
/Users/weidwonder/softwares/claude-desktop-multi-instance/
├── claude_quick.sh              # 主脚本
├── README.md                    # 英文文档
├── README_CN.md                 # 中文文档
├── LICENSE                      # 许可证
├── .gitignore                   # Git 忽略文件
└── docs/
    └── screenshots/
        ├── demo.png             # 多窗口演示
        ├── spotlight.png        # Spotlight 搜索效果
        ├── icon-name1.png       # Dock 名称示例1
        └── icon-name2.png       # Dock 名称示例2

~/.claude-instances/             # 实例数据目录
├── [instance1]/
├── [instance2]/
└── scripts/                     # 辅助脚本

/Applications/
├── Claude.app                   # 原始应用
├── Claude-[instance1].app       # 实例1包装器
└── Claude-[instance2].app       # 实例2包装器
```

## 开发注意事项 Development Notes

### 脚本修改原则
- 保持中英文双语界面的一致性
- 所有用户可见的消息都应包含中英文
- 维护向后兼容性
- 确保错误处理的完整性

### 文档维护
- README.md 和 README_CN.md 需要保持同步
- 新增截图需要更新相应的文档说明
- 版本更新时同步更新使用说明

### 测试要点
- 多实例间的配置隔离
- 应用包装器的正确启动
- 符号链接的创建和清理
- 备份恢复机制的可靠性

## 更新历史 Update History

- 主脚本界面改为中英文双语显示
- README.md 和 README_CN.md 都增加 Spotlight 搜索功能说明
- 添加 spotlight.png 截图展示
- 完善应用包装器的说明文档
- 中英文文档保持同步更新
- 完成脚本所有用户交互提示的双语化
- 在两个文档之间添加相互引用，方便用户切换语言
