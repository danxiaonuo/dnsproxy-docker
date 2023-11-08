##########################################
#         构建可执行二进制文件             #
##########################################
# 指定构建的基础镜像
FROM alpine:latest as down

# 作者描述信息
MAINTAINER danxiaonuo
# 时区设置
ARG TZ=Asia/Shanghai
ENV TZ=$TZ
# 语言设置
ARG LANG=C.UTF-8
ENV LANG=$LANG

# 构建依赖
ARG BUILD_DEPS="\
      git \
      wget \
      curl \
      jq \
      tar \
      xz \
      make"
ENV BUILD_DEPS=$BUILD_DEPS

# ***** 安装依赖 *****
RUN set -eux && \
   # 修改源地址
   sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories && \
   # 更新源地址并更新系统软件
   apk update && apk upgrade && \
   # 安装依赖包
   apk add --no-cache --clean-protected $BUILD_DEPS && \
   rm -rf /var/cache/apk/* && \
   # 更新时区
   ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime && \
   # 更新时间
   echo ${TZ} > /etc/timezone

# 运行下载
RUN set -eux \
    && export DNSPROXY_DOWN=$(curl -s https://api.github.com/repos/AdguardTeam/dnsproxy/releases/latest | jq -r .assets[].browser_download_url | grep -i 'linux-amd64') \
    && wget --no-check-certificate -O /tmp/dnsproxy-linux-amd64.tar.gz $DNSPROXY_DOWN \
    && cd /tmp && tar zxvf dnsproxy-linux-amd64.tar.gz

##########################################
#         构建基础镜像                    #
##########################################
# 
# 指定创建的基础镜像
FROM alpine AS dist

# 作者描述信息
MAINTAINER danxiaonuo
# 时区设置
ARG TZ=Asia/Shanghai
ENV TZ=$TZ
# 语言设置
ARG LANG=C.UTF-8
ENV LANG=$LANG

ARG PKG_DEPS="\
      zsh \
      bash \
      bash-doc \
      bash-completion \
      bind-tools \
      iproute2 \
      ipset \
      git \
      vim \
      tzdata \
      curl \
      wget \
      lsof \
      zip \
      unzip \
      ca-certificates"
ENV PKG_DEPS=$PKG_DEPS

# ***** 安装依赖 *****
RUN set -eux && \
   # 修改源地址
   sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories && \
   # 更新源地址并更新系统软件
   apk update && apk upgrade && \
   # 安装依赖包
   apk add --no-cache --clean-protected $PKG_DEPS && \
   rm -rf /var/cache/apk/* && \
   # 更新时区
   ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime && \
   # 更新时间
   echo ${TZ} > /etc/timezone && \
   # 更改为zsh
   sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" || true && \
   sed -i -e "s/bin\/ash/bin\/zsh/" /etc/passwd && \
   sed -i -e 's/mouse=/mouse-=/g' /usr/share/vim/vim*/defaults.vim && \
   /bin/zsh
   
# 拷贝dnsproxy
COPY --from=down /tmp/linux-amd64/dnsproxy /usr/bin/dnsproxy

# 安装dnsproxy
RUN set -eux \
    && chmod +x /usr/bin/dnsproxy \
    && mkdir -pv /etc/dnsproxy

# 拷贝dnsproxy配置文件
COPY conf/dnsproxy/config.yaml /etc/dnsproxy/config.yaml

# 容器信号处理
STOPSIGNAL SIGQUIT

# 挂载目录
VOLUME /etc/dnsproxy

# 执行命令
CMD /usr/bin/dnsproxy --config-path=/etc/dnsproxy/config.yaml
