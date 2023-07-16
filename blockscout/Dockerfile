# Raw version representing v5.1.5-beta
ARG BLOCKSCOUT_VERSION=5.1.5

#
# The backend-builder uses the official exlixir docker image that contains
# Elixir, Erlang, compatiable OTP version, and mix.
#
FROM elixir:1.14-otp-25 as backend-builder
ARG BLOCKSCOUT_VERSION

WORKDIR /src

# All elixir dependencies are already installed
# We only need git to clone and apply patches
RUN apt-get update \
  && apt-get install -y git \
  && rm -rf /var/lib/apt/lists/*

# COPY patches first, since we want to apply after clone, but before compiling
# This does force a re-clone if there are patch changes, but also reduces our layers.
#
COPY ./patches /src/patches

# The order of the below steps must be kept the same
#
# Clone the  blockscout repository
RUN git clone --depth 1 --branch v${BLOCKSCOUT_VERSION}-beta https://github.com/blockscout/blockscout.git
WORKDIR blockscout
# apply patches
RUN git apply /src/patches/*.patch
RUN mix local.hex --force
RUN mix local.rebar --force
# install prod dependencies
RUN mix deps.get --only prod
# compile minimal production optimized version of application
RUN MIX_ENV=prod mix compile
# The order of the above steps must be kept the same
#

#
# The frontend-builder copies builds the block_scout_web frontend and installs solc for the explorer using npm.
#
FROM node:18 as frontend-builder

WORKDIR /src

# The frontend relys on dependencies installed by mix (similar to ruby on rails where css/js/other assets are included via gems)
COPY --from=backend-builder /src/blockscout/ /src/blockscout/
COPY ./assets/fury-logo.png /src/blockscout/apps/block_scout_web/assets/static/images/fury-logo.png

# Build the user interface (block_scout_web/assets) and then install the solc npm package (explorer)
RUN cd blockscout/apps/block_scout_web/assets \
  && npm install \
  && NODE_ENV=prod npm run deploy \
  && cd ../../explorer \
  && npm install

#
# The release-builder copies the static assets built by the frontend-builder for the block_scout_web frontend,
# then runs phx.digest which digests, compresses, and outputs hashed assets with a manifest. Finally, mix release
# is called which assembles a self-contained application that can run without a Erlang VM.
#
FROM backend-builder as release-builder

WORKDIR /src

# Priv is where resources required by the application are kept
COPY --from=frontend-builder /src/blockscout/apps/block_scout_web/priv/static/ /src/blockscout/apps/block_scout_web/priv/static

# Generate cacheable assets and build final release
RUN cd blockscout \
  && MIX_ENV=prod mix phx.digest \
  && MIX_ENV=prod mix release

#
# The runner uses debian 11 (bullseye), which matches the OS used in previous steps.
#
# For elixir applications, we must ensure the locale is UTF-8.
#
# In addition, we also ensure ca-certificates are up to date.
#
FROM debian:11 as runner
ARG BLOCKSCOUT_VERSION

# Install locale, update ca certs, install node for contract verification
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
  && apt-get update \
  && apt-get install -y locales ca-certificates nodejs \
  && rm -rf /var/lib/apt/lists/* \
  && echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen \
  && locale-gen \
  && update-ca-certificates

# Ensure utf8 locale is used
ENV LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8

WORKDIR /app

# Copy the release to the /app workdir (contains the bin/blockscout cmd which represents the built umbrella app w/ frontent, indexer, etc)
COPY --from=release-builder /src/blockscout/_build/prod/rel/blockscout/ /app/
# This copies the installed solc via npm
COPY --from=frontend-builder /src/blockscout/apps/explorer/node_modules /app/node_modules
# Required for blockscout, not standard for pheonix/umbrella apps but is required for some runtime config
# NOTE: Refer to https://github.com/blockscout/blockscout/blob/master/docker/Dockerfile when changing version as this may be refactored away
COPY --from=backend-builder /src/blockscout/config/config_helper.exs /app/config/config_helper.exs
COPY --from=backend-builder /src/blockscout/config/config_helper.exs /app/releases/${BLOCKSCOUT_VERSION}/config_helper.exs

# Run database creation and migrations first, then start built production app
CMD ["sh", "-c", "/app/bin/blockscout eval 'Elixir.Explorer.ReleaseTasks.create_and_migrate()' && /app/bin/blockscout start"]
