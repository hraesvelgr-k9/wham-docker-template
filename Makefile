ifneq (,$(wildcard .env))
include .env
export
endif

COMPOSE=docker compose --env-file .env
BASE_FILES=-f compose.yml
DEV_FILES=$(BASE_FILES) -f compose.dev.yml
PROD_FILES=$(BASE_FILES) -f compose.prod.yml

.PHONY: help init env-init dev-build dev-up dev-down dev-shell dev-logs dev-config \
        prod-build prod-up prod-down prod-shell prod-logs prod-config \
        dev-rebuild prod-rebuild dev-restart clean ps

help:
	@echo "Usage:"
	@echo "  make env-init     - Create .env from .env.example if it does not exist"
	@echo "  make init         - Clone the WHAM repository if it does not exist"
	@echo "  make dev-build    - Build the development image"
	@echo "  make dev-up       - Start the development container"
	@echo "  make dev-down     - Stop the development container"
	@echo "  make dev-shell    - Open a shell in the development container"
	@echo "  make dev-logs     - Show development container logs"
	@echo "  make dev-config   - Render the merged development Compose config"
	@echo "  make dev-rebuild  - Rebuild and restart the development container"
	@echo "  make prod-build   - Build the production-like image"
	@echo "  make prod-up      - Start the production-like container"
	@echo "  make prod-down    - Stop the production-like container"
	@echo "  make prod-shell   - Open a shell in the production-like container"
	@echo "  make prod-logs    - Show production-like container logs"
	@echo "  make prod-config  - Render the merged production-like Compose config"
	@echo "  make prod-rebuild - Rebuild and restart the production-like container"
	@echo "  make ps           - Show Compose container status"
	@echo "  make clean        - Remove containers and volumes"

env-init:
	@test -f .env || cp .env.example .env

init:
	@test -d workspace/WHAM || (mkdir -p workspace && git clone --recursive https://github.com/yohanshin/WHAM.git workspace/WHAM)

dev-build:
	$(COMPOSE) $(DEV_FILES) build

dev-up:
	$(COMPOSE) $(DEV_FILES) up -d

dev-down:
	$(COMPOSE) $(DEV_FILES) down

dev-shell:
	$(COMPOSE) $(DEV_FILES) exec $(SERVICE_NAME) bash

dev-logs:
	$(COMPOSE) $(DEV_FILES) logs -f

dev-config:
	$(COMPOSE) $(DEV_FILES) config

dev-rebuild:
	$(COMPOSE) $(DEV_FILES) up -d --build

dev-restart:
	$(COMPOSE) $(DEV_FILES) exec $(SERVICE_NAME) rm -f /var/lib/wham/.deps_installed
	$(COMPOSE) $(DEV_FILES) restart $(SERVICE_NAME)

prod-build:
	$(COMPOSE) $(PROD_FILES) build

prod-up:
	$(COMPOSE) $(PROD_FILES) up -d

prod-down:
	$(COMPOSE) $(PROD_FILES) down

prod-shell:
	$(COMPOSE) $(PROD_FILES) exec $(SERVICE_NAME) bash

prod-logs:
	$(COMPOSE) $(PROD_FILES) logs -f

prod-config:
	$(COMPOSE) $(PROD_FILES) config

prod-rebuild:
	$(COMPOSE) $(PROD_FILES) up -d --build

ps:
	$(COMPOSE) $(DEV_FILES) ps

clean:
	$(COMPOSE) $(DEV_FILES) down -v --remove-orphans || true
	$(COMPOSE) $(PROD_FILES) down -v --remove-orphans || true
