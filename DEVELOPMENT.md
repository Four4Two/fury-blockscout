# Development

The goal of this document is to allow any developer to be able to quickly build, run, test, develop and debug a local version of the [Fury customized Blockscout Ethereum Explorer](https://explorer.fury.io).

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
# used by the fury docker compose service
FURY_CONTAINER_EVM_RPC_PORT=8545
FURY_HOST_EVM_RPC_PORT=8545
FURY_CONTAINER_COSMOS_RPC_PORT=26657
FURY_HOST_COSMOS_RPC_PORT=26657

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

### Blockscout + Postgres + Fury

Executing the below command will build and start local versions of blockscout, postgres and fury, exposing a web UI that can be viewed by opening your browser to `http://localhost:4000`

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

## Testing

Running blockscout tests

```bash
mix deps.get
mix test
```

> NOTE: These currently fail, TBD on cause or resolution

## Debugging

### Blockscout

#### Print Debugging

Download the sources locally for the base version of blockscout used to build the fury customized development and production images

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
# repo base fanfury/fury-blockscout-build/
cd ../../
# to run your debugged version of blockscout locally
make refresh
```

#### Indexer status

To see how far back the block explorer has indexed blocks, connect to the database and query to see what is the earliest block it has indexed, if these values change that means earlier and earlier blocks are being indexed (`refetch_needed` indicates whether the indexing was successful)

```sql
make debug-database
blockscout_testing=# select number, inserted_at, updated_at, refetch_needed from blocks order by number asc limit 5;
 number  |        inserted_at         |         updated_at         | refetch_needed
---------+----------------------------+----------------------------+----------------
 5762464 | 2023-06-16 00:27:58.151073 | 2023-06-16 00:27:58.151073 | f
 5762465 | 2023-06-16 00:27:58.032291 | 2023-06-16 00:27:58.032291 | f
 5762466 | 2023-06-16 00:27:57.890547 | 2023-06-16 00:27:57.890547 | f
 5762467 | 2023-06-16 00:27:57.774853 | 2023-06-16 00:27:57.774853 | f
 5762468 | 2023-06-16 00:27:57.658246 | 2023-06-16 00:27:57.658246 | f
(5 rows)

blockscout_testing=# select number, inserted_at, updated_at, refetch_needed from blocks order by number asc limit 5;
 number  |        inserted_at         |         updated_at         | refetch_needed
---------+----------------------------+----------------------------+----------------
 5762461 | 2023-06-16 00:27:58.521786 | 2023-06-16 00:27:58.521786 | f
 5762462 | 2023-06-16 00:27:58.409383 | 2023-06-16 00:27:58.409383 | f
 5762463 | 2023-06-16 00:27:58.272033 | 2023-06-16 00:27:58.272033 | f
 5762464 | 2023-06-16 00:27:58.151073 | 2023-06-16 00:27:58.151073 | f
 5762465 | 2023-06-16 00:27:58.032291 | 2023-06-16 00:27:58.032291 | f
(5 rows)

blockscout_testing=# select number, inserted_at, updated_at, refetch_needed from blocks order by number asc limit 5;
 number  |        inserted_at         |         updated_at         | refetch_needed
---------+----------------------------+----------------------------+----------------
 5762458 | 2023-06-16 00:27:59.161544 | 2023-06-16 00:27:59.161544 | f
 5762459 | 2023-06-16 00:27:59.023982 | 2023-06-16 00:27:59.023982 | f
 5762460 | 2023-06-16 00:27:58.752723 | 2023-06-16 00:27:58.752723 | f
 5762461 | 2023-06-16 00:27:58.521786 | 2023-06-16 00:27:58.521786 | f
 5762462 | 2023-06-16 00:27:58.409383 | 2023-06-16 00:27:58.409383 | f
(5 rows)
```

Another thing to look at is the select count(*) from pending_block_operations;, which is the leading cause of blockscout slowing down our nodes on mainnet is my hypothesis.

```sql
select count(*) from pending_block_operations;
> 1612632

select * from pending_block_operations limit 1;
> block_hash | inserted_at | updated_at | fetch_internal_transactions
> 0x95c132c930f104232464ab278cfde649e74963c743c634277497e824c38a43fc | 2023-01-21 23:49:21.372883 | 2023-01-21 23:49:21.372883 | true
```

#### Running local explorer against production network(s)

Update values in the [local environment file](.env) to point to the archive / pruning endpoint of the network you want your local instance of Blockscout to index

```bash
ETHEREUM_JSONRPC_HTTP_URL=http://evm.fury.black
# uncomment below to have blockscout index public testnet
# ETHEREUM_JSONRPC_HTTP_URL=https://evm.fury.black
# ETHEREUM_JSONRPC_WS_URL=wss://wevm..fury.black
# uncomment below to have blockscout index mainnet
ETHEREUM_JSONRPC_HTTP_URL=https://evm.data.fury.black
ETHEREUM_JSONRPC_WS_URL=wss://wevm.data.fury.black
```

```bash
# wipe all state and restart containers with updated environment variables
make reset
```

Open the [Blockscout UI](http://localhost:4000) to inspect progress

### Postgres

You can connect to the local postgres database started by `make up` to inspect tables and prototype queries

```bash
⋊> ~/f/k/fanfury/fury-blockscout-build on ls/deploy-blockscout-v5-upgrade ⨯ make debug-d
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

> Note: you must use an x86/intel cpu architecture computer to build any image that is meant to be run in a production environment, if you don't have access to one locally create an EC2 instance to use until Github actions are set up to handle Continuous Integration for building new production / hotfix images

### Hotfix flow

Deploy the image to ECS by updating the version tag to `hotfix` (or you can re-tag to a more specific version as desired) in the [infrastructure repo](https://github.com/Kava-Labs/infrastructure/blob/master/terraform/product/production/us-east-1/blockscout-testnet/service/terragrunt.hcl#L48) and running `AWS_PROFILE=root terragrunt apply`

View the output of your debugging in the ECS console for the task started by the above `terragrunt apply` command

![Blockscout print debug AWS ECS console output](./devdocs/images/blockscout_print_debug_example_output.png)

If you are deploying multiple hotfixes with the same tag as part of an iterative development process you can skip running `terragrunt apply` each time (after running `make hotfix-release`) by asking ECS to deploy a new version of the service - checking for and using a newer version of the image if present

```bash
AWS_PROFILE=production aws ecs update-service --cluster blockchain-service --service blockscout-fury-10-testnet --force-new-deployment
```

### Normal release flow

To build a new image with the tag equal to the value of `PRODUCTION_IMAGE_TAG` in the [env file](./.env)

```bash
make release
```

Deploy the image to ECS by updating the version tag to match the value of `PRODUCTION_IMAGE_TAG` in the [infrastructure repo](https://github.com/Kava-Labs/infrastructure/blob/master/terraform/product/production/us-east-1/blockscout-testnet/service/terragrunt.hcl#L48) and running `AWS_PROFILE=root terragrunt apply`
