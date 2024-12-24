#!/usr/bin/env bash

set -e
set -o errexit
set -o errtrace

# 定义错误处理函数
error_handler() {
    echo "Error occurred in script at line: ${BASH_LINENO[0]}, command: '${BASH_COMMAND}'"
}

# 设置trap捕获ERR信号
trap 'error_handler' ERR

source /etc/profile
BASE_PATH=$(cd $(dirname $0) && pwd)

REPO_URL=$1
REPO_BRANCH=$2
BUILD_DIR=$3
COMMIT_HASH=$4

FEEDS_CONF="feeds.conf.default"
GOLANG_REPO="https://github.com/sbwml/packages_lang_golang"
GOLANG_BRANCH="23.x"
THEME_SET="argon"
LAN_ADDR="192.168.1.1"

clone_repo() {
    if [[ ! -d $BUILD_DIR ]]; then
        echo $REPO_URL $REPO_BRANCH
        git clone --depth 1 -b $REPO_BRANCH $REPO_URL $BUILD_DIR
    fi
}

clean_up() {
    cd $BUILD_DIR
    if [[ -f $BUILD_DIR/.config ]]; then
        \rm -f $BUILD_DIR/.config
    fi
    if [[ -d $BUILD_DIR/tmp ]]; then
        \rm -rf $BUILD_DIR/tmp
    fi
    if [[ -d $BUILD_DIR/logs ]]; then
        \rm -rf $BUILD_DIR/logs/*
    fi
}

reset_feeds_conf() {
    git reset --hard origin/$REPO_BRANCH
    git clean -f -d
    git pull
    if [[ $COMMIT_HASH != "none" ]]; then
        git checkout $COMMIT_HASH
    fi
}

update_feeds() {
    # 删除注释行
    sed -i '/^#/d' "$BUILD_DIR/$FEEDS_CONF"

    # 检查并添加 small-package 源
    if ! grep -q "small-package" "$BUILD_DIR/$FEEDS_CONF"; then
        # 确保文件以换行符结尾
        [ -z "$(tail -c 1 "$BUILD_DIR/$FEEDS_CONF")" ] || echo "" >>"$BUILD_DIR/$FEEDS_CONF"
        echo "src-git small8 https://github.com/kenzok8/small-package" >>"$BUILD_DIR/$FEEDS_CONF"
    fi

    # 添加bpf.mk解决更新报错
    if [ ! -f "$BUILD_DIR/include/bpf.mk" ]; then
        touch "$BUILD_DIR/include/bpf.mk"
    fi

    # 更新 feeds
    ./scripts/feeds clean
    ./scripts/feeds update -a
}

remove_unwanted_packages() {
    local luci_packages=(
        
       "luci-theme-argon" 
       
    )
    local packages_net=(
    
        
        "chinadns-ng" 
        
    )
   # local small8_packages=(
   #     "ppp" "firewall" "dae" "daed" "daed-next" "libnftnl" "nftables" "dnsmasq"
   # )

    for pkg in "${luci_packages[@]}"; do
        \rm -rf ./feeds/luci/applications/$pkg
        \rm -rf ./feeds/luci/themes/$pkg
    done

    for pkg in "${packages_net[@]}"; do
        \rm -rf ./feeds/packages/net/$pkg
    done

   # for pkg in "${small8_packages[@]}"; do
   #     \rm -rf ./feeds/small8/$pkg
   # done

    if [[ -d ./package/istore ]]; then
        \rm -rf ./package/istore
    fi
}

update_golang() {
    if [[ -d ./feeds/packages/lang/golang ]]; then
        \rm -rf ./feeds/packages/lang/golang
        git clone $GOLANG_REPO -b $GOLANG_BRANCH ./feeds/packages/lang/golang
    fi
}

install_small8() {
    ./scripts/feeds install -p small8 -f xray-core xray-plugin dns2tcp dns2socks haproxy hysteria \
        naiveproxy shadowsocks-rust sing-box v2ray-core v2ray-geodata v2ray-geoview v2ray-plugin \
        tuic-client chinadns-ng ipt2socks tcping trojan-plus simple-obfs shadowsocksr-libev \
        luci-app-passwall alist luci-app-alist smartdns luci-app-smartdns v2dat mosdns luci-app-mosdns \
        adguardhome luci-app-adguardhome ddns-go luci-app-ddns-go taskd luci-lib-xterm luci-lib-taskd \
        luci-app-store quickstart luci-app-quickstart luci-app-istorex luci-app-cloudflarespeedtest \
        luci-theme-argon netdata luci-app-netdata lucky luci-app-lucky luci-app-openclash mihomo \
        luci-app-mihomo luci-app-homeproxy
}

install_feeds() {
    ./scripts/feeds update -i
    for dir in $BUILD_DIR/feeds/*; do
        # 检查是否为目录并且不以 .tmp 结尾，并且不是软链接
        if [ -d "$dir" ] && [[ ! "$dir" == *.tmp ]] && [ ! -L "$dir" ]; then
            if [[ $(basename "$dir") == "small8" ]]; then
                install_small8
            else
                ./scripts/feeds install -f -ap $(basename "$dir")
            fi
        fi
    done
}

fix_default_set() {
    #修改默认主题
    sed -i "s/luci-theme-bootstrap/luci-theme-$THEME_SET/g" $(find ./feeds/luci/collections/ -type f -name "Makefile")

    install -m 755 -D "$BASE_PATH/patches/99_set_argon_primary" "$BUILD_DIR/package/base-files/files/etc/uci-defaults/99_set_argon_primary"

    if [ -f $BUILD_DIR/package/emortal/autocore/files/tempinfo ]; then
        if [ -f $BASE_PATH/patches/tempinfo ]; then
            \cp -f $BASE_PATH/patches/tempinfo ./package/emortal/autocore/files/tempinfo
        fi
    fi
}

 fix_miniupmpd() {
    local PKG_HASH=$(awk -F"=" '/^PKG_HASH:/ {print $2}' ./feeds/packages/net/miniupnpd/Makefile)
    if [[ $PKG_HASH == "fbdd5501039730f04a8420ea2f8f54b7df63f9f04cde2dc67fa7371e80477bbe" ]]; then
        if [[ -f $BASE_PATH/patches/400-fix_nft_miniupnp.patch ]]; then
            if [[ ! -d ./feeds/packages/net/miniupnpd/patches ]]; then
                mkdir -p ./feeds/packages/net/miniupnpd/patches
            fi
            \cp -f $BASE_PATH/patches/400-fix_nft_miniupnp.patch ./feeds/packages/net/miniupnpd/patches/
        fi
    fi
 }

change_dnsmasq2full() {
    if ! grep -q "dnsmasq-full" $BUILD_DIR/include/target.mk; then
        sed -i 's/dnsmasq/dnsmasq-full/g' ./include/target.mk
    fi
}

chk_fullconenat() {
    if [ ! -d $BUILD_DIR/package/network/utils/fullconenat-nft ]; then
        \cp -rf $BASE_PATH/fullconenat/fullconenat-nft $BUILD_DIR/package/network/utils
    fi
    if [ ! -d $BUILD_DIR/package/network/utils/fullconenat ]; then
        \cp -rf $BASE_PATH/fullconenat/fullconenat $BUILD_DIR/package/network/utils
    fi
}

fix_mk_def_depends() {
    sed -i 's/libustream-mbedtls/libustream-openssl/g' $BUILD_DIR/include/target.mk 2>/dev/null
    if [ -f $BUILD_DIR/target/linux/qualcommax/Makefile ]; then
        sed -i 's/wpad-basic-mbedtls/wpad-openssl/g' $BUILD_DIR/target/linux/qualcommax/Makefile
    fi
}

#add_wifi_default_set() {
#    local uci_dir="$BUILD_DIR/package/base-files/files/etc/uci-defaults"
#    local ipq_uci_dir="$BUILD_DIR/target/linux/qualcommax/ipq60xx/base-files/etc/uci-defaults"
#    if [ -f "$uci_dir/990_set-wireless.sh" ]; then
#        \rm -f "$uci_dir/990_set-wireless.sh"
#    fi
#    if [ -d "$ipq_uci_dir" ]; then
#        install -m 755 -D "$BASE_PATH/patches/992_set-wifi-uci.sh" "$ipq_uci_dir/992_set-wifi-uci.sh"
#    fi
# }

# update_default_lan_addr() {
#    local CFG_PATH="$BUILD_DIR/package/base-files/files/bin/config_generate"
#    if [ -f $CFG_PATH ]; then
#        sed -i 's/192\.168\.[0-9]*\.[0-9]*/'$LAN_ADDR'/g' $CFG_PATH
#    fi
# }



remove_affinity_script() {
    local affinity_script_path="$BUILD_DIR/target/linux/qualcommax/ipq60xx/base-files/etc/init.d/set-irq-affinity"
    if [ -f "$affinity_script_path" ]; then
        \rm -f "$affinity_script_path"
    fi
}

fix_build_for_openssl() {
    local makefile="$BUILD_DIR/package/libs/openssl/Makefile"

    if [[ -f "$makefile" ]]; then
        if ! grep -qP "^CONFIG_OPENSSL_SSL3" "$makefile"; then
            sed -i '/^ifndef CONFIG_OPENSSL_SSL3/i CONFIG_OPENSSL_SSL3 := y' "$makefile"
        fi
    fi
}

update_ath11k_fw() {
    local makefile="$BUILD_DIR/package/firmware/ath11k-firmware/Makefile"
    local new_mk="$BASE_PATH/patches/ath11k_fw.mk"

    if [ -d "$(dirname "$makefile")" ] && [ -f "$makefile" ]; then
        [ -f "$new_mk" ] && \rm -f "$new_mk"
        curl -L -o "$new_mk" https://raw.githubusercontent.com/youaokok/openwrt-66.x/refs/heads/main/package/firmware/ath11k-firmware/Makefile
        \mv -f "$new_mk" "$makefile"
    fi
}

fix_mkpkg_format_invalid() {
    if [[ $BUILD_DIR =~ "imm-nss" ]]; then
        if [ -f $BUILD_DIR/feeds/small8/v2ray-geodata/Makefile ]; then
            sed -i 's/VER)-\$(PKG_RELEASE)/VER)-r\$(PKG_RELEASE)/g' $BUILD_DIR/feeds/small8/v2ray-geodata/Makefile
        fi
        if [ -f $BUILD_DIR/feeds/small8/luci-lib-taskd/Makefile ]; then
            sed -i 's/>=1\.0\.3-1/>=1\.0\.3-r1/g' $BUILD_DIR/feeds/small8/luci-lib-taskd/Makefile
        fi
        if [ -f $BUILD_DIR/feeds/small8/luci-app-openclash/Makefile ]; then
            sed -i 's/PKG_RELEASE:=beta/PKG_RELEASE:=1/g' $BUILD_DIR/feeds/small8/luci-app-openclash/Makefile
        fi
        if [ -f $BUILD_DIR/feeds/small8/luci-app-quickstart/Makefile ]; then
            sed -i 's/PKG_VERSION:=0\.8\.16-1/PKG_VERSION:=0\.8\.16/g' $BUILD_DIR/feeds/small8/luci-app-quickstart/Makefile
            sed -i 's/PKG_RELEASE:=$/PKG_RELEASE:=1/g' $BUILD_DIR/feeds/small8/luci-app-quickstart/Makefile
        fi
        if [ -f $BUILD_DIR/feeds/small8/luci-app-store/Makefile ]; then
            sed -i 's/PKG_VERSION:=0\.1\.27-1/PKG_VERSION:=0\.1\.27/g' $BUILD_DIR/feeds/small8/luci-app-store/Makefile
            sed -i 's/PKG_RELEASE:=$/PKG_RELEASE:=1/g' $BUILD_DIR/feeds/small8/luci-app-store/Makefile
        fi
    fi
}

add_ax6600_led() {
    local target_dir="$BUILD_DIR/target/linux/qualcommax/ipq60xx/base-files"
    local initd_dir="$target_dir/etc/init.d"
    local sbin_dir="$target_dir/sbin"
    local athena_led_dir="$BUILD_DIR/package/emortal/luci-app-athena-led"

    if [ -d "$(dirname "$target_dir")" ] && [ -d "$initd_dir" ]; then
        cat <<'EOF' >"$initd_dir/start_screen"
#!/bin/sh /etc/rc.common

START=99

boot() {
    case $(board_name) in
    jdcloud,ax6600|\
    jdcloud,re-cs-02)
        ax6600_led >/dev/null 2>&1 &
        ;;
    esac
}
EOF
        chmod +x "$initd_dir/start_screen"
        mkdir -p "$sbin_dir"
        install -m 755 -D "$BASE_PATH/patches/ax6600_led" "$sbin_dir/ax6600_led"

        # 临时加一下
        install -m 755 -D "$BASE_PATH/patches/cpuusage" "$sbin_dir/cpuusage"
    fi

    \rm -rf $athena_led_dir 2>/dev/null
}

chanage_cpuusage() {
    local luci_dir="$BUILD_DIR/feeds/luci/modules/luci-base/root/usr/share/rpcd/ucode/luci"
    local imm_script1="$BUILD_DIR/package/base-files/files/etc/uci-defaults/993_set-nss-load.sh"
    local imm_script2="$BUILD_DIR/package/base-files/files/sbin/cpuusage"

    if [ -f $luci_dir ]; then
        sed -i "s#const fd = popen('top -n1 | awk \\\'/^CPU/ {printf(\"%d%\", 100 - \$8)}\\\'')#const cpuUsageCommand = access('/sbin/cpuusage') ? '/sbin/cpuusage' : 'top -n1 | awk \\\'/^CPU/ {printf(\"%d%\", 100 - \$8)}\\\''#g" $luci_dir
        sed -i '/cpuUsageCommand/a \\t\t\tconst fd = popen(cpuUsageCommand);' $luci_dir
    fi

    if [ -f "$imm_script1" ]; then
        \rm -f "$imm_script1"
    fi

    if [ -f "$imm_script2" ]; then
        \rm -f "$imm_script2"
    fi

    # 临时放一下，清理脚本
    find $BUILD_DIR/package/base-files/files/etc/uci-defaults/ -type f -name "9*.sh" -exec rm -f {} +
}



set_custom_task() {
    local sh_dir="$BUILD_DIR/package/base-files/files/etc/init.d"
    cat <<'EOF' >"$sh_dir/custom_task"
#!/bin/sh /etc/rc.common
# 设置启动优先级
START=99

boot() {
    # 重新添加缓存请求定时任务
    sed -i '/drop_caches/d' /etc/crontabs/root
    echo "15 3 * * * sync && echo 3 > /proc/sys/vm/drop_caches" >>/etc/crontabs/root

    # 删除现有的 wireguard_check 任务
    sed -i '/wireguard_check/d' /etc/crontabs/root

    # 获取 WireGuard 接口名称
    local wg_ifname=$(wg show | awk '/interface/ {print $2}')

    if [ -n "$wg_ifname" ]; then
        # 添加新的 wireguard_check 任务，每10分钟执行一次
        echo "*/10 * * * * /sbin/wireguard_check.sh" >>/etc/crontabs/root
        uci set system.@system[0].cronloglevel='9'
        uci commit system
        /etc/init.d/cron restart
    fi

    # 应用新的 crontab 配置
    crontab /etc/crontabs/root
}
EOF
    chmod +x "$sh_dir/custom_task"
}

add_wg_chk() {
    local sbin_path="$BUILD_DIR/package/base-files/files/sbin"
    if [[ -d "$sbin_path" ]]; then
        install -m 755 -D "$BASE_PATH/patches/wireguard_check.sh" "$sbin_path/wireguard_check.sh"
    fi
}




main() {
    clone_repo
    clean_up
    reset_feeds_conf
    update_feeds
    remove_unwanted_packages
    fix_default_set
    fix_miniupmpd
    update_golang
    change_dnsmasq2full
    chk_fullconenat
    fix_mk_def_depends
   # add_wifi_default_set
   # update_default_lan_addr
   # remove_something_nss_kmod
    remove_affinity_script
    fix_build_for_openssl
    update_ath11k_fw
    fix_mkpkg_format_invalid
    chanage_cpuusage
   # update_tcping
    add_wg_chk
    add_ax6600_led
    set_custom_task
   # update_pw_ha_chk
   # install_opkg_distfeeds
   # update_nss_pbuf_performance
    install_feeds
}

main "$@"
