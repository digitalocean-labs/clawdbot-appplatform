.PHONY: rebuild logs shell

rebuild:
	docker compose down
	docker compose up -d --build
	docker compose ps

logs:
	docker compose logs -f

shell:
	docker compose exec moltbot-gateway bash
