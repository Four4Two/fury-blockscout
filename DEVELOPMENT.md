# Development

The goal of this document is to allow any developer to be able to quickly build, run, test, develop and debug a local version of the [Kava customized Blockscout Ethereum Explorer](https://explorer.kava.io).

## Setting up required toolchains

### Elixir & Phoenix

Follow [this guide](https://hexdocs.pm/phoenix/installation.html) for how to install and configure erlang, elixir and other dependencies needed by the Phoenix web framework.

### Node

[Node version file](./.node-version)

Current version used: `18.14.0`

Install required node version using a tool such as homebrew or asdf
- https://nodejs.org/en/download/package-manager

### Docker & Docker Compose

Install latest version of Docker and Docker compose
- [Docker](https://docs.docker.com/engine/install/) for building service docker images
- [Docker Compose (v2+)](https://docs.docker.com/compose/install/) for orchestrating containers for the service and it's dependencies (e.g. postgres database and redis cache)

## Configuration

Adjusting or setting of values to be used by `make`, `docker-compose` or any of the containerized applications is possible by modifying the [local environment file](./.env)

```bash
# used by the kava docker compose service
KAVA_CONTAINER_EVM_RPC_PORT=8545
KAVA_HOST_EVM_RPC_PORT=8545
KAVA_CONTAINER_COSMOS_RPC_PORT=26657
KAVA_HOST_COSMOS_RPC_PORT=26657

# Used by the postgres database docker file
PGTAP_VERSION=v1.2.0

# Used by the postgres database docker compose service
POSTGRES_HOST_PORT=5444
POSTGRES_CONTAINER_PORT=5432

# Used by the postgres database application
POSTGRES_ADMIN_USERNAME=postgres
POSTGRES_BLOCKSCOUT_USERNAME=blockscout_user
POSTGRES_BLOCKSCOUT_DATABASE_NAME=blockscout_testing
POSTGRES_PASSWORD=root_password123
DB_BLOCKSCOUT_PASSWORD=blockscout_password123
POSTGRES_MAX_NUM_CONNECTIONS=200

...etc...
```

## Building

Build a development version docker image of the service
```bash
make build
```

## Running

### Blockscout + Postgres + Kava

Executing the below command will build and start local versions of blockscout, postgres and kava, exposing a web UI that can be viewed by opening your browser to `http://localhost:4000`

```bash
make up
```

An example of command flow used during typical iterative development:

```bash
# start (or restart previously built) containers for all the services
# in docker-compose.yml
make up
# rebuild, reset state and restart all containers for all the services
# in docker-compose.yml
make reset
# rebuild and restart just the blockscout service
make refresh
# stop and start (without re-building or wiping state) just the proxy blockscout
make restart
# stop all services in docker-compose.yml
make down
```

other commands with comments for their purpose are available in the [Makefile](./Makefile)

### Hardhat server

```bash
npx hardhat node --hostname 0.0.0.0
```

# Testing

Running blockscout tests

```bash
mix deps.get
mix test
```

> NOTE: These currently fail, TBD on cause or resolution


## Debugging

### Blockscout

#### Print Debugging

Download the sources locally for the base version of blockscout used to build the kava customized development and production images

```bash
make vendor-blockscout
```

Add print debugging statements using `dbg` or make other desired modifications to the applications logic and state

```bash
cd blockscout/blockscout-base
```

```elixir
# CODE
  def get_db_config(opts) do
    # DEBUG
    # https://elixir-lang.org/getting-started/debugging.html
    dbg(opts)
    url_encoded = opts[:url] || System.get_env("DATABASE_URL")
    url = url_encoded && URI.decode(url_encoded)
    env_function = opts[:env_func] || (&System.get_env/1)

    @postgrex_env_vars
    |> get_env_vars(env_function)
    |> Keyword.merge(extract_parameters(url))
  end
```

Create a patch of your changes to be applied when the development or production docker image is built

```bash
git diff > ../patches/debug.patch
# repo base kava-blockscout-build/
cd ../../
# to run your debugged version of blockscout locally
make refresh
```


### Postgres

You can connect to the local postgres database started by `make up` to inspect tables and prototype queries

```bash
⋊> ~/f/k/kava-blockscout-build on ls/deploy-blockscout-v5-upgrade ⨯ make debug-d
atabase
docker compose exec postgres psql -U postgres -d blockscout_testing
psql (15.2 (Debian 15.2-1.pgdg110+1))
Type "help" for help.

blockscout_testing=# \d+
                                                                List of relation
s
 Schema |                       Name                       |   Type   |      Own
er      | Persistence | Access method |    Size    | Description
--------+--------------------------------------------------+----------+---------
--------+-------------+---------------+------------+-------------
 public | account_api_keys                                 | table    | blocksco
ut_user | permanent   | heap          | 0 bytes    |
 public | account_api_plans                                | table    | blocksco
ut_user | permanent   | heap          | 8192 bytes |
 public | account_api_plans_id_seq                         | sequence | blocksco
ut_user | permanent   |               | 8192 bytes |
 public | account_custom_abis                              | table    | blocksco
ut_user | permanent   | heap          | 8192 bytes |
blockscout_testing=#
```

## Publishing New Versions

### Hotfix flow

Deploy the image to ECS by updating the version tag to `hotfix` (or you can re-tag to a more specific version as desired) in the [infrastructure repo](https://github.com/Kava-Labs/infrastructure/blob/master/terraform/product/production/us-east-1/blockscout-testnet/service/terragrunt.hcl#L48) and running `AWS_PROFILE=root terragrunt apply`

View the output of your debugging in the ECS console for the task started by the above `terragrunt apply` command

![Blockscout print debug AWS ECS console output](./devdocs/images/blockscout_print_debug_example_output.png)

If you are deploying multiple hotfixes with the same tag as part of an iterative development process you can skip running `terragrunt apply` each time (after running `make hotfix-release`) by asking ECS to deploy a new version of the service - checking for and using a newer version of the image if present

```bash
AWS_PROFILE=production aws ecs update-service --cluster blockchain-service --service blockscout-kava-10-testnet --force-new-deployment
```