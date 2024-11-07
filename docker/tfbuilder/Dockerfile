FROM quay.io/centos/centos:stream9

# upgrade packages
RUN dnf upgrade --setopt=install_weak_deps=False -y && \
    dnf clean all && \
    rm -rf /tmp/* && \
    rm -rf /var/cache/yum && \
    rm -rf /var/cache/dnf && \
    find /var/log -type f -name '*.log' -delete

# Install Docker  https://docs.docker.com/engine/install/centos/
RUN yum install -y yum-utils
RUN yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
RUN yum install -y docker-ce docker-ce-cli containerd.io

RUN dnf makecache \
    && dnf install -y unzip which zip python3 python3-pip wget git gzip

# Install SDKMan
RUN curl -s "https://get.sdkman.io" | bash

ENV SDKMAN_DIR=/root/.sdkman

RUN source "/root/.sdkman/bin/sdkman-init.sh" \
    && yes | sdk update \
    && yes | sdk install java 11.0.25-ms \
    && yes | sdk install gradle 5.4.1 \
    && yes | sdk install maven

ENV JAVA_HOME="$SDKMAN_DIR/candidates/java/current"
ENV MAVEN_HOME="$SDKMAN_DIR/candidates/maven/current"
ENV GRADLE_HOME="$SDKMAN_DIR/candidates/gradle/current"
ENV PATH="$JAVA_HOME/bin:$MAVEN_HOME/bin:$GRADLE_HOME/bin:$PATH"

# Install pip and python dependencies
RUN python3 -m pip install --upgrade pip \
    && python3 -m pip install boto boto3 ansible docker awscli
    
# Ansible dependencies
RUN ansible-galaxy collection install amazon.aws community.general

# Install virtualenv and pipx
#RUN python3 -m pip install --upgrade pip
#RUN python3 -m pip install pipx
#RUN python3 -m pipx ensurepath
#RUN pipx install virtualenv
#ENV PATH="/root/.local/pipx/venvs/virtualenv/bin:$PATH"

# Install Github CLI
RUN wget https://cli.github.com/packages/rpm/gh-cli.repo -O /etc/yum.repos.d/gh-cli.repo
RUN yum install -y gh

# Install git-lfs
RUN curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.rpm.sh | bash
RUN yum -y install git-lfs
RUN git lfs install

# Install NVM
ENV NVM_DIR /root/.nvm
RUN mkdir -p /usr/local/nvm && wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.37.0/install.sh | bash

# Add nexus internal ip to /etc/hosts so we know how to reach it.
#RUN sh -c "echo 'ec2-52-25-68-156.us-west-2.compute.amazonaws.com nexus.terraframe.com' >> /etc/hosts"

# Install Android SDK
RUN wget https://dl.google.com/android/repository/commandlinetools-linux-6858069_latest.zip -O /tmp/android-studio.zip \
    && mkdir -p /tmp/android-sdk/cmdline-tools \
    && unzip -C /tmp/android-studio.zip -d /tmp/android-sdk \
    && mkdir -p /opt/android-sdk/cmdline-tools/latest && mv /tmp/android-sdk/cmdline-tools/* /opt/android-sdk/cmdline-tools/latest

ENV ANDROID_HOME=/opt/android-sdk
RUN yes | $ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager --licenses

# Add a few known hosts so we can use git and SSH
RUN mkdir -p /root/.ssh && ssh-keyscan -t rsa github.com >> /root/.ssh/known_hosts

# Add the OSGeo SSL certificates to the Java trust store
RUN echo | openssl s_client -showcerts -connect repo.osgeo.org:443 -servername repo.osgeo.org 2>/dev/null | \
    awk '/-----BEGIN CERTIFICATE-----/{i++} /-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/ { print > "osgeo_cert_" i ".crt" }'
RUN for CERT in osgeo_cert_*.crt; do \
    keytool -importcert -file "$CERT" -alias "$(basename "$CERT" .crt)" -keystore "$JAVA_HOME/lib/security/cacerts" -storepass changeit -noprompt; \
    done


CMD ["bash"]
