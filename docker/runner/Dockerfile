# Custom GitHub Actions Runner with Node.js
# Based on official GitHub runner image for ARC compatibility
#
# The official runner images are minimal - this adds Node.js
# which is required for JavaScript-based actions (checkout, setup-terraform, etc.)

FROM ghcr.io/actions/actions-runner:latest

USER root

# Install Node.js 20 LTS from NodeSource
RUN apt-get update && apt-get install -y curl gnupg \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" > /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Verify Node.js
RUN node --version && npm --version

USER runner
