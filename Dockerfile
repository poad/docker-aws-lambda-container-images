ARG DEBIAN_DIST_NAME=ubuntu
ARG DEBIAN_VERSION_NAME=noble
ARG SLIM_IMAGE_SUFFIX=
ARG UBUNTU_VERSION_NAME=noble

ARG NODE_VERSION=20

FROM --platform=$BUILDPLATFORM buildpack-deps:${DEBIAN_VERSION_NAME}-curl AS downloader

ARG NODE_VERSION

ARG BUILDPLATFORM
ARG TARGETPLATFORM

RUN BUILD_OPTIONS=""; TARGET="" \
  && if [ "${TARGETPLATFORM}" != "${BUILDPLATFORM}" ]; then \
        case "${TARGETPLATFORM}" in \
            'linux/arm64') \
                SUFFIX="-arm64" \
                export SUFFIX \
                ;; \
            *) \
                ;; \
        esac; \
    fi

WORKDIR /var/task/

ENV PATH ${PATH}:/root/.cargo/bin

RUN curl -fsSLo /tmp/setup "https://deb.nodesource.com/setup_${NODE_VERSION}.x" \
 && curl -sSLo /tmp/aws-lambda-rie "https://github.com/aws/aws-lambda-runtime-interface-emulator/releases/latest/download/aws-lambda-rie${SUFFIX}"

FROM --platform=$BUILDPLATFORM ${DEBIAN_DIST_NAME}:${DEBIAN_VERSION_NAME}${SLIM_IMAGE_SUFFIX} AS release

RUN BUILD_OPTIONS=""; TARGET="" \
  && if [ "${TARGETPLATFORM}" != "${BUILDPLATFORM}" ]; then \
        case "${TARGETPLATFORM}" in \
            'linux/arm64') \
                apt update -qqqqy \
                apt install -qqqqy --no-install-recommends g++-aarch64-linux-gnu libc6-dev-arm64-cross crossbuild-essential-arm64  \
                TARGET="aarch64-unknown-linux-gnu" \
                BUILD_OPTIONS="--target=${TARGET}" \
                ;; \
            'linux/amd64') \
                apt update -qqqqy \
                apt install -qqqqy --no-install-recommends g++-x86_64-linux-gnu libc6-dev-amd64-cross crossbuild-essential-amd64 \
                TARGET="x86_64-unknown-linux-gnu" \
                BUILD_OPTIONS="--target=${TARGET}" \
                ;; \
            *) \
                ;; \
        esac; \
    fi


ARG DEBIAN_FRONTEND=noninteractive

ARG DEPS="\
    autoconf \
    automake \
    g++ \
    gcc \
    libtool \
    make \
    cmake \
    unzip \
    libcurl4-openssl-dev \
    wget \
    binutils \
    software-properties-common \
    build-essential \
    libnss3-dev \
    zlib1g-dev \
    libgdbm-dev \
    libncurses5-dev \
    libssl-dev \
    libffi-dev \
    libreadline-dev \
    libsqlite3-dev \
    libbz2-dev \
    apt-utils \
    apt-transport-https \
    lsb-release \
    curl \
    gnupg \
    m4 \
    python3-dev \
"
ARG UBUNTU_VERSION_NAME

ENV LAMBDA_TASK_ROOT=/var/task
ENV LAMBDA_RUNTIME_DIR=/var/runtime
ENV PATH=${LAMBDA_TASK_ROOT}:/var/lang/bin:/usr/local/bin:/usr/bin:/bin:/opt/bin:${PATH}

COPY --from=downloader /tmp/setup /tmp/setup

ENV PNPM_HOME="/root/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
ENV SHELL="/bin/bash"

RUN apt-get update -qqq \
 && apt-get full-upgrade -qqqy \
 && apt-get install -qqy --no-install-recommends ${DEPS} ca-certificates python3-distutils-extra python3-venv \
 && chmod +x /tmp/setup \
 && /tmp/setup \
 && rm -rf /tmp/setup \
 && apt-get install -qqy --no-install-recommends nodejs \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* /var/log/apt/* /var/log/alternatives.log /var/log/dpkg.log /var/log/faillog /var/log/lastlog

WORKDIR /root

RUN corepack enable \
 && corepack prepare pnpm@latest --activate \
 && pnpm setup

WORKDIR /var/task/
 
RUN pnpm -g i aws-lambda-ric \
 && apt-get autoremove --purge -qqy ${DEPS} python3-dev \
 && rm -rf /var/lib/apt/lists/* /var/log/apt/* /var/log/alternatives.log /var/log/dpkg.log /var/log/faillog /var/log/lastlog \
 && mkdir -p /opt/extensions

COPY assets/bootstrap ${LAMBDA_TASK_ROOT}/bootstrap

RUN chmod +x "${LAMBDA_TASK_ROOT}/bootstrap"

RUN groupadd -g 10000 node \
 && useradd -g 10000 -l -m -s /usr/bin/bash -u 10000 node

WORKDIR ${LAMBDA_TASK_ROOT}

ENTRYPOINT [ "./bootstrap" ]

FROM release AS testing

COPY --from=downloader /tmp/aws-lambda-rie /usr/local/bin/aws-lambda-rie

RUN chmod +x /usr/local/bin/aws-lambda-rie

FROM testing
