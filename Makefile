# Kubernetes Image Auditor build automation.
# Builds, runs, tests, and removes the locally generated Go binary.
# The binary is created under bin/ and is excluded from Git.
SHELL := /usr/bin/env bash

IMAGE_AUDITOR_DIR := tools/image-auditor
IMAGE_AUDITOR_BIN := bin/image-auditor

.PHONY: help image-auditor-build image-auditor-run image-auditor-test image-auditor-clean

help:
	@echo "Available targets:"
	@echo "  make image-auditor-build   Build the image auditor binary"
	@echo "  make image-auditor-run     Build and run the image auditor"
	@echo "  make image-auditor-test    Run Go tests"
	@echo "  make image-auditor-clean   Remove the generated binary"

image-auditor-build:
	@echo "Building Kubernetes image auditor..."
	@mkdir -p bin
	@cd $(IMAGE_AUDITOR_DIR) && go build -o ../../$(IMAGE_AUDITOR_BIN) .
	@echo "Binary created at $(IMAGE_AUDITOR_BIN)"

image-auditor-run: image-auditor-build
	@if [[ -z "$(ALLOWED_IMAGE_PREFIXES)" ]]; then \
		echo "ERROR: ALLOWED_IMAGE_PREFIXES is required."; \
		echo 'Example: make image-auditor-run ALLOWED_IMAGE_PREFIXES="us-central1-docker.pkg.dev/project-id/repository/"'; \
		exit 2; \
	fi
	@./$(IMAGE_AUDITOR_BIN) \
		--allowed-prefixes "$(ALLOWED_IMAGE_PREFIXES)" \
		$(ARGS)

image-auditor-test:
	@cd $(IMAGE_AUDITOR_DIR) && go test ./...

image-auditor-clean:
	@rm -f $(IMAGE_AUDITOR_BIN)
	@echo "Removed $(IMAGE_AUDITOR_BIN)"
