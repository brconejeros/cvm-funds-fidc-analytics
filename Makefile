# dbt runs with dbt/ as both project dir and profiles dir.
DBT_DIR      := dbt
TARGET       ?= duckdb
DBT          := uv run --frozen dbt
DBT_FLAGS    := --project-dir $(DBT_DIR) --profiles-dir $(DBT_DIR) --target $(TARGET)

.DEFAULT_GOAL := build
.PHONY: setup profiles deps build parse docs docs-serve requirements clean

setup: profiles ## Install Python deps and create local profile
	uv sync --frozen
	mkdir -p data/duckdb

profiles: ## Copy profiles.yml.example -> dbt/profiles.yml if missing
	@test -f $(DBT_DIR)/profiles.yml || (cp $(DBT_DIR)/profiles.yml.example $(DBT_DIR)/profiles.yml && echo "Created $(DBT_DIR)/profiles.yml")

deps: profiles ## Install dbt packages
	$(DBT) deps --project-dir $(DBT_DIR) --profiles-dir $(DBT_DIR)

build: deps ## dbt build (models + tests) on $(TARGET)
	mkdir -p data/duckdb
	$(DBT) build $(DBT_FLAGS)

parse: deps
	$(DBT) parse $(DBT_FLAGS)

docs: deps
	mkdir -p data/duckdb
	$(DBT) docs generate $(DBT_FLAGS)

docs-serve: docs
	$(DBT) docs serve $(DBT_FLAGS)

requirements: ## Regenerate requirements.txt from uv.lock
	uv export --frozen --no-hashes --no-dev --no-emit-project -o requirements.txt

clean:
	rm -rf $(DBT_DIR)/target $(DBT_DIR)/dbt_packages $(DBT_DIR)/logs logs
	find data/duckdb -name '*.duckdb*' -delete
