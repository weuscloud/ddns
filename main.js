const fs = require('fs');
const ini = require('ini');
const getIPv6Addresses = require('./getIPv6Addresses');
function getTargetField(config) {
    return Object.getOwnPropertyNames(config.IPv6)[0]||null;
}

function main() {
    // 读取 config.ini 文件
    fs.readFile('config.ini', 'utf8', (err, data) => {
        if (err) {
            console.error('读取 config.ini 文件时出错:', err);
            return;

        }
        const config = ini.parse(data);
        // 获取要更新的字段名
        const targetField = getTargetField(config);
        if(!targetField) return console.error('读取 config.ini 文件时出错:', err);
        // 获取全局 IPv6 地址列表
        const ipv6Addresses = getIPv6Addresses();

        // 检查是否有至少两个全局 IPv6 地址
        if (ipv6Addresses.global.length > 0) {
            config.IPv6[targetField] = ipv6Addresses.global[0];
        } else {
            console.log('没有足够的全局 IPv6 地址可供使用。');
            return;
        }

        // 将更新后的配置对象转换回 ini 格式的字符串
        const updatedConfig = ini.stringify(config, { section: '' });

        // 将更新后的内容写入 config.ini 文件
        fs.writeFile('config.ini', updatedConfig, 'utf8', (writeErr) => {
            if (writeErr) {
                console.error('写入 config.ini 文件时出错:', writeErr);
            } else {
                console.log(`成功将IPv6 地址写入 config.ini 文件的 [IPv6] 节下的 ${targetField} 字段。`);
            }
        });
    });
}
if (require.main === module) {
    main();
} else {
    module.exports = getTargetField;
}
