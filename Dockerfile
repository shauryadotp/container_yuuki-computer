FROM debian:trixie-slim

ARG DEBIAN_FRONTEND=noninteractive
ARG USERNAME=yuuki
ARG UID=1000
ARG GID=1000

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TZ=Asia/Kolkata \
    HOME=/home/${USERNAME}

# Base packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    gnupg \
    openssh-server \
    openssh-client \
    iproute2 \
    fastfetch \
    curl \
    wget \
    git \
    sudo \
    bash \
    locales \
    tzdata \
    unzip \
    xz-utils \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime \
    && echo "${TZ}" > /etc/timezone \
    && rm -rf /var/lib/apt/lists/*

# Prevent Playwright / Puppeteer from fetching bundled Chrome; route to Helium
ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 \
    PUPPETEER_SKIP_DOWNLOAD=true \
    CHROME_PATH=/usr/bin/helium \
    CHROME_BIN=/usr/bin/helium \
    BROWSER_PATH=/usr/bin/helium

# User & sudo setup
RUN groupadd --gid ${GID} ${USERNAME} \
    && useradd --uid ${UID} --gid ${GID} -m -s /bin/bash -p '*' ${USERNAME} \
    && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} \
    && chmod 0440 /etc/sudoers.d/${USERNAME}

# Prepare user SSH dir
RUN mkdir -p /home/${USERNAME}/.ssh && \
    chmod 700 /home/${USERNAME}/.ssh && \
    chown -R ${USERNAME}:${GID} /home/${USERNAME}/.ssh

# Set up tool paths (FNM uses aliases/default for its global default binary path)
ENV FNM_DIR="/home/${USERNAME}/.fnm"
ENV BUN_INSTALL="/home/${USERNAME}/.bun"
ENV USER_PATH="/home/${USERNAME}/.local/bin:/home/${USERNAME}/.bun/bin:/home/${USERNAME}/.fnm/aliases/default/bin"
ENV PATH="${USER_PATH}:${PATH}"

RUN mkdir -p /run/sshd /etc/ssh/sshd_config.d && \
    printf "Port 22\nPasswordAuthentication no\nKbdInteractiveAuthentication no\nPubkeyAuthentication yes\nUsePAM no\nSetEnv PATH=%s\n" "${PATH}" > /etc/ssh/sshd_config.d/99-hardened.conf && \
    printf "Host *\n    StrictHostKeyChecking accept-new\n" >> /etc/ssh/ssh_config

WORKDIR /home/${USERNAME}
USER ${USERNAME}

ENV GIT_AUTHOR_NAME="Yuuki Ai" \
    GIT_AUTHOR_EMAIL="yuuki-git@petalbit.in" \
    GIT_COMMITTER_NAME="Yuuki Ai" \
    GIT_COMMITTER_EMAIL="yuuki-git@petalbit.in"

    # 1. bun
    RUN curl -fsSL https://bun.sh/install | bash

    # 2. fnm + Node
    RUN curl -fsSL https://fnm.vercel.app/install | bash -s -- --install-dir "${FNM_DIR}" --skip-shell && \
        ${FNM_DIR}/fnm install 24 && \
        ${FNM_DIR}/fnm default 24

    # 3. uv
    RUN curl -LsSf https://astral.sh/uv/install.sh | sh

    # login/interactive PATH (Docker ENV + sshd SetEnv get reset by /etc/profile)
    RUN printf '%s\n' \
          '' \
          '# user tools' \
          'export BUN_INSTALL="$HOME/.bun"' \
          'export FNM_DIR="$HOME/.fnm"' \
          'export PATH="$HOME/.local/bin:$BUN_INSTALL/bin:$FNM_DIR:$FNM_DIR/aliases/default/bin:$PATH"' \
          'command -v fnm >/dev/null && eval "$(fnm env --use-on-cd --shell bash)"' \
          >> ~/.profile && \
        printf '%s\n' \
          '' \
          '# user tools' \
          'export BUN_INSTALL="$HOME/.bun"' \
          'export FNM_DIR="$HOME/.fnm"' \
          'export PATH="$HOME/.local/bin:$BUN_INSTALL/bin:$FNM_DIR:$FNM_DIR/aliases/default/bin:$PATH"' \
          'command -v fnm >/dev/null && eval "$(fnm env --use-on-cd --shell bash)"' \
          >> ~/.bashrc

# 5. njs packages
# RUN bun add -g agent-browser

USER root
EXPOSE 22
CMD ["/usr/sbin/sshd", "-D"]
