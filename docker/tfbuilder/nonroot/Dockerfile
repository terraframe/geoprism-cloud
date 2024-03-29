FROM centos:8

# Install Docker  https://docs.docker.com/engine/install/centos/
RUN yum install -y yum-utils
RUN yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
RUN yum install -y docker-ce docker-ce-cli containerd.io

RUN dnf makecache \
    && dnf install -y unzip which zip python3 wget git curl gzip
RUN python3 -m pip install --upgrade pip

# Install Github CLI
RUN wget https://cli.github.com/packages/rpm/gh-cli.repo -O /etc/yum.repos.d/gh-cli.repo
RUN yum install -y gh

# Install git-lfs
RUN curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.rpm.sh | bash
RUN yum -y install git-lfs

RUN groupadd --gid 1000 jenkins \
    && useradd --home-dir /home/jenkins --create-home --uid 1000 \
        --gid 1000 --shell /bin/sh --skel /dev/null jenkins
USER jenkins
ENV PATH="/home/jenkins/.local/bin:$PATH"

# Install SDKMan
RUN curl -s "https://get.sdkman.io" | bash

ENV SDKMAN_DIR=/home/jenkins/.sdkman

RUN source "/home/jenkins/.sdkman/bin/sdkman-init.sh" \
    && yes | sdk update \
    && yes | sdk install java 8.0.265-open \
    && yes | sdk install gradle 5.4.1 \
    && yes | sdk install maven

ENV JAVA_HOME="$SDKMAN_DIR/candidates/java/current"
ENV MAVEN_HOME="$SDKMAN_DIR/candidates/maven/current"
ENV GRADLE_HOME="$SDKMAN_DIR/candidates/gradle/current"
ENV PATH="$JAVA_HOME/bin:$MAVEN_HOME/bin:$GRADLE_HOME/bin:$PATH"

# Install pip and python dependencies
#RUN python3 -m pip install --upgrade pip \
#    && python3 -m pip install boto boto3 ansible docker awscli
RUN pip3 install boto3 ansible docker awscli

   
# Ansible dependencies
RUN ansible-galaxy collection install amazon.aws community.general

# Install virtualenv and pipx
#RUN python3 -m pip install --upgrade pip
#RUN python3 -m pip install pipx
#RUN python3 -m pipx ensurepath
#RUN pipx install virtualenv
#ENV PATH="/home/jenkins/.local/pipx/venvs/virtualenv/bin:$PATH"

# Install git-lfs
RUN git lfs install

# Install NVM
ENV NVM_DIR /home/jenkins/.nvm
RUN wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.37.0/install.sh | bash

# Add nexus internal ip to /etc/hosts so we know how to reach it.
#RUN sh -c "echo 'ec2-52-25-68-156.us-west-2.compute.amazonaws.com nexus.terraframe.com' >> /etc/hosts"

# Install Android SDK
RUN wget https://dl.google.com/android/repository/commandlinetools-linux-6858069_latest.zip -O /tmp/android-studio.zip \
    && mkdir -p /tmp/android-sdk/cmdline-tools \
    && unzip -C /tmp/android-studio.zip -d /tmp/android-sdk \
    && mkdir -p /home/jenkins/.android-sdk/cmdline-tools/latest && mv /tmp/android-sdk/cmdline-tools/* /home/jenkins/.android-sdk/cmdline-tools/latest

ENV ANDROID_HOME=/home/jenkins/.android-sdk
RUN yes | $ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager --licenses

# Add a few known hosts so we can use git and SSH
RUN mkdir -p /home/jenkins/.ssh && ssh-keyscan -t rsa github.com >> /home/jenkins/.ssh/known_hosts

CMD ["bash"]
