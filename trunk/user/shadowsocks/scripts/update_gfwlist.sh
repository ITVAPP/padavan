#!/bin/sh
set -e -o pipefail

# 添加调试开关
DEBUG=1  # 设置为1启用调试输出,0则禁用

debug() {
    if [ $DEBUG -eq 1 ]; then
        echo "[DEBUG] $(date "+%Y-%m-%d %H:%M:%S") $@"
    fi
}

# 定义备选URL列表
BACKUP_URLS="https://github.moeyy.xyz/https://raw.githubusercontent.com/YW5vbnltb3Vz/domain-list-community/release/gfwlist.txt
https://gh-proxy.com/https://raw.githubusercontent.com/YW5vbnltb3Vz/domain-list-community/release/gfwlist.txt
https://ghproxy.net/https://raw.githubusercontent.com/YW5vbnltb3Vz/domain-list-community/release/gfwlist.txt
https://ghproxy.cc/https://raw.githubusercontent.com/YW5vbnltb3Vz/domain-list-community/release/gfwlist.txt
https://raw.githubusercontent.com/gfwlist/gfwlist/master/gfwlist.txt"

# 测试URL可访问性并下载文件的函数
try_download_url() {
    local url="$1"
    # 将 https 替换为 http
    url=$(echo $url | sed 's/https:/http:/g')
    debug "正在尝试URL: $url"
    
    # 直接尝试下载
    curl -4 -s -o /tmp/gfwlist_list_origin.conf --connect-timeout 10 --retry 3 "$url"
    
    if [ -f /tmp/gfwlist_list_origin.conf ]; then
        local filesize=$(ls -l /tmp/gfwlist_list_origin.conf | awk '{print $5}')
        debug "下载完成，文件大小: $filesize bytes"
        if [ $filesize -gt 1000 ]; then
            return 0
        fi
    fi
    
    return 1
}

NAME=shadowsocksr
GFWLIST_URL="$(nvram get ss_gfwlist_url)"
debug "获取到的 GFWLIST_URL: $GFWLIST_URL"

log() {
    logger -t "$NAME" "$@"
    echo "$(date "+%Y-%m-%d %H:%M:%S") $@" >> "/tmp/ssrplus.log"
    debug "$@"  # 同时输出到调试
}

# 检查更新条件
debug "=============== 更新检查 ==============="
debug "脚本参数: $@"
debug "检查更新参数: \$1=$1, ss_update_gfwlist=$(nvram get ss_update_gfwlist)"
[ "$1" != "force" ] && [ "$(nvram get ss_update_gfwlist)" != "1" ] && {
    debug "不满足更新条件,退出脚本"
    exit 0
}

log "GFWList 开始更新..."

# 检查并创建目录
debug "=============== 文件系统检查 ==============="
debug "检查目录 /etc/storage/gfwlist/"
debug "目录权限: $(ls -ld /etc/storage/gfwlist/ 2>/dev/null || echo '目录不存在')"
[ ! -d /etc/storage/gfwlist/ ] && {
    debug "创建目录 /etc/storage/gfwlist/"
    mkdir -p /etc/storage/gfwlist/
    debug "创建结果: $?"
}

# 备份旧文件
[ -f /tmp/gfwlist_list_origin.conf ] && {
    debug "备份已存在的文件"
    cp -f /tmp/gfwlist_list_origin.conf /tmp/gfwlist_list_origin.conf.bak
}

# 尝试下载文件
debug "=============== 文件下载 ==============="
download_success=0

# 首先尝试主URL
if [ -n "$GFWLIST_URL" ]; then
    debug "尝试主URL: $GFWLIST_URL"
    debug "DNS 解析测试: $(nslookup $(echo $GFWLIST_URL | awk -F/ '{print $3}') 2>&1)"
    debug "网络连接测试: ping -c 1 $(echo $GFWLIST_URL | awk -F/ '{print $3}') 2>&1"
    
    if try_download_url "$GFWLIST_URL"; then
        download_success=1
        log "使用主URL更新成功"
    else
        log "主URL更新失败，尝试备用地址"
    fi
fi

# 如果主URL失败，尝试备用URL
if [ $download_success -eq 0 ]; then
    debug "开始尝试备用URL列表"
    for url in $BACKUP_URLS; do
        if [ -n "$url" ]; then
            if try_download_url "$url"; then
                download_success=1
                log "使用备用URL更新成功: $url"
                break
            fi
        fi
    done
fi

# 如果所有URL都失败，恢复备份
if [ $download_success -eq 0 ]; then
    log "所有URL尝试失败"
    if [ -f /tmp/gfwlist_list_origin.conf.bak ]; then
        debug "恢复备份文件"
        cp -f /tmp/gfwlist_list_origin.conf.bak /tmp/gfwlist_list_origin.conf
    else
        debug "无备份文件可恢复，退出脚本"
        exit 1
    fi
fi

debug "=============== Lua处理 ==============="
debug "执行 lua 脚本处理"
lua /etc_ro/ss/gfwupdate.lua
lua_status=$?
debug "lua 脚本执行完成,退出状态: $lua_status"

# 下载成功后的文件处理逻辑
debug "=============== 文件处理 ==============="
if [ -f /tmp/gfwlist_list.conf ]; then
    count=`awk '{print NR}' /tmp/gfwlist_list.conf|tail -n1`
    debug "统计的行数: $count"
    if [ $count -gt 1000 ]; then
        debug "行数大于1000,开始更新文件"
        rm -f /etc/storage/gfwlist/gfwlist_list.conf
        mv -f /tmp/gfwlist_list.conf /etc/storage/gfwlist/gfwlist_list.conf
        debug "执行存储保存"
        mtd_storage.sh save >/dev/null 2>&1
        debug "存储保存完成"
        log "GFWList 更新完成！"
        echo 3 > /proc/sys/vm/drop_caches
        debug "清理系统缓存完成"
        if [ $(nvram get ss_enable) = 1 ]; then
            debug "=============== 服务重启 ==============="
            lua /etc_ro/ss/gfwcreate.lua
            log "正在重启 ShadowSocksR Plus..."
            /usr/bin/shadowsocks.sh stop
            /usr/bin/shadowsocks.sh start
        else
            debug "SS 未启用,跳过重启"
        fi
    else
        log "GFWList 下载失败,行数不足 1000，请重试！"
    fi
else
    log "GFWList 文件处理失败，文件不存在"
fi

# 清理临时文件
debug "=============== 清理工作 ==============="
rm -f /tmp/gfwlist_list_origin.conf
rm -f /tmp/gfwlist_list.conf
[ -f /tmp/gfwlist_list_origin.conf.bak ] && rm -f /tmp/gfwlist_list_origin.conf.bak
debug "临时文件清理完成"
debug "脚本执行完成"
