FROM buildpack-deps:stretch-scm

ARG DOCKERFILE_PATH
ARG SOURCE_COMMIT
ARG SOURCE_TYPE
ARG APT_PROXY
ARG DOCKER_VERSION
ARG HELM_VERSION
ARG K3S_VERSION

ENV http_proxy="${APT_PROXY}" https_proxy="${APT_PROXY}"

USER root

# Collect all of the packages needed for our composite of tools into one place

ENV DEBIAN_FRONTEND=noninteractive container=docker
RUN if [ -n "${APT_PROXY}" ]; then echo "Acquire::HTTP::Proxy \"${APT_PROXY}\";\nAcquire::HTTPS::Proxy false;\n" >> /etc/apt/apt.conf.d/01proxy; cat /etc/apt/apt.conf.d/01proxy; fi &&\
    apt-get update && apt-get install -yq --no-install-recommends \
	apt-transport-https \
	ca-certificates \
	curl \
	gnupg2 \
	software-properties-common \
	bzip2 \
	unzip \
	xz-utils \
	bison \
	libgdbm-dev \
	ruby \
	autoconf \
	automake \
	libtool \
	build-essential \
	gcc \
	make \
	zlib1g-dev \
	libssl-dev \
	tcl \
	tk \
	dpkg-dev \
	tcl-dev \
	tk-dev \
	libssl-dev \
	jq \
	netcat-openbsd \
	collectl colplot \
	# Docker deps
	e2fsprogs iptables xfsprogs kmod \
	# Google Chrome deps
	xvfb fontconfig libxss1 libappindicator3-1 libindicator7 libpango1.0-0 fonts-liberation xdg-utils gconf-service libasound2 libatk-bridge2.0-0 libgtk-3-0 libnspr4 libnss3 lsb-release

#
# OpenJDK 8
#
# https://github.com/docker-library/openjdk/blob/master/8/jdk/Dockerfile


# A few reasons for installing distribution-provided OpenJDK:
#
#  1. Oracle.  Licensing prevents us from redistributing the official JDK.
#
#  2. Compiling OpenJDK also requires the JDK to be installed, and it gets
#     really hairy.
#
#     For some sample build times, see Debian's buildd logs:
#       https://buildd.debian.org/status/logs.php?pkg=openjdk-8

# RUN apt-get update && apt-get install -y --no-install-recommends \
# 	bzip2 \
# 	unzip \
# 	xz-utils \
# 	&& rm -rf /var/lib/apt/lists/*

# Default to UTF-8 file.encoding
ENV LANG C.UTF-8

# add a simple script that can auto-detect the appropriate JAVA_HOME value
# based on whether the JDK or only the JRE is installed
RUN { \
	echo '#!/bin/sh'; \
	echo 'set -e'; \
	echo; \
	echo 'dirname "$(dirname "$(readlink -f "$(which javac || which java)")")"'; \
	} > /usr/local/bin/docker-java-home \
	&& chmod +x /usr/local/bin/docker-java-home

# do some fancy footwork to create a JAVA_HOME that's cross-architecture-safe
RUN ln -svT "/usr/lib/jvm/java-8-openjdk-$(dpkg --print-architecture)" /docker-java-home
ENV JAVA_HOME /docker-java-home

ENV JAVA_VERSION 8u181
ENV JAVA_DEBIAN_VERSION 8u212-b01-1~deb9u1
ENV _JAVA_OPTIONS="-XX:+UnlockExperimentalVMOptions -XX:+UseCGroupMemoryLimitForHeap"

RUN set -ex; \
	\
	# deal with slim variants not having man page directories (which causes "update-alternatives" to fail)
	if [ ! -d /usr/share/man/man1 ]; then \
	mkdir -p /usr/share/man/man1; \
	fi; \
	\
	apt-get update; \
	apt-get install -y --no-install-recommends \
	openjdk-8-jdk="$JAVA_DEBIAN_VERSION" \
	; \
	rm -rf /var/lib/apt/lists/*; \
	\
	# verify that "docker-java-home" returns what we expect
	[ "$(readlink -f "$JAVA_HOME")" = "$(docker-java-home)" ]; \
	\
	# update-alternatives so that future installs of other OpenJDK versions don't change /usr/bin/java
	update-alternatives --get-selections | awk -v home="$(readlink -f "$JAVA_HOME")" 'index($3, home) == 1 { $2 = "manual"; print | "update-alternatives --set-selections" }'; \
	# ... and verify that it actually worked for one of the alternatives we care about
	update-alternatives --query java | grep -q 'Status: manual'

# If you're reading this and have any feedback on how this image could be
# improved, please open an issue or a pull request so we can discuss it!
#
#   https://github.com/docker-library/openjdk/issues

#
# Gradle
# https://github.com/keeganwitt/docker-gradle/blob/fac6450faeec2232e1ed15051a751236e40ffda2/jdk8/Dockerfile

ENV GRADLE_HOME="/opt/gradle" GRADLE_VERSION="4.10.3"

ARG GRADLE_DOWNLOAD_SHA256=8626cbf206b4e201ade7b87779090690447054bc93f052954c78480fa6ed186e
RUN set -o errexit -o nounset \
	&& echo "Downloading Gradle" \
	&& wget --no-verbose --output-document=gradle.zip "https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip" \
	&& echo "Checking download hash" \
	&& echo "${GRADLE_DOWNLOAD_SHA256} *gradle.zip" | sha256sum --check - \
	&& echo "Installing Gradle" \
	&& unzip gradle.zip \
	&& rm gradle.zip \
	&& mv "gradle-${GRADLE_VERSION}" "${GRADLE_HOME}/" \
	&& ln --symbolic "${GRADLE_HOME}/bin/gradle" /usr/bin/gradle \
	&& echo "Adding gradle user and group" \
	&& groupadd --system --gid 1000 gradle \
	&& useradd --system --gid gradle --uid 1000 --shell /bin/bash --create-home gradle \
	&& mkdir /home/gradle/.gradle \
	&& chown --recursive gradle:gradle /home/gradle

# Create Gradle volume
VOLUME "/home/gradle/.gradle"
WORKDIR /home/gradle

RUN set -o errexit -o nounset \
	&& echo "Testing Gradle installation" \
	&& gradle --version

#
# Ruby 2.4.4
#

# from https://github.com/docker-library/ruby/blob/e98bec810e6f1bd88ad0106f2e3b3f3291f5f5bb/2.4/Dockerfile
# skip installing gem documentation
RUN mkdir -p /usr/local/etc \
	&& { \
		echo 'install: --no-document'; \
		echo 'update: --no-document'; \
	} >> /usr/local/etc/gemrc

ENV RUBY_MAJOR="2.4" \
    RUBY_VERSION="2.4.4" \
	RUBY_DOWNLOAD_SHA256="1d0034071d675193ca769f64c91827e5f54cb3a7962316a41d5217c7bc6949f0" \
    RUBYGEMS_VERSION="2.6.14.1" \
    BUNDLER_VERSION="1.16.2"

# some of ruby's build scripts are written in ruby
#   we purge system ruby later to make sure our final image uses what we just built
RUN set -ex \
	&& wget -O ruby.tar.xz "https://cache.ruby-lang.org/pub/ruby/${RUBY_MAJOR%-rc}/ruby-$RUBY_VERSION.tar.xz" \
	&& echo "$RUBY_DOWNLOAD_SHA256 *ruby.tar.xz" | sha256sum -c - \
	&& mkdir -p /usr/src/ruby \
	&& tar -xJf ruby.tar.xz -C /usr/src/ruby --strip-components=1 \
	&& rm ruby.tar.xz \
	&& cd /usr/src/ruby \
# hack in "ENABLE_PATH_CHECK" disabling to suppress:
#   warning: Insecure world writable dir
	&& { \
		echo '#define ENABLE_PATH_CHECK 0'; \
		echo; \
		cat file.c; \
	} > file.c.new \
	&& mv file.c.new file.c \
	&& autoconf \
	&& ./configure --disable-install-doc --enable-shared \
	&& make -j"$(nproc)" \
	&& make install \
	&& cd / \
	&& rm -r /usr/src/ruby \
	&& gem update --system "$RUBYGEMS_VERSION"


RUN gem install bundler --version "$BUNDLER_VERSION"

# install things globally, for great justice
# and don't create ".bundle" in all our apps
ENV GEM_HOME="/usr/local/bundle" \
    BUNDLE_PATH="$GEM_HOME" \
	BUNDLE_BIN="$GEM_HOME/bin" \
	BUNDLE_SILENCE_ROOT_WARNING=1 \
	BUNDLE_APP_CONFIG="$GEM_HOME" \
    PATH="$BUNDLE_BIN:$PATH"
RUN mkdir -p "$GEM_HOME" "$BUNDLE_BIN" \
	&& chmod 777 "$GEM_HOME" "$BUNDLE_BIN"

#
# Python 2.7.15
#

# https://github.com/docker-library/python/blob/master/2.7/stretch/Dockerfile
# ensure local python is preferred over distribution python
# http://bugs.python.org/issue19846
# > At the moment, setting "LANG=C" on a Linux system *fundamentally breaks Python 3*, and that's not OK.
ENV PATH="/usr/local/bin:$PATH" \
    LANG="C.UTF-8" \
    GPG_KEY="C01E1CAD5EA2C4F0B8E3571504C367C218ADD4FF" \
    PYTHON_VERSION="2.7.15"

RUN set -ex \
	&& wget -O python.tar.xz "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz" \
	&& wget -O python.tar.xz.asc "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz.asc" \
	&& export GNUPGHOME="$(mktemp -d)" \
	&& gpg --no-tty --keyserver keyserver.ubuntu.com --recv-keys "$GPG_KEY" \
	&& gpg --no-tty --batch --verify python.tar.xz.asc python.tar.xz \
	&& rm -rf "$GNUPGHOME" python.tar.xz.asc \
	&& mkdir -p /usr/src/python \
	&& tar -xJC /usr/src/python --strip-components=1 -f python.tar.xz \
	&& rm python.tar.xz \
	&& cd /usr/src/python \
	&& gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
	&& ./configure \
		--build="$gnuArch" \
		--enable-shared \
		--enable-unicode=ucs4 \
	&& make -j "$(nproc)" \
	&& make install \
	&& ldconfig \
	&& find /usr/local -depth \
		\( \
			\( -type d -a \( -name test -o -name tests \) \) \
			-o \
			\( -type f -a \( -name '*.pyc' -o -name '*.pyo' \) \) \
		\) -exec rm -rf '{}' + \
	&& rm -rf /usr/src/python

# if this is called "PIP_VERSION", pip explodes with "ValueError: invalid truth value '<VERSION>'"
ENV PYTHON_PIP_VERSION 10.0.1

RUN set -ex; \
	wget -O get-pip.py 'https://bootstrap.pypa.io/get-pip.py'; \
	python get-pip.py \
		--disable-pip-version-check \
		--no-cache-dir \
		"pip==$PYTHON_PIP_VERSION" \
	; \
	pip --version; \
	find /usr/local -depth \
		\( \
			\( -type d -a \( -name test -o -name tests \) \) \
			-o \
			\( -type f -a \( -name '*.pyc' -o -name '*.pyo' \) \) \
		\) -exec rm -rf '{}' +; \
	rm -f get-pip.py

# install "virtualenv", since the vast majority of users of this image will want it
RUN pip install --no-cache-dir virtualenv awscli azure-cli

#
# Docker in Docker (dind)
# https://github.com/aws/aws-codebuild-docker-images/blob/master/ubuntu/docker/17.09.0/Dockerfile
#
ENV DOCKER_BUCKET="download.docker.com" \
	DOCKER_VERSION="18.09.3" \
	DOCKER_CHANNEL="stable" \
	DIND_COMMIT="52379fa76dee07ca038624d639d9e14f4fb719ff" \
	DOCKER_COMPOSE_VERSION="1.23.2"

# From the docker:17.09
RUN set -x \
	&& curl -fSL "https://${DOCKER_BUCKET}/linux/static/${DOCKER_CHANNEL}/x86_64/docker-${DOCKER_VERSION}.tgz" -o docker.tgz \
	&& tar --extract --file docker.tgz --strip-components 1  --directory /usr/local/bin/ \
	&& rm docker.tgz \
	&& docker -v \
	# From the docker dind 17.09
	# && apt-get install -y --no-install-recommends \
	# e2fsprogs iptables xfsprogs xz-utils kmod \
	&& addgroup docker \
	&& usermod -G docker gradle \
	# set up subuid/subgid so that "--userns-remap=default" works out-of-the-box
	&& addgroup dockremap \
	&& useradd -g dockremap dockremap \
	&& echo 'dockremap:165536:65536' >> /etc/subuid \
	&& echo 'dockremap:165536:65536' >> /etc/subgid \
	&& wget "https://raw.githubusercontent.com/moby/moby/${DIND_COMMIT}/hack/dind" -O /usr/local/bin/dind \
	&& curl -fkSL https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-Linux-x86_64 > /usr/local/bin/docker-compose \
	&& chmod +x /usr/local/bin/dind /usr/local/bin/docker-compose \
	# Ensure docker-compose works
	&& docker-compose version \
	&& rm -rf /var/lib/apt/lists/* \
	&& apt-get clean \
	&& rm -f /etc/apt/apt.conf.d/01proxy

# Google Chrome for headless testing
RUN export CHROME_VERSION=stable_current &&\
	curl --show-error --location --fail --retry 3 -o /tmp/google-chrome-${CHROME_VERSION}_amd64.deb https://dl.google.com/linux/direct/google-chrome-${CHROME_VERSION}_amd64.deb &&\
    dpkg -i /tmp/google-chrome-${CHROME_VERSION}_amd64.deb &&\
	rm /tmp/google-chrome-${CHROME_VERSION}_amd64.deb

# Terraform
ENV TERRAFORM_VERSION="0.11.11" \
	TERRAFORM_SHA256="94504f4a67bad612b5c8e3a4b7ce6ca2772b3c1559630dfd71e9c519e3d6149c"

RUN curl -fL -o /tmp/terraform.zip https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip &&\
	echo "${TERRAFORM_SHA256} /tmp/terraform.zip" | sha256sum --check - &&\
    cd /usr/bin &&\
	unzip /tmp/terraform.zip &&\
	rm /tmp/terraform.zip &&\
	chmod +x /usr/bin/terraform

# k3s
RUN curl -fL -o /usr/bin/k3s https://github.com/rancher/k3s/releases/download/v0.1.0/k3s &&\
    chmod +x /usr/bin/k3s &&\
	curl -fL -o /opt/local-path-storage.yaml https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml &&\
	echo '#!/bin/sh\nexec k3s kubectl $@' > /usr/bin/kubectl &&\
	chmod +x /usr/bin/kubectl

# Kubernetes Helm
RUN curl -fL -o /tmp/helm.tgz https://storage.googleapis.com/kubernetes-helm/helm-v${HELM_VERSION}-linux-amd64.tar.gz &&\
	tar -xzf /tmp/helm.tgz --strip-components=1 -C /usr/bin linux-amd64/helm linux-amd64/tiller &&\
	rm /tmp/helm.tgz &&\
	chmod +x /usr/bin/helm /usr/bin/tiller

ENV HELM_VERSION="${HELM_VERSION}" \
	K3S_VERSION="${K3S_VERSION}" \
    KUBECONFIG="/etc/rancher/k3s/k3s.yaml"

COPY k3s-${K3S_VERSION}-${HELM_VERSION}.tar.gz /opt/
COPY *.sh /usr/local/bin/
VOLUME ["/var/lib/docker"]

ENV http_proxy="" https_proxy=""

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["gradle"]

LABEL maintainer="Patrick Double <pat@patdouble.com>" \
      org.label-schema.docker.dockerfile="$DOCKERFILE_PATH/Dockerfile" \
      org.label-schema.license="GPLv2" \
	  org.label-schema.name="Gradle build base with Gradle ${GRADLE_VERSION}, OpenJDK ${JAVA_VERSION}, Docker (dind) ${DOCKER_VER}, Docker Compose ${DOCKER_COMPOSE_VER}, Kubernetes via K3S ${K3S_VERSION}, Ruby ${RUBY_VERSION}, Python ${PYTHON_VERSION}, Terraform ${TERRAFORM_VERSION} on Debian Jessie. Intended for building web applications based on the JVM and common frontend technologies." \
	  org.label-schema.url="https://bitbucket.org/double16/gradle-webapp-build-base" \
      org.label-schema.vcs-ref=$SOURCE_COMMIT \
      org.label-schema.vcs-type="$SOURCE_TYPE" \
      org.label-schema.vcs-url="https://bitbucket.org/double16/gradle-webapp-build-base.git"
