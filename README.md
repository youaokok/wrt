首先装好 Linux 系统，推荐 Ubuntu LTS  

安装编译依赖  
sudo apt update -y  
sudo apt full-upgrade -y  
sudo apt install -y ack antlr3 asciidoc autoconf automake autopoint binutils bison build-essential \  
bzip2 ccache cmake cpio curl device-tree-compiler fastjar flex gawk gettext gcc-multilib g++-multilib \  
git gperf haveged help2man intltool libc6-dev-i386 libelf-dev libfuse-dev libglib2.0-dev libgmp3-dev \  
libltdl-dev libmpc-dev libmpfr-dev libncurses5-dev libncursesw5-dev libpython3-dev libreadline-dev \  
libssl-dev libtool lrzsz mkisofs msmtp ninja-build p7zip p7zip-full patch pkgconf python3 \  
python3-pyelftools python3-setuptools qemu-utils rsync scons squashfs-tools subversion swig texinfo \  
uglifyjs upx-ucl unzip vim wget xmlto xxd zlib1g-dev  


使用步骤：  
git clone https://github.com/ZqinKing/wrt_relese.git  
cd wrt_relese  
  
编译京东云雅典娜、亚瑟:  
./build.sh jdc_ax1800pro-ax6600_libwrt  

编译红米AX6000:  
./build.sh redmi_ax6000_immwrt21  

编译京东云百里:   
./build.sh jdc_ax6000_imm23
