.PHONY: help up down pull logs ps build lint xyops-sync

SERVICE ?=

help:
	@echo "Usage: make <target> SERVICE=<service-name>"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	    awk 'BEGIN {FS = ":.*?## "}; {printf "  %-10s %s\n", $$1, $$2}'

up: ## Start a stack (e.g. make up SERVICE=kuma)
	docker compose -f docker/$(SERVICE)/compose.yaml up -d

down: ## Stop a stack (e.g. make down SERVICE=kuma)
	docker compose -f docker/$(SERVICE)/compose.yaml down

pull: ## Pull latest images for a stack
	docker compose -f docker/$(SERVICE)/compose.yaml pull

logs: ## Tail logs for a stack
	docker compose -f docker/$(SERVICE)/compose.yaml logs -f

build: ## Build and start a custom app stack
	docker compose -f docker/$(SERVICE)/compose.yaml up --build -d

ps: ## Show all running containers
	docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

xyops-sync: ## Upsert all xyOps plugins via API (reads docker/xyops/.secrets)
	@echo "Syncing xyOps plugins..."
	@bash docker/xyops/scripts/sync-plugins.sh

lint: ## Validate all compose stack configs
	@failed=0; \
	for f in docker/*/compose.yaml; do \
		printf "  %-45s" "$$f"; \
		if docker compose -f $$f config > /dev/null 2>&1; then \
			echo "OK"; \
		else \
			echo "FAIL"; failed=1; \
		fi; \
	done; \
	exit $$failed
