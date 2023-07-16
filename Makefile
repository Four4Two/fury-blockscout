# execute these tasks when `make` with no target is invoked
default: up

# import environment file for setting or overriding
# configuration used by this Makefile
include .env

# source all variables in environment file
# This only runs in the make command shell
# so won't affect your login shell
export $(shell sed 's/=.*//' .env)

.PHONY: vendor-blockscout
# download blockscout sources locally for building
# custom versions of blockscout
vendor-blockscout:
	git submodule update --init --recursive

.PHONY: build
# build a development version docker image of the service
build:
	cd blockscout && \
	docker build ./ -f Dockerfile -t ${IMAGE_NAME}:${LOCAL_IMAGE_TAG}

.PHONY: build-db-exporter
# build the exporter image
build-db-exporter:
	cd db_exporter && \
	docker buildx bake -f docker-bake.hcl

.PHONY: build-db-importer
# build the importer image
build-db-importer:
	cd db_importer && \
	docker buildx bake -f docker-bake.hcl

.PHONY: publish
# build a production version docker image of the service
publish:
	cd blockscout && \
	docker build ./ -f Dockerfile -t ${IMAGE_NAME}:${PRODUCTION_IMAGE_TAG}

.PHONY: hotfix-release
# build a production image using local sources and push it to the remote repository using tag `hotfix
hotfix-release: publish
	docker tag ${IMAGE_NAME}:${PRODUCTION_IMAGE_TAG} fanfury/${IMAGE_NAME}:hotfix && \
	docker push fanfury/${IMAGE_NAME}:hotfix

.PHONY: release
# build and push an image using local sources and tagged according to values
# specified in /.env
release: publish
	docker tag ${IMAGE_NAME}:${PRODUCTION_IMAGE_TAG} fanfury/${IMAGE_NAME}:${PRODUCTION_IMAGE_TAG} && \
	docker push ${IMAGE_NAME}:${PRODUCTION_IMAGE_TAG}

.PHONY: up
# start dockerized versions of the service and it's dependencies
up:
	docker compose up -d

.PHONY: down
# stop the service and it's dependencies
down:
	docker compose down

.PHONY: restart
# restart just the service (useful for picking up new environment variable values)
restart:
	docker compose up -d blockscout --force-recreate

.PHONY: restart-postgres
# restart just the database without wiping it's data
restart-postgres:
	docker compose up -d postgres --force-recreate

.PHONY: reset
# wipe state and restart the service and all it's dependencies
reset:
	docker compose up -d --build --remove-orphans --renew-anon-volumes --force-recreate

# wipe just the database state and restart just the database
.PHONY: reset-postgres
reset-postgres:
	docker compose up -d postgres --force-recreate --renew-anon-volumes

.PHONY: refresh

# rebuild from latest local sources and restart just the service containers
# (preserving any volume state such as database tables & rows)
refresh:
	docker compose up -d blockscout --build --force-recreate

.PHONY: logs
# follow the logs from all the dockerized services
# make logs
# or one
# make logs S=blockscout
logs:
	docker compose logs ${S} -f

.PHONY: debug-database
# open a connection to the postgres database for debugging it's state
# https://www.postgresql.org/docs/current/app-psql.html
debug-database:
	docker compose exec postgres psql -U ${POSTGRES_ADMIN_USERNAME} -d ${POSTGRES_BLOCKSCOUT_DATABASE_NAME}
