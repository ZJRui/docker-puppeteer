#!/usr/bin/env node

function sleep(ms) {
    ms = (ms) ? ms : 0;
    return new Promise(resolve => {setTimeout(resolve, ms);});
}

/**
 * 问题：为什么要用这种形式？  因为当前的js文件时通过full_screenshot 脚本文件中的 
 * env node /tools/fullScreenshot.js "$@" 执行的，类似于子进程吧？
 */
process.on('uncaughtException', (error) => {
    console.error(error);
    process.exit(1);
});

process.on('unhandledRejection', (reason, p) => {
    console.error(reason, p);
    process.exit(1);
});

const puppeteer = require('puppeteer');

// console.log(process.argv);
/**
 * node 程序的参数，
 * [root@localhost docker-puppeteer]# node test.js 
length [
  '/usr/local/bin/node',
  '/root/docker-learn/docker-puppeteer/test.js'
]
 * 
 */
//因此我们执行 node .index.js http://baidu.com  这个url就是第三个参数
if (!process.argv[2]) {
    console.error('ERROR: no url arg\n');

    console.info('for example:\n');
    console.log('  docker run --shm-size 1G --rm -v /tmp:/screenshots \\');
    console.log('  alekzonder/puppeteer:latest screenshot \'https://www.google.com\'\n');
    process.exit(1);
}

var url = process.argv[2];

var now = new Date();

var dateStr = now.toISOString();

var width = 800;
var height = 600;

if (typeof process.argv[3] === 'string') {
    var [width, height] = process.argv[3].split('x').map(v => parseInt(v, 10));
}

var delay = 0;

if (typeof process.argv[4] === 'string') {
    delay = parseInt(process.argv[4], 10);
}

var isMobile = false;

/**
 * 注意这行代码， 这行代码后面必须要带有分号， 不然
 *  `full_screenshot_${width}_${height}.png` 会被作为函数名，他后面有一对括号 （async xx），
 * 所以会被作为函数
 */
let filename = `full_screenshot_${width}_${height}.png`;

(async() => {

    const browser = await puppeteer.launch({
        args: [
        '--no-sandbox',
        '--disable-setuid-sandbox'
        ]
    });

    const page = await browser.newPage();

    page.setViewport({
        width,
        height,
        isMobile
    });

    await page.goto(url, {waitUntil: 'networkidle2'});

    await sleep(delay);

    /**
     * 这里有一个问题： 我们将截图保存到了容器的/screenshots 目录下了。
     * docker run --name alekpte_screen2 -v /root/docker-learn/docker-puppeteer/index.js:/app/index.js alekzonder/puppeteer:latest  node index.js https://www.baidu.com
     * 
     * 这种方式启动创建的容器  会执行 node index.js http://www.baidu.com 当index.js执行完 进程就推出了
     * 同时容器也会退出。 所以我该如何进入到容器的screenshot目录下查看文件呢？
     * 
     * （1）docker exec 进入容器 要求容器必须要是运行状态。
     * （2）创建容器的时候 指定本机目录映射到 容器的/screenshot 
     * （3） 使用docker cp 将容器中的文件拷贝出来，《 Docker容器无法启动,里面的配置文件如何修改 》  docker cp alekpte_screen2:/screenshots  /root/docker-learn/docker-puppeteer/
     * （4）查看docker容器在本地的存储路径，到这个文件夹下寻找
     * 
     * 
     * 或者说： docker run -it --name alekPtr_screen3 -v /root/docker-learn/docker-puppeteer/index.js:/app/index.js alekzonder/puppeteer:latest  /bin/bash
     * 创建一个容器 并启动shell，然后 在shell中执行 node index.js http://www.baid.com  然后查看 /srcrenshots目录
     * 
     * 
     * 
     * 
     */
    await page.screenshot({path: `/screenshots/${filename}`, fullPage: true});

    browser.close();

    console.log(
        JSON.stringify({
            date: dateStr,
            timestamp: Math.floor(now.getTime() / 1000),
            filename,
            width,
            height
        })
    );

})();
