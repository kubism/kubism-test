SHELL := bash

# Directory, where all required tools are located (absolute path required)
TOOLS_DIR ?= $(shell cd tools && pwd)

# Prerequisite tools
GO ?= go
DOCKER ?= docker
KUBECTL ?= kubectl

# Tools managed by this project
GINKGO ?= $(TOOLS_DIR)/ginkgo
LINTER ?= $(TOOLS_DIR)/golangci-lint
KIND ?= $(TOOLS_DIR)/kind
GOVERALLS ?= $(TOOLS_DIR)/goveralls
GOVER ?= $(TOOLS_DIR)/gover
HELM3 ?= $(TOOLS_DIR)/helm3
CONTROLLER_GEN ?= $(TOOLS_DIR)/controller-gen
KUSTOMIZE ?= $(TOOLS_DIR)/kustomize
KUBEBUILDER ?= $(TOOLS_DIR)/kubebuilder
KUBEBUILDER_ASSETS ?= $(TOOLS_DIR)

# Variables
MANAGER_BIN ?= bin/manager
WORKER_BIN ?= bin/worker

DOCKER_TAG ?= latest
DOCKER_IMG ?= kubismio/backup-operator:$(DOCKER_TAG)

KIND_CLUSTER ?= test
KIND_IMAGE ?= kindest/node:v1.16.4

HELM_CHART_NAME ?= backup-operator
HELM_CHART_DIR ?= charts/$(HELM_CHART_NAME)
HELM_RELEASE_NAME ?= dev-backup-operator
HELM_NAMESPACE ?= default

# Empty by default, needs value to run e2e/integration tests (e.g. 'make TEST_LONG=y test')
TEST_LONG ?=

export

.PHONY: all test lint fmt vet install uninstall deploy manifests docker-build docker-push tools docker-is-running kind-create kind-delete kind-is-running check-test-long

all: $(MANAGER_BIN) $(WORKER_BIN) tools

$(MANAGER_BIN): generate fmt vet
	$(GO) build -o $(MANAGER_BIN) ./cmd/manager/main.go

$(WORKER_BIN): generate fmt vet
	$(GO) build -o $(WORKER_BIN) ./cmd/worker/...

test: generate fmt vet manifests docker-is-running kind-is-running check-test-long $(GINKGO) $(KUBEBUILDER) $(HELM3)
	$(GINKGO) -r -v -cover pkg

test-%: generate fmt vet manifests docker-is-running kind-is-running check-test-long $(GINKGO) $(KUBEBUILDER) $(HELM3)
	$(GINKGO) -r -v -cover pkg/$*

# If e2e/integration tests are running we need to build the image beforehand
check-test-long:
ifdef TEST_LONG
	$(MAKE) docker-build
endif

# First run gover to merge the coverprofiles and upload to coveralls
coverage: $(GOVERALLS) $(GOVER)
	$(GOVER)
	$(GOVERALLS) -coverprofile=gover.coverprofile -service=travis-ci -repotoken $(COVERALLS_TOKEN)

lint: $(LINTER) helm-lint
	$(GO) mod verify
	$(LINTER) run -v --no-config --deadline=5m

fmt:
	$(GO) fmt ./...

vet:
	$(GO) vet ./...

# Generate manifests e.g. CRD, RBAC etc.
manifests: $(CONTROLLER_GEN) $(KUSTOMIZE)
	$(CONTROLLER_GEN) crd:trivialVersions=false rbac:roleName=manager-role webhook paths="./..." output:crd:artifacts:config=config/crd/bases
	echo -e "# Generated by 'make manifests'\n" > $(HELM_CHART_DIR)/crds/crds.yaml
	$(KUSTOMIZE) build config/crd >> $(HELM_CHART_DIR)/crds/crds.yaml
	echo -e "# Generated by 'make manifests'\n" > $(HELM_CHART_DIR)/templates/rbac.yaml
	$(KUSTOMIZE) build config/rbac-templates >> $(HELM_CHART_DIR)/templates/rbac.yaml

# Generate code using controller-gen
generate: $(CONTROLLER_GEN)
	$(CONTROLLER_GEN) object:headerFile="hack/boilerplate.go.txt" paths="./..."

docker-build:
	$(DOCKER) build . -t $(DOCKER_IMG)

docker-push:
	$(DOCKER) push $(DOCKER_IMG)

docker-is-running:
	@echo "Checking if docker is running..."
	@{ \
	set -e; \
	$(DOCKER) version > /dev/null; \
	}

kind-create: $(KIND)
	$(KIND) create cluster --image $(KIND_IMAGE) --name $(KIND_CLUSTER) --wait 5m

kind-is-running: $(KIND)
	@echo "Checking if kind cluster with name '$(KIND_CLUSTER)' is running..."
	@echo "(e.g. create cluster via 'make kind-create')"
	@{ \
	set -e; \
	$(KIND) get kubeconfig --name $(KIND_CLUSTER) > /dev/null; \
	}

kind-get-kubeconfig: $(KIND)
	$(KIND) get kubeconfig --name $(KIND_CLUSTER) > /tmp/kind-$(KIND_CLUSTER)-config
	@echo "Created untracked config file in '/tmp/kind-$(KIND_CLUSTER)-config. Use as follows:"
	@echo "export KUBECONFIG=\"/tmp/kind-$(KIND_CLUSTER)-config\""

kind-delete: $(KIND)
	$(KIND) delete cluster --name $(KIND_CLUSTER)

helm-install: $(HELM3)
	$(HELM3) upgrade --install $(HELM_RELEASE_NAME) --namespace $(HELM_NAMESPACE) $(HELM_CHART_DIR)

helm-uninstall: $(HELM3)
	$(HELM3) uninstall --namespace $(HELM_NAMESPACE) $(HELM_RELEASE_NAME)

helm-lint: $(HELM3)
	$(HELM3) lint $(HELM_CHART_DIR)

helm-publish: $(HELM3)
	./ci/publish.sh

# Phony target to install all required tools into ${TOOLS_DIR}
tools: $(TOOLS_DIR)/kind $(TOOLS_DIR)/ginkgo $(TOOLS_DIR)/controller-gen $(TOOLS_DIR)/kustomize $(TOOLS_DIR)/golangci-lint $(TOOLS_DIR)/kubebuilder $(TOOLS_DIR)/helm3 $(TOOLS_DIR)/goveralls $(TOOLS_DIR)/gover

$(TOOLS_DIR)/kind:
	$(shell $(TOOLS_DIR)/goget-wrapper sigs.k8s.io/kind@v0.7.0)

$(TOOLS_DIR)/ginkgo:
	$(shell $(TOOLS_DIR)/goget-wrapper github.com/onsi/ginkgo/ginkgo@v1.12.0)

$(TOOLS_DIR)/controller-gen:
	$(shell $(TOOLS_DIR)/goget-wrapper sigs.k8s.io/controller-tools/cmd/controller-gen@v0.2.5)

$(TOOLS_DIR)/kustomize:
	$(shell $(TOOLS_DIR)/goget-wrapper sigs.k8s.io/kustomize/kustomize/v3@v3.5.3)

$(TOOLS_DIR)/golangci-lint:
	$(shell curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b $(TOOLS_DIR) v1.25.0)

$(TOOLS_DIR)/kubebuilder $(TOOLS_DIR)/kubectl $(TOOLS_DIR)/kube-apiserver $(TOOLS_DIR)/etcd:
	$(shell $(TOOLS_DIR)/kubebuilder-install)

$(TOOLS_DIR)/helm3:
	$(shell $(TOOLS_DIR)/helm3-install)

$(TOOLS_DIR)/goveralls:
	$(shell $(TOOLS_DIR)/goget-wrapper github.com/mattn/goveralls@v0.0.5)

$(TOOLS_DIR)/gover:
	$(shell $(TOOLS_DIR)/goget-wrapper github.com/modocache/gover)