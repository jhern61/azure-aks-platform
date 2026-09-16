SHELL := /bin/bash
TF_DIR := terraform
K8S_DIR := kubernetes

.DEFAULT_GOAL := help

.PHONY: help bootstrap init fmt validate lint plan apply deploy kubeconfig destroy

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

bootstrap: ## One-time: create remote Terraform state backend in Azure
	./scripts/bootstrap-state.sh

init: ## terraform init with backend config
	cd $(TF_DIR) && terraform init -backend-config=backend.hcl

fmt: ## Format Terraform
	cd $(TF_DIR) && terraform fmt -recursive

validate: ## Validate Terraform
	cd $(TF_DIR) && terraform validate

lint: ## Run tflint + checkov locally
	cd $(TF_DIR) && tflint --recursive
	checkov -d $(TF_DIR) --quiet

plan: ## terraform plan
	cd $(TF_DIR) && terraform plan -out=tfplan

apply: ## terraform apply the last plan
	cd $(TF_DIR) && terraform apply tfplan

kubeconfig: ## Fetch AKS credentials into your kubeconfig
	cd $(TF_DIR) && $$(terraform output -raw kubeconfig_command)

deploy: ## Apply workload, observability, and SLO manifests
	kubectl apply -f $(K8S_DIR)/workload/app.yaml
	kubectl apply -f $(K8S_DIR)/slo/slo-rules.yaml

destroy: ## Tear down all infrastructure
	cd $(TF_DIR) && terraform destroy
