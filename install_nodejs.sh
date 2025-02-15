#!/bin/bash

# 定义 Node.js 版本和下载链接
NODE_VERSION="v22.13.1"
NODE_DOWNLOAD_URL="https://nodejs.org/dist/${NODE_VERSION}/node-${NODE_VERSION}-linux-x64.tar.xz"
# 下载 Node.js 的 tar.xz 文件
echo "正在下载 Node.js ${NODE_VERSION}..."
wget $NODE_DOWNLOAD_URL
if [ $? -ne 0 ]; then
    echo "下载失败，请检查网络或下载链接。"
    exit 1
fi

# 解压文件
echo "正在解压 Node.js 文件..."
tar -xvf node-${NODE_VERSION}-linux-x64.tar.xz
if [ $? -ne 0 ]; then
    echo "解压失败，请检查文件是否完整。"
    exit 1
fi

# 移动解压后的文件夹
echo "正在移动 Node.js 文件夹到 /usr/local..."
sudo mv node-${NODE_VERSION}-linux-x64 /usr/local/nodejs
if [ $? -ne 0 ]; then
    echo "移动文件夹失败，请检查权限。"
    exit 1
fi

# 配置环境变量
echo "正在配置环境变量..."
echo 'export PATH=/usr/local/nodejs/bin:$PATH' >> ~/.bashrc
source ~/.bashrc

# 验证安装
echo "正在验证 Node.js 和 npm 安装..."
node -v
npm -v
if [ $? -eq 0 ]; then
    echo "Node.js 和 npm 安装成功！"
else
    echo "安装验证失败，请检查安装步骤。"
fi

# 清理下载文件
rm node-${NODE_VERSION}-linux-x64.tar.xz