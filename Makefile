.PHONY: help test test-dind test-dind-rootless test-cli test-all clean

# Default Node.js version
NODE_VERSION ?= 20

help: ## Show this help message
	@echo "Forgejo Runner Docker Image - Testing Makefile"
	@echo ""
	@echo "Usage: make [target] [NODE_VERSION=XX]"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'
	@echo ""
	@echo "Examples:"
	@echo "  make test              # Run comprehensive tests with Node.js 20"
	@echo "  make test-dind         # Test only DinD variant"
	@echo "  make test NODE_VERSION=18  # Test with Node.js 18"

test: ## Run comprehensive test suite
	./test.sh

test-dind: ## Test DinD variant
	./test-variant.sh $(NODE_VERSION) dind

test-dind-rootless: ## Test DinD rootless variant
	./test-variant.sh $(NODE_VERSION) dind-rootless

test-cli: ## Test CLI/DooD variant
	./test-variant.sh $(NODE_VERSION) cli

test-all: ## Test all variants for all Node.js versions
	@echo "Testing all combinations..."
	@for node in 18 20 22; do \
		for variant in dind dind-rootless cli; do \
			echo ""; \
			echo "=== Testing Node.js $$node with $$variant ==="; \
			./test-variant.sh $$node $$variant || exit 1; \
		done; \
	done
	@echo ""
	@echo "All tests passed!"

build: ## Build image (specify NODE_VERSION and VARIANT)
	@if [ -z "$(VARIANT)" ]; then \
		echo "Error: VARIANT not specified. Use: make build VARIANT=dind NODE_VERSION=20"; \
		exit 1; \
	fi
	docker build \
		--build-arg NODE_VERSION=$(NODE_VERSION) \
		--build-arg DOCKER_VARIANT=$(VARIANT) \
		-t forgejo-runner:node$(NODE_VERSION)-$(VARIANT) \
		.

clean: ## Clean up test containers and images
	@echo "Cleaning up test containers..."
	@docker rm -f test-runner-dind test-runner-dind-rootless test-runner-cli test-runner-cli-quick 2>/dev/null || true
	@echo "Cleaning up test images..."
	@docker rmi -f $$(docker images -q 'forgejo-runner-test:*' 2>/dev/null) 2>/dev/null || true
	@docker rmi -f $$(docker images -q 'test:*' 2>/dev/null) 2>/dev/null || true
	@echo "Cleanup complete!"

clean-all: clean ## Clean up everything including build logs
	@echo "Removing build logs..."
	@rm -f /tmp/build-*.log
	@echo "All clean!"
