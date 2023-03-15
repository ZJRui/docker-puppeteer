FROM node:12-slim

RUN apt-get update && \
apt-get install -yq gconf-service libasound2 libatk1.0-0 libc6 libcairo2 libcups2 libdbus-1-3 \
libexpat1 libfontconfig1 libgcc1 libgconf-2-4 libgdk-pixbuf2.0-0 libglib2.0-0 libgtk-3-0 libnspr4 \
libpango-1.0-0 libpangocairo-1.0-0 libstdc++6 libx11-6 libx11-xcb1 libxcb1 libxcomposite1 \
libxcursor1 libxdamage1 libxext6 libxfixes3 libxi6 libxrandr2 libxrender1 libxss1 libxtst6 \
fonts-ipafont-gothic fonts-wqy-zenhei fonts-thai-tlwg fonts-kacst ttf-freefont \
ca-certificates fonts-liberation libappindicator1 libnss3 lsb-release xdg-utils wget && \
wget https://github.com/Yelp/dumb-init/releases/download/v1.2.1/dumb-init_1.2.1_amd64.deb && \
dpkg -i dumb-init_*.deb && rm -f dumb-init_*.deb && \
apt-get clean && apt-get autoremove -y && rm -rf /var/lib/apt/lists/*




# 在镜像中全局 安装puppetter。 alekzonder/puppeteer 镜像中已经安装好了puppeteer chrome nodejs， 因此我们不需要在 容器的 /app 目录下 npm install puppeteer.  
#假设开发项目使用到了 puppeteer 和dotenv两个npm依赖。 我们只需要将项目的源代码拷贝到 容器的/app目录下（容器的/app目录映射到了主机的某一个路径，假设是/root/app/testApp），
#然后在/root/app/testApp下nmp init -y 创建package.json，然后npm install dotenv ，不需要在项目路径下安装 npm install puppeteer，puppeteer已经在镜像中全局安装了.
# 目前最新的puppettter是  "puppeteer": "^19.7.4", 
RUN yarn global add puppeteer@1.20.0 && yarn cache clean




# ${NODE_PATH}表示读取运行环境变量
ENV NODE_PATH="/usr/local/share/.config/yarn/global/node_modules:${NODE_PATH}"

ENV PATH="/tools:${PATH}"

# useradd 中的-g参数指定添加的用所所属的用户组
#groupadd -r :创建系统组群, groupadd china:创建群组china ， groupadd -r chinese ：创建系统群组china
#useradd -g initial_group:指定用户登录组的GID或者组名，-G group ... 指定用户除了登录组之外所属的一个或多个附加组
RUN groupadd -r pptruser && useradd -r -g pptruser -G audio,video pptruser
#chown 改变所属关系
COPY --chown=pptruser:pptruser ./tools /tools

# Set language to UTF8
ENV LANG="C.UTF-8"

WORKDIR /app

# Add user so we don't need --no-sandbox.
RUN mkdir /screenshots \
	&& mkdir -p /home/pptruser/Downloads \
    && chown -R pptruser:pptruser /home/pptruser \
    && chown -R pptruser:pptruser /usr/local/share/.config/yarn/global/node_modules \
    && chown -R pptruser:pptruser /screenshots \
    && chown -R pptruser:pptruser /app \
    && chown -R pptruser:pptruser /tools

# Run everything after as non-privileged user.
USER pptruser

# --cap-add=SYS_ADMIN
# https://docs.docker.com/engine/reference/run/#additional-groups

# dumb-init是一个简单的进程管理器和初始化系统，旨在在最小的容器环境（例如Docker）中作为PID 1运行，向子进程
#代理发送信号，接管子进程
#示例：root@k8s-master:/tmp# docker run --name sem_test --rm -it -v /tmp/a.out:/a.out -v /tmp/dumb-init:/dumb-init ubuntu:latest /dumb-init /a.out
#上述命令是说 将dumb-init 作为启动进程，然后dumb-init 接受一个参数 ，参数指定一个可执行文件，然后dumb-init启动这个进程
#下面的CMD将会作为ENTRYpoint的参数
## Runs "/usr/bin/dumb-init -- node index.js"
#每个Dockerfile只能有一个entrypoint，如果有多个则只有最后一个生效
ENTRYPOINT ["dumb-init", "--"]

# CMD ["/usr/local/share/.config/yarn/global/node_modules/puppeteer/.local-chromium/linux-526987/chrome-linux/chrome"]
#每个dockerfile只能有一条cmd命令。如果有多个，则只有最后一条会被执行
#问题： 为什么这里 写index.js？ 这个index.js文件在哪里？
#解释： docker run --shm-size 1G --rm -v <path_to_script>:/app/index.js alekzonder/puppeteer:latest，
#-v <path_to_script>:/app/index.js  -v一般我们都是指定主机文件夹映射到 容器文件夹，为什么这里是映射到
#容器的某一个文件呢？ 主要是我们在 dockerfile中指定了默认的 cmd 是 node index.js ，所以容器默认会执行
#node index.js 。所以我们要将本地文件映射到容器文件。

CMD ["node", "index.js"]

#注意： 如果 docker run 中指定了 新的command，则 会覆盖dockerfile中默认的 CMD ["node", "index.js"]。就变成了
# 执行Runs "/usr/bin/dumb-init -- newCommand"  而不是将 docker run中指定的命令 拼接到 Runs "/usr/bin/dumb-init -- node index.js"的后面作为参数
