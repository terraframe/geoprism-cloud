FROM quay.io/centos/centos:stream10

# upgrade packages
RUN dnf upgrade --setopt=install_weak_deps=False -y && \
    dnf clean all && \
    rm -rf /tmp/* && \
    rm -rf /var/cache/yum && \
    rm -rf /var/cache/dnf && \
    find /var/log -type f -name '*.log' -delete

# Install Docker  https://docs.docker.com/engine/install/centos/
RUN dnf install -y dnf-plugins-core
RUN dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
RUN dnf install -y docker-ce docker-ce-cli containerd.io

RUN dnf makecache \
    && dnf install -y unzip which zip python3 python3-pip wget git gzip openssl

# Install SDKMan
RUN curl -s "https://get.sdkman.io" | bash

ENV SDKMAN_DIR=/root/.sdkman

# Java 25. Leave JAVA_VERSION empty to auto-pick the newest 25.x build from JAVA_VENDOR
# (SDKMAN suffix: "tem" = Eclipse Temurin, "open" = jdk.java.net OpenJDK),
# or pin it: docker build --build-arg JAVA_VERSION=25.0.x-tem .
ARG JAVA_VENDOR="tem"
ARG JAVA_VERSION=""

RUN source "/root/.sdkman/bin/sdkman-init.sh" \
    && yes | sdk update \
    && JAVA_LIST="$(sdk list java < /dev/null 2>&1 | sed 's/\x1b\[[0-9;]*[A-Za-z]//g')" \
    && JV="${JAVA_VERSION:-$(printf '%s\n' "$JAVA_LIST" | tr -c 'A-Za-z0-9.\n-' '\n' | grep -xE "25(\.[0-9]+)*-${JAVA_VENDOR}" | sort -V | tail -1)}" \
    && if [ -z "$JV" ]; then echo "No Java 25 -${JAVA_VENDOR} build found in SDKMAN. 'sdk list java' returned:" >&2; printf '%s\n' "$JAVA_LIST" | head -80 >&2; exit 1; fi \
    && echo "Installing java $JV" \
    && yes | sdk install java "$JV" \
    && sdk default java "$JV" \
    && yes | sdk install gradle \
    && yes | sdk install maven

ENV JAVA_HOME="$SDKMAN_DIR/candidates/java/current"
ENV MAVEN_HOME="$SDKMAN_DIR/candidates/maven/current"
ENV GRADLE_HOME="$SDKMAN_DIR/candidates/gradle/current"
ENV PATH="$JAVA_HOME/bin:$MAVEN_HOME/bin:$GRADLE_HOME/bin:$PATH"

# Install pip and python dependencies
RUN python3 -m pip install --upgrade pip \
    && python3 -m pip install boto3 ansible docker awscli
    
# Ansible dependencies
RUN ansible-galaxy collection install amazon.aws community.general

# Install virtualenv and pipx
#RUN python3 -m pip install --upgrade pip
#RUN python3 -m pip install pipx
#RUN python3 -m pipx ensurepath
#RUN pipx install virtualenv
#ENV PATH="/root/.local/pipx/venvs/virtualenv/bin:$PATH"

# Install Github CLI
# (The repo keyring holds GitHub's old key, expired 2026-09-05, plus the new 7F38BBB5... key that
#  signs current packages. dnf prints an "expired" warning for the old one; it's harmless.)
RUN dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo \
    && dnf install -y gh

# Install git-lfs
RUN curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.rpm.sh | bash
RUN dnf install -y git-lfs
RUN git lfs install

# Install NVM
ENV NVM_DIR=/root/.nvm
# Installs the latest nvm release. Pin with: --build-arg NVM_VERSION=v0.x.y
ARG NVM_VERSION=""
RUN NV="${NVM_VERSION:-$(curl -fsSL -o /dev/null -w '%{url_effective}' https://github.com/nvm-sh/nvm/releases/latest | sed 's#.*/##')}" \
    && case "$NV" in v[0-9]*) ;; *) echo "Could not resolve latest nvm release (got '$NV')" >&2; exit 1;; esac \
    && echo "Installing nvm $NV" \
    && mkdir -p "$NVM_DIR" \
    && curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${NV}/install.sh" | bash

# Add nexus internal ip to /etc/hosts so we know how to reach it.
#RUN sh -c "echo 'ec2-52-25-68-156.us-west-2.compute.amazonaws.com nexus.terraframe.com' >> /etc/hosts"

# Install Android SDK
# Version + SHA-256 from https://developer.android.com/studio#command-line-tools-only
ARG ANDROID_CMDLINE_TOOLS=15859902
ARG ANDROID_CMDLINE_TOOLS_SHA256=4e4c464f145a7512b57d088ac6c278c03c9eea610886b35a5e0804e74eedf583
RUN wget -q https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS}_latest.zip -O /tmp/android-studio.zip \
    && echo "${ANDROID_CMDLINE_TOOLS_SHA256}  /tmp/android-studio.zip" | sha256sum -c - \
    && mkdir -p /tmp/android-sdk/cmdline-tools \
    && unzip -C /tmp/android-studio.zip -d /tmp/android-sdk \
    && mkdir -p /opt/android-sdk/cmdline-tools/latest && mv /tmp/android-sdk/cmdline-tools/* /opt/android-sdk/cmdline-tools/latest \
    && rm -rf /tmp/android-studio.zip /tmp/android-sdk

ENV ANDROID_HOME=/opt/android-sdk
RUN yes | $ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager --licenses

# Add a few known hosts so we can use git and SSH
RUN mkdir -p /root/.ssh && ssh-keyscan -t rsa github.com >> /root/.ssh/known_hosts

# Add the OSGeo SSL certificates to the Java trust store
RUN mkdir -p /tmp/osgeo-certs && cd /tmp/osgeo-certs \
    && echo | openssl s_client -showcerts -connect repo.osgeo.org:443 -servername repo.osgeo.org 2>/dev/null \
       | awk '/-----BEGIN CERTIFICATE-----/{i++} /-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/ { print > "osgeo_cert_" i ".crt" }' \
    && if ! ls osgeo_cert_*.crt >/dev/null 2>&1; then echo "Could not fetch certificates from repo.osgeo.org" >&2; exit 1; fi \
    && for CERT in osgeo_cert_*.crt; do \
         keytool -importcert -cacerts -file "$CERT" -alias "$(basename "$CERT" .crt)" -storepass changeit -noprompt; \
       done \
    && rm -rf /tmp/osgeo-certs


CMD ["bash"]
