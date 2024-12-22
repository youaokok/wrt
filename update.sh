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

# update_feeds() {
  
# }

# remove_unwanted_packages() {
# }

# update_golang() {
# }

# install_small8()
# }

# install_feeds() {
#    ./scripts/feeds update -i
#    for dir in $BUILD_DIR/feeds/*; do
        # 检查是否为目录并且不以 .tmp 结尾，并且不是软链接
#        if [ -d "$dir" ] && [[ ! "$dir" == *.tmp ]] && [ ! -L "$dir" ]; then
#            if [[ $(basename "$dir") == "small8" ]]; then
#                install_small8
#            else
#                ./scripts/feeds install -f -ap $(basename "$dir")
#            fi
#        fi
#    done
#}

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

# fix_miniupmpd() {
#    local PKG_HASH=$(awk -F"=" '/^PKG_HASH:/ {print $2}' ./feeds/packages/net/miniupnpd/Makefile)
#    if [[ $PKG_HASH == "fbdd5501039730f04a8420ea2f8f54b7df63f9f04cde2dc67fa7371e80477bbe" ]]; then
#        if [[ -f $BASE_PATH/patches/400-fix_nft_miniupnp.patch ]]; then
#            if [[ ! -d ./feeds/packages/net/miniupnpd/patches ]]; then
#                mkdir -p ./feeds/packages/net/miniupnpd/patches
#            fi
#            \cp -f $BASE_PATH/patches/400-fix_nft_miniupnp.patch ./feeds/packages/net/miniupnpd/patches/
#        fi
#    fi
# }

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



# remove_affinity_script() {
  
# }

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

# add_ax6600_led() {

# }

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

# update_tcping() {
  
# }

# set_custom_task() {
# }

# add_wg_chk() {
#    local sbin_path="$BUILD_DIR/package/base-files/files/sbin"
#    if [[ -d "$sbin_path" ]]; then
#        install -m 755 -D "$BASE_PATH/patches/wireguard_check.sh" "$sbin_path/wireguard_check.sh"
#    fi
# }

# 1 update_pw_ha_chk() {
 

#install_opkg_distfeeds() {
    # 只处理aarch64
#    if ! grep -q "nss-packages" "$BUILD_DIR/feeds.conf.default"; then
#        return
#    fi
#    local emortal_def_dir="$BUILD_DIR/package/emortal/default-settings"
#    local distfeeds_conf="$emortal_def_dir/files/99-distfeeds.conf"

#    if [ -d "$emortal_def_dir" ] && [ ! -f "$distfeeds_conf" ]; then
#        install -m 755 -D "$BASE_PATH/patches/99-distfeeds.conf" "$distfeeds_conf"

#        sed -i "/define Package\/default-settings\/install/a\\
# \\t\$(INSTALL_DIR) \$(1)/etc\\n\
# \t\$(INSTALL_DATA) ./files/99-distfeeds.conf \$(1)/etc/99-distfeeds.conf\n" $emortal_def_dir/Makefile

#        sed -i "/exit 0/i\\
# [ -f \'/etc/99-distfeeds.conf\' ] && mv \'/etc/99-distfeeds.conf\' \'/etc/opkg/distfeeds.conf\'\n\
# sed -ri \'/check_signature/s@^[^#]@#&@\' /etc/opkg.conf\n" $emortal_def_dir/files/99-default-settings
#    fi
# }

# update_nss_pbuf_performance() {
#    local pbuf_path="$BUILD_DIR/package/kernel/mac80211/files/pbuf.uci"
#    if [ -d "$(dirname "$pbuf_path")" ] && [ -f $pbuf_path ]; then
#        sed -i "s/auto_scale '1'/auto_scale 'off'/g" $pbuf_path
#        sed -i "s/scaling_governor 'schedutil'/scaling_governor 'performance'/g" $pbuf_path
#    fi
# }

main() {
    clone_repo
    clean_up
    reset_feeds_conf
   # update_feeds
   # remove_unwanted_packages
    fix_default_set
   # fix_miniupmpd
   # update_golang
    change_dnsmasq2full
    chk_fullconenat
    fix_mk_def_depends
   # add_wifi_default_set
   # update_default_lan_addr
   # remove_something_nss_kmod
   # remove_affinity_script
    fix_build_for_openssl
    update_ath11k_fw
    fix_mkpkg_format_invalid
    chanage_cpuusage
  #  update_tcping
  #  add_wg_chk
  #  add_ax6600_led
   # set_custom_task
   # update_pw_ha_chk
   # install_opkg_distfeeds
   # update_nss_pbuf_performance
   # install_feeds
}

main "$@"
