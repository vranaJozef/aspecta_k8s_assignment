setup: ## Initialize the environment (Cluster, Registry, Tools)
	@echo "Starting setup..."
	@./scripts/setup.sh

verify_alert: ## Run alert verification procedure
	@echo "Running verification..."
	@./scripts/verify_alert.sh

clean: ## Destroy the local environment
	@echo "Cleaning up..."
	@./scripts/cleanup.sh



