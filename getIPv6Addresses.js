const os = require('os');

// 定义函数来判断 IPv6 地址类型
function getIPv6Type(address) {
    if (address === '::1') {
        return 'loopback';
    }
    if (address.startsWith('fe80:')) {
        return 'link-local';
    }
    if (!address.startsWith('fe80:') && address.includes(':')) {
        return 'global';
    }
    return 'unknown';
}

// 获取本机所有 IPv6 地址信息
function getIPv6Addresses() {
    const interfaces = os.networkInterfaces();
    const ipv6Info = {
        'link-local': [],
        'global': [],
        'loopback': [],
        'unknown': []
    };

    for (const interfaceName in interfaces) {
        const iface = interfaces[interfaceName];
        for (const info of iface) {
            if (info.family === 'IPv6') {
                const type = getIPv6Type(info.address);
                ipv6Info[type].push(info.address);
            }
        }
    }

    return ipv6Info;
}
if (require.main === module) {
    console.log(getIPv6Addresses().global);
} else {
    module.exports = getIPv6Addresses;
}
