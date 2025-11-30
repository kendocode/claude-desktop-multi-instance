#!/bin/bash

# Claude Desktop 快速启动脚本 Quick Launch Script
# 使用方法 Usage: 
#   ./claude_quick.sh                    # 显示菜单 Show menu
#   ./claude_quick.sh [实例名称]          # 启动指定实例 Launch instance
#   ./claude_quick.sh delete [实例名]     # 删除指定实例 Delete instance
#   ./claude_quick.sh wrapper [实例名]    # 为实例创建应用包装器 Create app wrapper
#   ./claude_quick.sh list               # 列出所有实例 List instances
#   ./claude_quick.sh diagnose           # 诊断问题 Diagnose issues
#   ./claude_quick.sh fix                # 修复包装器 Fix wrappers
#   ./claude_quick.sh restore            # 恢复原始配置 Restore config

CLAUDE_INSTANCES_BASE="$HOME/.claude-instances"
ORIGINAL_CLAUDE_DIR="$HOME/Library/Application Support/Claude"

# ==================== 函数定义 ====================

# 恢复原始配置函数 Restore Original Config Function
restore_original_config() {
    echo "🔄 恢复 Claude 原始配置 Restoring Claude original config..."
    
    # 删除符号链接
    if [ -L "$ORIGINAL_CLAUDE_DIR" ]; then
        rm "$ORIGINAL_CLAUDE_DIR"
        echo "✅ 删除符号链接 Deleted symbolic link"
    fi
    
    # 恢复最新备份
    LATEST_BACKUP=$(ls -t "$ORIGINAL_CLAUDE_DIR.backup."* 2>/dev/null | head -n 1)
    if [ -n "$LATEST_BACKUP" ]; then
        mv "$LATEST_BACKUP" "$ORIGINAL_CLAUDE_DIR"
        echo "✅ 配置已恢复: $(basename "$LATEST_BACKUP")"
    else
        echo "⚠️  未找到备份文件"
        # 创建最小配置
        mkdir -p "$ORIGINAL_CLAUDE_DIR"
        echo '{"mcpServers": {}}' > "$ORIGINAL_CLAUDE_DIR/claude_desktop_config.json"
        echo "✅ 创建基础配置"
    fi
}

# 删除实例菜单 Delete Instance Menu
delete_instance_menu() {
    echo ""
    echo "🗑️  删除实例 Delete Instance"
    echo "============"
    
    if [ ! -d "$CLAUDE_INSTANCES_BASE" ]; then
        echo "❌ 未找到任何实例 No instances found"
        return
    fi
    
    echo "现有实例 Existing instances:"
    ls -1 "$CLAUDE_INSTANCES_BASE" 2>/dev/null | grep -v "^scripts$" | sed 's/^/  - /' | nl
    
    echo ""
    read -p "输入要删除的实例名称 Enter instance name to delete: " instance_to_delete
    
    if [ -z "$instance_to_delete" ]; then
        echo "❌ 实例名称不能为空 Instance name cannot be empty"
        return
    fi
    
    if [ "$instance_to_delete" = "scripts" ]; then
        echo "❌ 不能删除 scripts 目录 Cannot delete scripts directory"
        return
    fi
    
    if [ ! -d "$CLAUDE_INSTANCES_BASE/$instance_to_delete" ]; then
        echo "❌ 实例 '$instance_to_delete' 不存在 Instance '$instance_to_delete' does not exist"
        return
    fi
    
    echo ""
    echo "⚠️  将要删除实例 Will delete instance: $instance_to_delete"
    echo "这将删除以下内容 This will delete the following content:"
    echo "  - 实例配置目录 Instance config directory: $CLAUDE_INSTANCES_BASE/$instance_to_delete"
    echo "  - 应用包装器 App wrapper (如果存在 if exists): /Applications/Claude-$instance_to_delete.app"
    echo ""
    read -p "确认删除 Confirm deletion? (yes/NO): " confirm
    
    if [ "$confirm" != "yes" ] && [ "$confirm" != "YES" ]; then
        echo "❌ 取消删除 Deletion cancelled"
        return
    fi
    
    echo ""
    echo "🗑️  正在删除实例 Deleting instance: $instance_to_delete"
    
    # 删除实例目录
    if [ -d "$CLAUDE_INSTANCES_BASE/$instance_to_delete" ]; then
        rm -rf "$CLAUDE_INSTANCES_BASE/$instance_to_delete"
        echo "✅ 删除实例目录 Deleted instance directory"
    fi
    
    # 删除应用包装器
    if [ -d "/Applications/Claude-$instance_to_delete.app" ]; then
        rm -rf "/Applications/Claude-$instance_to_delete.app"
        echo "✅ 删除应用包装器 Deleted app wrapper"
    fi
    
    echo "✅ 实例 '$instance_to_delete' 删除完成 Instance '$instance_to_delete' deletion completed"
}

# 复制 Claude 图标
copy_claude_icon() {
    local target_dir="$1"
    local icon_copied=false
    
    echo "🔍 查找 Claude 图标..."
    
    # 首先查找所有可能的图标文件
    local found_icons=$(find "/Applications/Claude.app" -name "*.icns" -type f 2>/dev/null)
    
    if [ -n "$found_icons" ]; then
        echo "📂 找到的图标文件:"
        echo "$found_icons"
        
        # 使用找到的第一个图标
        local first_icon=$(echo "$found_icons" | head -n 1)
        cp "$first_icon" "$target_dir/claude-icon.icns"
        echo "✅ 复制图标: $(basename "$first_icon")"
        icon_copied=true
    else
        # 尝试预定义的图标位置
        for icon_path in \
            "/Applications/Claude.app/Contents/Resources/AppIcon.icns" \
            "/Applications/Claude.app/Contents/Resources/claude.icns" \
            "/Applications/Claude.app/Contents/Resources/icon.icns" \
            "/Applications/Claude.app/Contents/Resources/app.icns" \
            "/Applications/Claude.app/Contents/Resources/Assets.car"; do
            
            if [ -f "$icon_path" ]; then
                cp "$icon_path" "$target_dir/claude-icon.icns"
                echo "✅ 复制图标: $(basename "$icon_path")"
                icon_copied=true
                break
            fi
        done
    fi
    
    if [ "$icon_copied" = false ]; then
        echo "⚠️  未找到 Claude 图标，检查可用图标:"
        ls -la "/Applications/Claude.app/Contents/Resources/" | grep -E "\.(icns|png|jpg)$" || echo "   无图标文件"
        
        # 创建一个简单的默认图标占位符
        echo "🎨 创建默认图标占位符"
        touch "$target_dir/claude-icon.icns"
    fi
}

# 创建应用包装器函数
create_app_wrapper() {
    local instance_name="$1"
    local display_name="$2"
    local wrapper_path="/Applications/Claude-$instance_name.app"
    
    # 检查是否已存在
    if [ -d "$wrapper_path" ]; then
        echo "⚠️  应用包装器已存在: $wrapper_path"
        read -p "是否覆盖? (y/N): " overwrite
        if [ "$overwrite" != "y" ] && [ "$overwrite" != "Y" ]; then
            echo "❌ 取消创建"
            return
        fi
        rm -rf "$wrapper_path"
    fi
    
    # 创建应用包结构
    mkdir -p "$wrapper_path/Contents/MacOS"
    mkdir -p "$wrapper_path/Contents/Resources"
    
    # 创建 Info.plist
    cat > "$wrapper_path/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>claude-launcher</string>
    <key>CFBundleIdentifier</key>
    <string>com.anthropic.claude.$instance_name</string>
    <key>CFBundleName</key>
    <string>$display_name</string>
    <key>CFBundleDisplayName</key>
    <string>$display_name</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>11.0</string>
    <key>CFBundleIconFile</key>
    <string>claude-icon</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF
    
    # 创建启动脚本
    cat > "$wrapper_path/Contents/MacOS/claude-launcher" << 'LAUNCHER_EOF'
#!/bin/bash

# 从应用包名提取实例名称
# $0 = /Applications/Claude-default.app/Contents/MacOS/claude-launcher
# 需要向上三层目录到应用包，然后提取名称
APP_PATH=$(dirname "$(dirname "$(dirname "$0")")")
APP_NAME=$(basename "$APP_PATH")
INSTANCE_NAME=${APP_NAME#Claude-}
INSTANCE_NAME=${INSTANCE_NAME%.app}

CLAUDE_INSTANCES_BASE="$HOME/.claude-instances"
INSTANCE_DIR="$CLAUDE_INSTANCES_BASE/$INSTANCE_NAME"
ORIGINAL_CLAUDE_DIR="$HOME/Library/Application Support/Claude"

echo "🚀 启动 Claude 实例: $INSTANCE_NAME"
echo "📂 应用路径: $APP_PATH"
echo "📁 实例目录: $INSTANCE_DIR"

# 确保实例目录存在
if [ ! -d "$INSTANCE_DIR" ]; then
    echo "❌ 实例目录不存在: $INSTANCE_DIR"
    echo "可用实例:"
    ls -1 "$CLAUDE_INSTANCES_BASE" 2>/dev/null | grep -v "^scripts$" | sed 's/^/  - /' || echo "  (无)"
    
    osascript -e "display dialog \"实例 '$INSTANCE_NAME' 不存在！

可用实例: $(ls -1 "$CLAUDE_INSTANCES_BASE" 2>/dev/null | grep -v "^scripts$" | tr '\n' ' ')

请先使用 claude_quick.sh 创建实例或检查实例名称。\" buttons {\"确定\"} with icon stop"
    exit 1
fi

# 检查 Claude.app 是否存在
if [ ! -d "/Applications/Claude.app" ]; then
    echo "❌ Claude Desktop 未安装在 /Applications/Claude.app"
    osascript -e "display dialog \"未找到 Claude Desktop！请确保已正确安装 Claude Desktop 到 Applications 文件夹。\" buttons {\"确定\"} with icon stop"
    exit 1
fi

# 查找 Claude 的可执行文件
CLAUDE_EXECUTABLE=""
for exec_path in \
    "/Applications/Claude.app/Contents/MacOS/Claude" \
    "/Applications/Claude.app/Contents/MacOS/claude" \
    "/Applications/Claude.app/Contents/MacOS/Claude Desktop" \
    "/Applications/Claude.app/Contents/MacOS/Claude.app"; do
    
    if [ -x "$exec_path" ]; then
        CLAUDE_EXECUTABLE="$exec_path"
        break
    fi
done

if [ -z "$CLAUDE_EXECUTABLE" ]; then
    echo "❌ 未找到 Claude 可执行文件"
    echo "可用文件:"
    ls -la "/Applications/Claude.app/Contents/MacOS/"
    
    osascript -e "display dialog \"未找到 Claude 可执行文件！请检查 Claude Desktop 安装。\" buttons {\"确定\"} with icon stop"
    exit 1
fi

echo "📱 使用可执行文件: $CLAUDE_EXECUTABLE"

# 备份当前配置
if [ -d "$ORIGINAL_CLAUDE_DIR" ] && [ ! -L "$ORIGINAL_CLAUDE_DIR" ]; then
    TIMESTAMP=$(date +%s)
    mv "$ORIGINAL_CLAUDE_DIR" "$ORIGINAL_CLAUDE_DIR.backup.$TIMESTAMP"
    echo "💾 备份原始配置"
fi

# 删除旧的符号链接
if [ -L "$ORIGINAL_CLAUDE_DIR" ]; then
    rm "$ORIGINAL_CLAUDE_DIR"
fi

# 创建新的符号链接
ln -sf "$INSTANCE_DIR/Application Support/Claude" "$ORIGINAL_CLAUDE_DIR"
echo "🔗 配置已切换到实例: $INSTANCE_NAME"

# 启动原始 Claude 应用
# 使用 open -n 而不是 exec 来避免继承包装器的架构上下文
# Use open -n instead of exec to avoid inheriting wrapper's architecture context
echo "▶️  启动 Claude Desktop..."
open -n "/Applications/Claude.app"
LAUNCHER_EOF
    
    chmod +x "$wrapper_path/Contents/MacOS/claude-launcher"
    echo "✅ 设置启动脚本执行权限"

    # 复制图标
    copy_claude_icon "$wrapper_path/Contents/Resources"

    # Ad-hoc 代码签名 (防止 Launch Services 错误和 Rosetta 提示)
    # Ad-hoc code signing (prevents Launch Services errors and Rosetta prompts)
    if codesign --force --deep --sign - "$wrapper_path" 2>/dev/null; then
        echo "✅ 应用包装器已签名 App wrapper signed"
    else
        echo "⚠️  代码签名失败，可能需要手动签名 Code signing failed, may need manual signing"
        echo "   运行 Run: codesign --force --deep --sign - \"$wrapper_path\""
    fi
    
    echo "✅ 应用包装器创建完成!"
    echo "📱 应用路径: $wrapper_path"
    echo "🔍 在 Launchpad 中搜索: $display_name"
    echo ""
    echo "💡 提示:"
    echo "  - 现在可以从 Launchpad 直接启动 '$display_name'"
    echo "  - 在 Dock 中会显示为 '$display_name' 而不是 'Claude'"
    echo "  - 可以将其拖到 Dock 中作为快捷方式"
}

# 创建应用包装器菜单 Create App Wrapper Menu
create_app_wrapper_menu() {
    echo ""
    echo "📱 创建应用包装器 Create App Wrapper"
    echo "=================="
    echo "这将为实例创建独立的应用图标，在 Dock 中显示自定义名称"
    echo "This creates independent app icons and custom names in Dock"
    echo ""
    
    if [ ! -d "$CLAUDE_INSTANCES_BASE" ]; then
        echo "❌ 未找到任何实例，请先创建实例 No instances found, please create an instance first"
        return
    fi
    
    echo "现有实例 Existing instances:"
    ls -1 "$CLAUDE_INSTANCES_BASE" 2>/dev/null | grep -v "^scripts$" | sed 's/^/  - /' | nl
    
    echo ""
    read -p "为哪个实例创建应用包装器 Create app wrapper for which instance: " instance_name
    
    if [ -z "$instance_name" ]; then
        echo "❌ 实例名称不能为空 Instance name cannot be empty"
        return
    fi
    
    if [ "$instance_name" = "scripts" ]; then
        echo "❌ scripts 不是有效的实例名称 'scripts' is not a valid instance name"
        return
    fi
    
    if [ ! -d "$CLAUDE_INSTANCES_BASE/$instance_name" ]; then
        echo "❌ 实例 '$instance_name' 不存在 Instance '$instance_name' does not exist"
        return
    fi
    
    # 默认显示名称
    default_display_name="Claude $(echo "$instance_name" | sed 's/.*/\L&/' | sed 's/\b\w/\U&/g')"
    read -p "应用显示名称 App display name [$default_display_name]: " display_name
    
    if [ -z "$display_name" ]; then
        display_name="$default_display_name"
    fi
    
    echo ""
    echo "🔨 创建应用包装器..."
    echo "  实例: $instance_name"
    echo "  显示名称: $display_name"
    
    create_app_wrapper "$instance_name" "$display_name"
}

# 创建快速切换脚本
create_quick_scripts() {
    local current_instance="$1"
    local scripts_dir="$CLAUDE_INSTANCES_BASE/scripts"
    
    mkdir -p "$scripts_dir"
    
    # 创建恢复脚本
    cat > "$scripts_dir/restore.sh" << 'EOF'
#!/bin/bash
ORIGINAL_CLAUDE_DIR="$HOME/Library/Application Support/Claude"
if [ -L "$ORIGINAL_CLAUDE_DIR" ]; then
    rm "$ORIGINAL_CLAUDE_DIR"
fi
LATEST_BACKUP=$(ls -t "$ORIGINAL_CLAUDE_DIR.backup."* 2>/dev/null | head -n 1)
if [ -n "$LATEST_BACKUP" ]; then
    mv "$LATEST_BACKUP" "$ORIGINAL_CLAUDE_DIR"
    echo "✅ Claude 配置已恢复"
else
    mkdir -p "$ORIGINAL_CLAUDE_DIR"
    echo '{"mcpServers": {}}' > "$ORIGINAL_CLAUDE_DIR/claude_desktop_config.json"
    echo "✅ 创建基础配置"
fi
EOF
    
    chmod +x "$scripts_dir/restore.sh"
    
    # 创建实例列表脚本
    cat > "$scripts_dir/list.sh" << 'EOF'
#!/bin/bash
echo "Claude Desktop 实例管理器"
echo "========================="
echo ""

# 列出所有实例
echo "📁 可用实例:"
instance_count=0
for dir in "$HOME/.claude-instances"/*/; do
    if [ -d "$dir" ]; then
        instance_name=$(basename "$dir")
        
        # 跳过 scripts 目录
        if [ "$instance_name" = "scripts" ]; then
            continue
        fi
        
        config_file="$dir/Application Support/Claude/claude_desktop_config.json"
        
        # 检查是否有应用包装器
        if [ -d "/Applications/Claude-$instance_name.app" ]; then
            wrapper_status="📱 有包装器"
        else
            wrapper_status="   无包装器"
        fi
        
        if [ -f "$config_file" ]; then
            mcp_servers=$(grep -c '"[^"]*".*:' "$config_file" 2>/dev/null || echo "0")
            echo "   $instance_name ($wrapper_status, MCP服务器: $mcp_servers)"
        else
            echo "   $instance_name ($wrapper_status, 未配置)"
        fi
        instance_count=$((instance_count + 1))
    fi
done

if [ $instance_count -eq 0 ]; then
    echo "   (暂无实例)"
fi

echo ""
echo "📱 应用包装器:"
wrapper_count=0
for app in /Applications/Claude-*.app; do
    if [ -d "$app" ]; then
        app_name=$(basename "$app" .app)
        instance_name=${app_name#Claude-}
        
        # 读取显示名称
        if [ -f "$app/Contents/Info.plist" ]; then
            display_name=$(plutil -extract CFBundleDisplayName raw "$app/Contents/Info.plist" 2>/dev/null || echo "$app_name")
        else
            display_name="$app_name"
        fi
        
        echo "   $display_name -> $instance_name"
        wrapper_count=$((wrapper_count + 1))
    fi
done

if [ $wrapper_count -eq 0 ]; then
    echo "   (暂无应用包装器)"
fi

echo ""
echo "💡 使用说明:"
echo "   - 运行 claude_quick.sh 启动实例"
echo "   - 有包装器的实例可以直接从 Launchpad 启动"
echo "   - 在 Dock 中会显示自定义名称而不是 'Claude'"
EOF
    
    chmod +x "$scripts_dir/list.sh"
    
    echo "🛠️  快速脚本已创建:"
    echo "   - 恢复配置: $scripts_dir/restore.sh"
    echo "   - 实例管理: $scripts_dir/list.sh"
    echo ""
    echo "⚡ 快捷命令:"
    echo "   - $0 list                    # 列出所有实例"
    echo "   - $0 delete [实例名]         # 删除实例"
    echo "   - $0 wrapper [实例名]        # 创建应用包装器"
    echo "   - $0 diagnose                # 诊断问题"
    echo "   - $0 fix                     # 修复包装器"
    echo "   - $0 restore                 # 恢复原始配置"
}

# 启动实例函数 Launch Instance Function
launch_instance() {
    local instance_name="$1"
    local instance_dir="$CLAUDE_INSTANCES_BASE/$instance_name"
    
    echo ""
    echo "🚀 启动 Claude Desktop 实例 Launch Claude Desktop instance: $instance_name"
    
    # 创建实例目录
    mkdir -p "$instance_dir/Application Support/Claude"
    mkdir -p "$instance_dir/Preferences"
    mkdir -p "$instance_dir/Caches"
    
    # 初始化配置文件
    if [ ! -f "$instance_dir/Application Support/Claude/claude_desktop_config.json" ]; then
        echo "📄 初始化配置文件 Initialize configuration file..."
        
        # 如果存在原始配置，复制它
        if [ -f "$ORIGINAL_CLAUDE_DIR/claude_desktop_config.json" ]; then
            cp "$ORIGINAL_CLAUDE_DIR/claude_desktop_config.json" "$instance_dir/Application Support/Claude/"
            echo "✅ 复制默认配置 Copy default configuration"
        else
            # 创建基础配置
            cat > "$instance_dir/Application Support/Claude/claude_desktop_config.json" << 'EOF'
{
  "mcpServers": {}
}
EOF
            echo "✅ 创建基础配置 Create basic configuration"
        fi
    fi
    
    # 备份当前配置
    if [ -d "$ORIGINAL_CLAUDE_DIR" ] && [ ! -L "$ORIGINAL_CLAUDE_DIR" ]; then
        TIMESTAMP=$(date +%s)
        BACKUP_DIR="$ORIGINAL_CLAUDE_DIR.backup.$TIMESTAMP"
        mv "$ORIGINAL_CLAUDE_DIR" "$BACKUP_DIR"
        echo "💾 备份原始配置: $(basename "$BACKUP_DIR")"
    fi
    
    # 删除旧的符号链接
    if [ -L "$ORIGINAL_CLAUDE_DIR" ]; then
        rm "$ORIGINAL_CLAUDE_DIR"
    fi
    
    # 创建新的符号链接
    ln -sf "$instance_dir/Application Support/Claude" "$ORIGINAL_CLAUDE_DIR"
    echo "🔗 创建配置链接"
    
    # 启动 Claude Desktop
    echo "▶️  启动 Claude Desktop Launch Claude Desktop..."
    open -n "/Applications/Claude.app"
    
    echo ""
    echo "✅ Claude Desktop 已启动 Claude Desktop has been launched!"
    echo "📂 实例配置目录 Instance config directory: $instance_dir"
    echo "⚙️  配置文件 Configuration file: $instance_dir/Application Support/Claude/claude_desktop_config.json"
    echo ""
    
    # 询问是否创建应用包装器
    if [ ! -d "/Applications/Claude-$instance_name.app" ]; then
        echo "💡 提示 Tip: 可以为此实例创建应用包装器 You can create an app wrapper for this instance"
        echo "   这样在 Dock 中会显示为 'Claude $instance_name' 而不是 'Claude'"
        echo "   This way it will show as 'Claude $instance_name' instead of 'Claude' in Dock"
        read -p "现在创建应用包装器吗 Create app wrapper now? (y/N): " create_wrapper
        
        if [ "$create_wrapper" = "y" ] || [ "$create_wrapper" = "Y" ]; then
            default_name="Claude $(echo "$instance_name" | sed 's/.*/\L&/' | sed 's/\b\w/\U&/g')"
            read -p "应用显示名称 App display name [$default_name]: " display_name
            if [ -z "$display_name" ]; then
                display_name="$default_name"
            fi
            
            echo ""
            create_app_wrapper "$instance_name" "$display_name"
        fi
    fi
    
    echo ""
    echo "💡 使用提示 Usage Tips:"
    echo "   - 关闭 Claude 后运行 '$0' 选择选项 6 恢复原始配置"
    echo "     After closing Claude, run '$0' and select option 6 to restore original config"
    echo "   - 或运行 '$0 [其他实例名]' 切换到其他实例"
    echo "     Or run '$0 [other_instance_name]' to switch to other instance"
    echo "   - 每个实例可以有独立的 MCP 服务器配置"
    echo "     Each instance can have independent MCP server configurations"
    
    # 创建快速切换脚本
    create_quick_scripts "$instance_name"
}

# ==================== 主程序逻辑 ====================

# 显示横幅 Display Banner
echo "======================================"
echo "    Claude Desktop 快速启动器"
echo "    Claude Desktop Quick Launcher"
echo "======================================"

# 检查 Claude 是否已安装
if [ ! -d "/Applications/Claude.app" ]; then
    echo "❌ 错误 Error: 未找到 Claude Desktop 应用 Claude Desktop app not found"
    echo "请先从 https://claude.ai/download 下载并安装 Claude Desktop"
    echo "Please download and install Claude Desktop from https://claude.ai/download first"
    exit 1
fi

# 处理特殊命令
case "$1" in
    "delete")
        if [ -n "$2" ]; then
            # 直接删除指定实例
            INSTANCE_TO_DELETE="$2"
            
            if [ "$INSTANCE_TO_DELETE" = "scripts" ]; then
                echo "❌ 不能删除 scripts 目录 Cannot delete scripts directory"
                exit 1
            fi
            
            echo "🗑️  删除实例 Delete instance: $INSTANCE_TO_DELETE"
            
            if [ ! -d "$CLAUDE_INSTANCES_BASE/$INSTANCE_TO_DELETE" ]; then
                echo "❌ 实例 '$INSTANCE_TO_DELETE' 不存在 Instance '$INSTANCE_TO_DELETE' does not exist"
                exit 1
            fi
            
            echo "⚠️  确认删除实例 Confirm deletion of instance '$INSTANCE_TO_DELETE'? (yes/NO):"
            read -p "> " confirm
            
            if [ "$confirm" = "yes" ] || [ "$confirm" = "YES" ]; then
                rm -rf "$CLAUDE_INSTANCES_BASE/$INSTANCE_TO_DELETE"
                [ -d "/Applications/Claude-$INSTANCE_TO_DELETE.app" ] && rm -rf "/Applications/Claude-$INSTANCE_TO_DELETE.app"
                echo "✅ 实例 '$INSTANCE_TO_DELETE' 已删除 Instance '$INSTANCE_TO_DELETE' deleted"
            else
                echo "❌ 取消删除 Deletion cancelled"
            fi
        else
            delete_instance_menu
        fi
        exit 0
        ;;
    "wrapper")
        if [ -n "$2" ]; then
            # 为指定实例创建包装器
            INSTANCE_FOR_WRAPPER="$2"
            if [ ! -d "$CLAUDE_INSTANCES_BASE/$INSTANCE_FOR_WRAPPER" ]; then
                echo "❌ 实例 '$INSTANCE_FOR_WRAPPER' 不存在 Instance '$INSTANCE_FOR_WRAPPER' does not exist"
                exit 1
            fi
            
            default_name="Claude $(echo "$INSTANCE_FOR_WRAPPER" | sed 's/.*/\L&/' | sed 's/\b\w/\U&/g')"
            echo "为实例 '$INSTANCE_FOR_WRAPPER' 创建应用包装器 Create app wrapper for instance '$INSTANCE_FOR_WRAPPER'"
            read -p "显示名称 Display name [$default_name]: " display_name
            if [ -z "$display_name" ]; then
                display_name="$default_name"
            fi
            
            create_app_wrapper "$INSTANCE_FOR_WRAPPER" "$display_name"
        else
            create_app_wrapper_menu
        fi
        exit 0
        ;;
    "list")
        # 运行列表脚本
        if [ -f "$CLAUDE_INSTANCES_BASE/scripts/list.sh" ]; then
            "$CLAUDE_INSTANCES_BASE/scripts/list.sh"
        else
            echo "Claude Desktop 实例列表 Instance List:"
            echo "========================"
            ls -1 "$CLAUDE_INSTANCES_BASE" 2>/dev/null | grep -v "^scripts$" | sed 's/^/  - /' || echo "  (暂无实例 No instances)"
        fi
        exit 0
        ;;
    "diagnose"|"debug")
        # 诊断模式
        echo "🔍 Claude Desktop 诊断"
        echo "======================"
        echo ""
        
        echo "1. 检查 Claude Desktop 安装:"
        if [ -d "/Applications/Claude.app" ]; then
            echo "   ✅ Claude.app 存在"
            
            echo ""
            echo "2. 检查可执行文件:"
            ls -la "/Applications/Claude.app/Contents/MacOS/"
            
            echo ""
            echo "3. 检查图标文件:"
            find "/Applications/Claude.app" -name "*.icns" -type f 2>/dev/null || echo "   ⚠️  未找到 .icns 图标文件"
            
            echo ""
            echo "4. 检查应用包装器:"
            for app in /Applications/Claude-*.app; do
                if [ -d "$app" ]; then
                    echo "   📱 $app"
                    echo "      可执行权限: $(ls -la "$app/Contents/MacOS/"* 2>/dev/null | awk '{print $1}' || echo '未找到')"
                fi
            done
            
        else
            echo "   ❌ Claude.app 不存在"
            echo "   请从 https://claude.ai/download 下载并安装 Claude Desktop"
        fi
        
        echo ""
        echo "5. 检查实例目录:"
        if [ -d "$CLAUDE_INSTANCES_BASE" ]; then
            ls -la "$CLAUDE_INSTANCES_BASE"
        else
            echo "   📁 暂无实例目录"
        fi
        
        exit 0
        ;;
    "fix"|"repair")
        # 修复模式
        echo "🔧 修复 Claude Desktop 包装器"
        echo "============================="
        
        for app in /Applications/Claude-*.app; do
            if [ -d "$app" ]; then
                echo "🔨 修复 Repairing: $app"
                
                # 确保启动脚本有执行权限
                launcher="$app/Contents/MacOS/claude-launcher"
                if [ -f "$launcher" ]; then
                    chmod +x "$launcher"
                    echo "   ✅ 设置启动脚本执行权限 Set launcher script executable permissions"
                else
                    echo "   ❌ 启动脚本不存在 Launcher script not found: $launcher"
                fi
                
                # 检查并修复图标
                if [ ! -f "$app/Contents/Resources/claude-icon.icns" ]; then
                    echo "   🎨 修复图标..."
                    copy_claude_icon "$app/Contents/Resources"
                fi

                # 检查并修复代码签名
                if ! codesign -v "$app" 2>/dev/null; then
                    echo "   🔐 添加代码签名..."
                    if codesign --force --deep --sign - "$app" 2>/dev/null; then
                        echo "   ✅ 代码签名已添加 Code signature added"
                    else
                        echo "   ⚠️  代码签名失败 Code signing failed"
                    fi
                else
                    echo "   ✅ 代码签名正常 Code signature OK"
                fi
            fi
        done

        echo "✅ 修复完成"
        exit 0
        ;;
    "restore"|"reset")
        restore_original_config
        exit 0
        ;;
esac

INSTANCE_NAME="${1:-default}"

# 如果没有指定实例名，显示菜单
if [ "$1" = "" ]; then
    echo ""
    echo "可用选项 Available Options:"
    echo "1. 启动默认实例 Launch default instance"
    echo "2. 选择现有实例 Select existing instance"
    echo "3. 创建新实例 Create new instance"
    echo "4. 删除指定实例 Delete specified instance"
    echo "5. 创建应用包装器 Create app wrapper (独立图标 independent icon)"
    echo "6. 恢复原始配置 Restore original configuration"
    echo "7. 诊断问题 Diagnose problems"
    echo "8. 修复包装器 Fix wrappers"
    echo ""
    read -p "请选择 Please select (1-8): " choice
    
    case $choice in
        1)
            INSTANCE_NAME="default"
            ;;
        2)
            if [ -d "$CLAUDE_INSTANCES_BASE" ]; then
                echo ""
                echo "现有实例 Existing instances:"
                ls -1 "$CLAUDE_INSTANCES_BASE" 2>/dev/null | grep -v "^scripts$" | sed 's/^/  - /'
                echo ""
                read -p "输入实例名称 Enter instance name: " INSTANCE_NAME
            else
                echo "未找到现有实例，使用默认实例 No existing instances found, using default instance"
                INSTANCE_NAME="default"
            fi
            ;;
        3)
            echo ""
            read -p "新实例名称 New instance name: " INSTANCE_NAME
            echo "将创建并启动新实例 Will create and launch new instance: $INSTANCE_NAME"
            ;;
        4)
            delete_instance_menu
            exit 0
            ;;
        5)
            create_app_wrapper_menu
            exit 0
            ;;
        6)
            restore_original_config
            exit 0
            ;;
        7)
            # 运行诊断 Run diagnostics
            echo "🔍 Claude Desktop 诊断 Diagnostics"
            echo "======================"
            echo ""
            
            echo "1. 检查 Claude Desktop 安装:"
            if [ -d "/Applications/Claude.app" ]; then
                echo "   ✅ Claude.app 存在"
                
                echo ""
                echo "2. 检查可执行文件:"
                ls -la "/Applications/Claude.app/Contents/MacOS/"
                
                echo ""
                echo "3. 检查图标文件:"
                find "/Applications/Claude.app" -name "*.icns" -type f 2>/dev/null || echo "   ⚠️  未找到 .icns 图标文件"
                
                echo ""
                echo "4. 检查应用包装器:"
                for app in /Applications/Claude-*.app; do
                    if [ -d "$app" ]; then
                        echo "   📱 $app"
                        echo "      可执行权限: $(ls -la "$app/Contents/MacOS/"* 2>/dev/null | awk '{print $1}' || echo '未找到')"
                    fi
                done
                
            else
                echo "   ❌ Claude.app 不存在"
                echo "   请从 https://claude.ai/download 下载并安装 Claude Desktop"
            fi
            
            echo ""
            echo "5. 检查实例目录:"
            if [ -d "$CLAUDE_INSTANCES_BASE" ]; then
                echo "   📁 实例目录: $CLAUDE_INSTANCES_BASE"
                for dir in "$CLAUDE_INSTANCES_BASE"/*/; do
                    if [ -d "$dir" ]; then
                        instance_name=$(basename "$dir")
                        if [ "$instance_name" != "scripts" ]; then
                            echo "     - $instance_name"
                        fi
                    fi
                done
            else
                echo "   📁 暂无实例目录"
            fi
            
            exit 0
            ;;
        8)
            # 运行修复
            echo "🔧 修复 Claude Desktop 包装器 Repair Claude Desktop Wrappers"
            echo "============================="
            
            for app in /Applications/Claude-*.app; do
                if [ -d "$app" ]; then
                    echo "🔨 修复 Repairing: $app"
                    
                    # 确保启动脚本有执行权限
                    launcher="$app/Contents/MacOS/claude-launcher"
                    if [ -f "$launcher" ]; then
                        chmod +x "$launcher"
                        echo "   ✅ 设置启动脚本执行权限 Set launcher script executable permissions"
                    else
                        echo "   ❌ 启动脚本不存在 Launcher script not found: $launcher"
                    fi
                    
                    # 检查并修复图标
                    if [ ! -f "$app/Contents/Resources/claude-icon.icns" ]; then
                        echo "   🎨 修复图标..."
                        copy_claude_icon "$app/Contents/Resources"
                    fi

                    # 检查并修复代码签名
                    if ! codesign -v "$app" 2>/dev/null; then
                        echo "   🔐 添加代码签名..."
                        if codesign --force --deep --sign - "$app" 2>/dev/null; then
                            echo "   ✅ 代码签名已添加 Code signature added"
                        else
                            echo "   ⚠️  代码签名失败 Code signing failed"
                        fi
                    else
                        echo "   ✅ 代码签名正常 Code signature OK"
                    fi
                fi
            done

            echo "✅ 修复完成 Repair completed"
            exit 0
            ;;
        *)
            echo "无效选择，使用默认实例 Invalid selection, using default instance"
            INSTANCE_NAME="default"
            ;;
    esac
fi

# 主执行逻辑
echo "🎯 实例: $INSTANCE_NAME"

# 启动实例
launch_instance "$INSTANCE_NAME"

echo ""
echo "======================================"
echo "     Claude Desktop 已启动"
echo "     Claude Desktop Launched"
echo "======================================"