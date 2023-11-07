##########################################
#         构建可执行二进制文件             #
##########################################
# 指定构建的基础镜像
FROM --platform=${TARGETPLATFORM} golang:alpine as builder

# 作者描述信息
MAINTAINER danxiaonuo
# 时区设置
ARG TZ=Asia/Shanghai
ENV TZ=$TZ
# 语言设置
ARG LANG=C.UTF-8
ENV LANG=$LANG

# GO环境变量
ARG GOPROXY=""
ENV GOPROXY ${GOPROXY}
ARG GO111MODULE=on
ENV GO111MODULE=$GO111MODULE
ARG CGO_ENABLED=1
ENV CGO_ENABLED=$CGO_ENABLED

# MOSDNS版本
ARG MOSDNS_VERSION=v5.3.1
ENV MOSDNS_VERSION=$MOSDNS_VERSION

ARG PKG_DEPS="\
      bash \
      gcc \
      go \
      musl-dev \
      git \
      linux-headers \
      build-base \
      zlib-dev \
      openssl \
      openssl-dev \
      tor \
      libevent-dev \
      tzdata \
      ca-certificates"
ENV PKG_DEPS=$PKG_DEPS

# ***** 安装依赖并构建二进制文件 *****
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
   # 克隆源码运行安装
   git clone --depth=1 -b $MOSDNS_VERSION --progress https://github.com/IrineSistiana/mosdns.git /src && \
   cd /src && export COMMIT=$(git rev-parse --short HEAD) && \
   go env -w GO111MODULE=on && \
   go env -w CGO_ENABLED=1 && \
   git fetch --all --tags && \
   git checkout tags/${MOSDNS_VERSION} && \
   go build -ldflags "-s -w -X main.version=${MOSDNS_VERSION}" -trimpath -o mosdns

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
      linux-headers \
      build-base \
      zlib-dev \
      openssl \
      openssl-dev \
      tor \
      libevent-dev \
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
      supervisor \
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
   mkdir -p /etc/mosdns && \
   /bin/zsh
   
# 拷贝mosdns
COPY --from=builder /src/mosdns /usr/bin/mosdns

# 容器信号处理
STOPSIGNAL SIGQUIT

# 挂载目录
VOLUME /etc/mosdns

# 执行命令
CMD /usr/bin/mosdns start --dir /etc/mosdns
