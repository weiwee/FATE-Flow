# Dazzle do not supports ARG TRIGGER_REBUILD=2
FROM gitpod/workspace-base:latest

RUN echo "ws full starts"

### Install C/C++ compiler and associated tools ###
LABEL dazzle/layer=lang-c
LABEL dazzle/test=tests/lang-c.yaml
USER root
# Dazzle does not rebuild a layer until one of its lines are changed. Increase this counter to rebuild this layer.
ENV TRIGGER_REBUILD=3
RUN curl -o /var/lib/apt/dazzle-marks/llvm.gpg -fsSL https://apt.llvm.org/llvm-snapshot.gpg.key \
    && apt-key add /var/lib/apt/dazzle-marks/llvm.gpg \
    && echo "deb https://apt.llvm.org/focal/ llvm-toolchain-focal main" >> /etc/apt/sources.list.d/llvm.list \
    && install-packages \
        clang \
        clangd \
        clang-format \
        clang-tidy \
        gdb \
        lld

### Homebrew ###
LABEL dazzle/layer=tool-brew
LABEL dazzle/test=tests/tool-brew.yaml
USER gitpod
# Dazzle does not rebuild a layer until one of its lines are changed. Increase this counter to rebuild this layer.
ENV TRIGGER_BREW_REBUILD=4
RUN mkdir ~/.cache && /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
ENV PATH=$PATH:/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin/
ENV MANPATH="$MANPATH:/home/linuxbrew/.linuxbrew/share/man"
ENV INFOPATH="$INFOPATH:/home/linuxbrew/.linuxbrew/share/info"
ENV HOMEBREW_NO_AUTO_UPDATE=1

RUN sudo apt remove -y cmake \
    && brew install cmake

### Java ###
## Place '.gradle' and 'm2-repository' in /workspace because (1) that's a fast volume, (2) it survives workspace-restarts and (3) it can be warmed-up by pre-builds.
LABEL dazzle/layer=lang-java
LABEL dazzle/test=tests/lang-java.yaml
USER gitpod
RUN curl -fsSL "https://get.sdkman.io" | bash \
 && bash -c ". /home/gitpod/.sdkman/bin/sdkman-init.sh \
             && sdk install java 11.0.13.fx-zulu \
             && sdk install gradle \
             && sdk install maven \
             && sdk flush archives \
             && sdk flush temp \
             && mkdir /home/gitpod/.m2 \
             && printf '<settings>\n  <localRepository>/workspace/m2-repository/</localRepository>\n</settings>\n' > /home/gitpod/.m2/settings.xml \
             && echo 'export SDKMAN_DIR=\"/home/gitpod/.sdkman\"' >> /home/gitpod/.bashrc.d/99-java \
             && echo '[[ -s \"/home/gitpod/.sdkman/bin/sdkman-init.sh\" ]] && source \"/home/gitpod/.sdkman/bin/sdkman-init.sh\"' >> /home/gitpod/.bashrc.d/99-java"
# above, we are adding the sdkman init to .bashrc (executing sdkman-init.sh does that), because one is executed on interactive shells, the other for non-interactive shells (e.g. plugin-host)
ENV GRADLE_USER_HOME=/workspace/.gradle/

### Python ###
LABEL dazzle/layer=lang-python
LABEL dazzle/test=tests/lang-python.yaml
USER gitpod
RUN sudo install-packages python3-pip

ENV PATH=$HOME/.pyenv/bin:$HOME/.pyenv/shims:$PATH
RUN curl -fsSL https://github.com/pyenv/pyenv-installer/raw/master/bin/pyenv-installer | bash \
    && { echo; \
        echo 'eval "$(pyenv init -)"'; \
        echo 'eval "$(pyenv virtualenv-init -)"'; } >> /home/gitpod/.bashrc.d/60-python \
    && pyenv update \
    && pyenv install 3.6.12 \
    && pyenv global 3.6.12 \
    && python3 -m pip install --no-cache-dir --upgrade pip \
    && python3 -m pip install --no-cache-dir --upgrade \
        setuptools wheel virtualenv pipenv pylint rope flake8 \
        mypy autopep8 pep8 pylama pydocstyle bandit notebook \
        twine \
    && sudo rm -rf /tmp/*
ENV PIP_USER=no
ENV PIPENV_VENV_IN_PROJECT=true
ENV PYTHONUSERBASE=/workspace/.pip-modules
ENV PATH=$PYTHONUSERBASE/bin:$PATH

### Rust ###
LABEL dazzle/layer=lang-rust
LABEL dazzle/test=tests/lang-rust.yaml
USER gitpod
RUN cp /home/gitpod/.profile /home/gitpod/.profile_orig && \
    curl -fsSL https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain 1.56.1 \
    && .cargo/bin/rustup component add \
        rls \
        rust-analysis \
        rust-src \
        rustfmt \
    && .cargo/bin/rustup completions bash | sudo tee /etc/bash_completion.d/rustup.bash-completion > /dev/null \
    && .cargo/bin/rustup completions bash cargo | sudo tee /etc/bash_completion.d/rustup.cargo-bash-completion > /dev/null \
    && grep -v -F -x -f /home/gitpod/.profile_orig /home/gitpod/.profile > /home/gitpod/.bashrc.d/80-rust
ENV PATH=$PATH:$HOME/.cargo/bin
# TODO: setting CARGO_HOME to /workspace/.cargo avoids manual updates. Remove after full workspace backups are GA.
ENV CARGO_HOME=/workspace/.cargo
ENV PATH=$CARGO_HOME/bin:$PATH

RUN sudo mkdir -p $CARGO_HOME \
    && sudo chown -R gitpod:gitpod $CARGO_HOME

RUN bash -lc "cargo install cargo-watch cargo-edit cargo-tree cargo-workspaces"

### Docker ###
LABEL dazzle/layer=tool-docker
LABEL dazzle/test=tests/tool-docker.yaml
USER root
ENV TRIGGER_REBUILD=3
# https://docs.docker.com/engine/install/ubuntu/
RUN curl -o /var/lib/apt/dazzle-marks/docker.gpg -fsSL https://download.docker.com/linux/ubuntu/gpg \
    && apt-key add /var/lib/apt/dazzle-marks/docker.gpg \
    && add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
    && install-packages docker-ce docker-ce-cli containerd.io

RUN curl -o /usr/bin/slirp4netns -fsSL https://github.com/rootless-containers/slirp4netns/releases/download/v1.1.12/slirp4netns-$(uname -m) \
    && chmod +x /usr/bin/slirp4netns

RUN curl -o /usr/local/bin/docker-compose -fsSL https://github.com/docker/compose/releases/download/1.29.2/docker-compose-Linux-x86_64 \
    && chmod +x /usr/local/bin/docker-compose

# https://github.com/wagoodman/dive
RUN curl -o /tmp/dive.deb -fsSL https://github.com/wagoodman/dive/releases/download/v0.10.0/dive_0.10.0_linux_amd64.deb \
    && apt install /tmp/dive.deb \
    && rm /tmp/dive.deb

### Install Tailscale ###
LABEL dazzle/layer=tool-tailscale
LABEL dazzle/test=tests/tool-tailscale.yaml
USER root
# Dazzle does not rebuild a layer until one of its lines are changed. Increase this counter to rebuild this layer.
ENV TRIGGER_REBUILD=1

RUN curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/focal.gpg | sudo apt-key add - \
    && curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/focal.list | sudo tee /etc/apt/sources.list.d/tailscale.list \
    && apt-get update \
    && apt-get install -y tailscale

### Prologue (built across all layers) ###
LABEL dazzle/layer=dazzle-prologue
LABEL dazzle/test=tests/prologue.yaml
USER root
RUN curl -o /usr/bin/dazzle-util -fsSL https://github.com/csweichel/dazzle/releases/download/v0.0.3/dazzle-util_0.0.3_Linux_x86_64 \
    && chmod +x /usr/bin/dazzle-util
# merge dpkg status files
RUN cp /var/lib/dpkg/status /tmp/dpkg-status \
    && for i in $(ls /var/lib/apt/dazzle-marks/*.status); do /usr/bin/dazzle-util debian dpkg-status-merge /tmp/dpkg-status $i > /tmp/dpkg-status; done \
    && cp -f /var/lib/dpkg/status /var/lib/dpkg/status-old \
    && cp -f /tmp/dpkg-status /var/lib/dpkg/status
# correct the path as per https://github.com/gitpod-io/gitpod/issues/4508
ENV PATH=$PATH:/usr/games
# merge GPG keys for trusted APT repositories
RUN for i in $(ls /var/lib/apt/dazzle-marks/*.gpg); do apt-key add "$i"; done
# copy tests to enable the self-test of this image
COPY tests /var/lib/dazzle/tests

# share env see https://github.com/gitpod-io/workspace-images/issues/472
RUN echo "PATH="${PATH}"" | sudo tee /etc/environment

USER gitpod
