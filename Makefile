.PHONY: build build-linux run test clean deploy

# Binary name
BINARY=fer-server
BINARY_LINUX=fer-server-linux

# Build for current OS
build:
	go build -o bin/$(BINARY) cmd/server/main.go

# Build for Linux (for VPS deployment)
build-linux:
	GOOS=linux GOARCH=amd64 go build -o bin/$(BINARY_LINUX) cmd/server/main.go

# Run locally
run: build
	./bin/$(BINARY)

# Run tests
test:
	go test -v ./...

# Clean build artifacts
clean:
	rm -rf bin/
	rm -rf data/

# Deploy to VPS (requires VPS_HOST and VPS_USER env vars)
deploy: build-linux
	./scripts/deploy.sh

# Verify session data
verify:
	./scripts/verify_session.sh ./data

# Pull data from VPS
pull:
	./scripts/pull_data.sh

# Pre-session checklist
checklist:
	./scripts/session_checklist.sh

# Development: run with hot reload (requires air)
dev:
	air

# Lint
lint:
	golangci-lint run

# Format
fmt:
	go fmt ./...
