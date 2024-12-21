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


#install_small8() {
#    ./scripts/feeds install -p small8 -f xray-core xray-plugin dns2tcp dns2socks haproxy hysteria \
#        naiveproxy shadowsocks-rust sing-box v2ray-core v2ray-geodata v2ray-geoview v2ray-plugin \
 #       tuic-client chinadns-ng ipt2socks tcping trojan-plus simple-obfs shadowsocksr-libev \
#        luci-app-passwall alist luci-app-alist smartdns luci-app-smartdns v2dat mosdns luci-app-mosdns \
#        adguardhome luci-app-adguardhome ddns-go luci-app-ddns-go taskd luci-lib-xterm luci-lib-taskd \
#        luci-app-store quickstart luci-app-quickstart luci-app-istorex luci-app-cloudflarespeedtest \
#        luci-theme-argon netdata luci-app-netdata lucky luci-app-lucky luci-app-openclash mihomo \
#        luci-app-mihomo luci-app-homeproxy
#}
#
#install_feeds() {
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
# }
#
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



#update_default_lan_addr() {
#    local CFG_PATH="$BUILD_DIR/package/base-files/files/bin/config_generate"
#    if [ -f $CFG_PATH ]; then
 #       sed -i 's/192\.168\.[0-9]*\.[0-9]*/'$LAN_ADDR'/g' $CFG_PATH
#    fi
#}

#remove_something_nss_kmod() {
 #   local ipq_target_path="$BUILD_DIR/target/linux/qualcommax/ipq60xx/target.mk"
 #   local ipq_mk_path="$BUILD_DIR/target/linux/qualcommax/Makefile"
 #   if [ -f $ipq_target_path ]; then
 #       sed -i 's/kmod-qca-nss-drv-eogremgr//g' $ipq_target_path
 #       sed -i 's/kmod-qca-nss-drv-gre//g' $ipq_target_path
 #       sed -i 's/kmod-qca-nss-drv-map-t//g' $ipq_target_path
 #       sed -i 's/kmod-qca-nss-drv-match//g' $ipq_target_path
 #       sed -i 's/kmod-qca-nss-drv-mirror//g' $ipq_target_path
 #       sed -i 's/kmod-qca-nss-drv-pvxlanmgr//g' $ipq_target_path
 #       sed -i 's/kmod-qca-nss-drv-tun6rd//g' $ipq_target_path
 #       sed -i 's/kmod-qca-nss-drv-tunipip6//g' $ipq_target_path
 #       sed -i 's/kmod-qca-nss-drv-vxlanmgr//g' $ipq_target_path
 #       sed -i 's/kmod-qca-nss-macsec//g' $ipq_target_path
#    fi

 #   if [ -f $ipq_mk_path ]; then
#        sed -i '/kmod-qca-nss-crypto/d' $ipq_mk_path
 #       sed -i '/kmod-qca-nss-drv-eogremgr/d' $ipq_mk_path
 #       sed -i '/kmod-qca-nss-drv-gre/d' $ipq_mk_path
 #       sed -i '/kmod-qca-nss-drv-map-t/d' $ipq_mk_path
 #       sed -i '/kmod-qca-nss-drv-match/d' $ipq_mk_path
 #       sed -i '/kmod-qca-nss-drv-mirror/d' $ipq_mk_path
 #       sed -i '/kmod-qca-nss-drv-tun6rd/d' $ipq_mk_path
#        sed -i '/kmod-qca-nss-drv-tunipip6/d' $ipq_mk_path
#        sed -i '/kmod-qca-nss-drv-vxlanmgr/d' $ipq_mk_path
#        sed -i '/kmod-qca-nss-drv-wifi-meshmgr/d' $ipq_mk_path
#        sed -i '/kmod-qca-nss-macsec/d' $ipq_mk_path
#    fi
#}

#remove_affinity_script() {
#    local affinity_script_path="$BUILD_DIR/target/linux/qualcommax/ipq60xx/base-files/etc/init.d/set-irq-affinity"
#    if [ -f "$affinity_script_path" ]; then
#        \rm -f "$affinity_script_path"
#    fi
#}



#update_ath11k_fw() {
#    local makefile="$BUILD_DIR/package/firmware/ath11k-firmware/Makefile"
#    local new_mk="$BASE_PATH/patches/ath11k_fw.mk"

#    if [ -d "$(dirname "$makefile")" ] && [ -f "$makefile" ]; then
#        [ -f "$new_mk" ] && \rm -f "$new_mk"
#        curl -L -o "$new_mk" https://raw.githubusercontent.com/VIKINGYFY/immortalwrt/refs/heads/main/package/firmware/ath11k-firmware/Makefile
#        \mv -f "$new_mk" "$makefile"
#    fi
#}

# fix_mkpkg_format_invalid() {
#    if [[ $BUILD_DIR =~ "imm-nss" ]]; then
##        if [ -f $BUILD_DIR/feeds/small8/v2ray-geodata/Makefile ]; then
#            sed -i 's/VER)-\$(PKG_RELEASE)/VER)-r\$(PKG_RELEASE)/g' $BUILD_DIR/feeds/small8/v2ray-geodata/Makefile
#        fi
#        if [ -f $BUILD_DIR/feeds/small8/luci-lib-taskd/Makefile ]; then
#            sed -i 's/>=1\.0\.3-1/>=1\.0\.3-r1/g' $BUILD_DIR/feeds/small8/luci-lib-taskd/Makefile
#        fi
#        if [ -f $BUILD_DIR/feeds/small8/luci-app-openclash/Makefile ]; then
#            sed -i 's/PKG_RELEASE:=beta/PKG_RELEASE:=1/g' $BUILD_DIR/feeds/small8/luci-app-openclash/Makefile
#        fi
#        if [ -f $BUILD_DIR/feeds/small8/luci-app-quickstart/Makefile ]; then
#            sed -i 's/PKG_VERSION:=0\.8\.16-1/PKG_VERSION:=0\.8\.16/g' $BUILD_DIR/feeds/small8/luci-app-quickstart/Makefile
#            sed -i 's/PKG_RELEASE:=$/PKG_RELEASE:=1/g' $BUILD_DIR/feeds/small8/luci-app-quickstart/Makefile
#        fi
#        if [ -f $BUILD_DIR/feeds/small8/luci-app-store/Makefile ]; then
#            sed -i 's/PKG_VERSION:=0\.1\.27-1/PKG_VERSION:=0\.1\.27/g' $BUILD_DIR/feeds/small8/luci-app-store/Makefile
#            sed -i 's/PKG_RELEASE:=$/PKG_RELEASE:=1/g' $BUILD_DIR/feeds/small8/luci-app-store/Makefile
#        fi
#    fi
#} 


    # 临时放一下，清理脚本






main() {
    clone_repo
    clean_up
    reset_feeds_conf
  
    fix_default_set
   
  
   
   
    
}

main "$@"
