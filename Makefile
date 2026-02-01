.PHONY: rebuild logs shell test test-all

rebuild:
	docker compose down
	docker compose up -d --build
	docker compose ps

logs:
	docker compose logs -f

shell:
	docker compose exec openclaw-gateway bash

test:
	@if [ -z "$(CONFIG)" ]; then echo "Usage: make test CONFIG=<name>"; exit 1; fi
	@bash -c 'source tests/lib.sh && switch_config $(CONFIG)'
	@docker compose down -t 1 >/dev/null 2>&1 || true
	@docker compose up -d --build
	@CONTAINER=$$(docker compose ps -q openclaw-gateway | head -1); \
	CONTAINER_NAME=$$(docker inspect --format '{{.Name}}' $$CONTAINER | sed 's/^.//'); \
	echo "Running tests for config: $(CONFIG) (container: $$CONTAINER_NAME)"; \
	found=false; \
	for script in $$(ls tests/$(CONFIG)/*.sh 2>/dev/null | sort); do \
		if [ -x "$$script" ]; then \
			found=true; \
			echo "Running $$script"; \
			"$$script" $$CONTAINER_NAME || exit 1; \
		fi; \
	done; \
	if [ "$$found" = "false" ]; then \
		echo "No test scripts found for $(CONFIG)"; \
	fi

test-all:
	@for env in example_configs/*.env; do \
		CONFIG=$$(basename $$env .env); \
		echo ""; \
		echo "=== Testing $$CONFIG ==="; \
		bash -c "source tests/lib.sh && switch_config $$CONFIG"; \
		docker compose down -t 1 >/dev/null 2>&1; \
		docker compose up -d --build >/dev/null 2>&1; \
		CONTAINER=$$(docker compose ps -q openclaw-gateway | head -1); \
		CONTAINER_NAME=$$(docker inspect --format '{{.Name}}' $$CONTAINER | sed 's/^.//'); \
		found=false; \
		for script in $$(ls tests/$$CONFIG/*.sh 2>/dev/null | sort); do \
			if [ -x "$$script" ]; then \
				found=true; \
				echo "Running $$script"; \
				"$$script" $$CONTAINER_NAME || exit 1; \
			fi; \
		done; \
		if [ "$$found" = "false" ]; then \
			echo "No test scripts for $$CONFIG, skipping"; \
		fi; \
	done; \
	echo ""; \
	echo "All tests passed!"
