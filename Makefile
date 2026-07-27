SHELL := /bin/bash

.DEFAULT_GOAL := help

RED    := \033[1;31m
YELLOW := \033[1;33m
GREEN  := \033[1;32m
CYAN   := \033[1;36m
RESET  := \033[0m

.PHONY: help
help: ## Show all available targets with short descriptions.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make <target>\n\nTargets:\n"} /^[a-zA-Z0-9_.-]+:.*##/ { printf "  %-72s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

# -----------------------------------------------------------------------------------
# Cluster setup
# -----------------------------------------------------------------------------------
.PHONY: setup-minikube
setup-minikube: ## Ensure Minikube cluster is running with correct profile.
	@echo -e "$(CYAN) Ensure Minikube cluster is running with correct profile $(RESET)"; \
	$(MAKE) -f Makefile_Setup ensure-minikube; \
	$(MAKE) -f Makefile_Setup enable-minikube-addons; \
	$(MAKE) -f Makefile_Setup check-clusterinfo; \
	$(MAKE) -f Makefile_Setup kubectl-get-nodes

# -----------------------------------------------------------------------------------
# Guided NetworkPolicy default-deny + least-privilege flow (step-by-step)
# -----------------------------------------------------------------------------------
.PHONY: step-0-check-CNI-support-networkpolicy
step-0-check-CNI-support-networkpolicy: ## Check if CNI supports NetworkPolicy (Calico/Cilium/Antrea/etc.).
	@printf '$(CYAN)%s$(RESET)\n' "Step 0. Check if CNI supports NetworkPolicy (Calico/Cilium/Antrea/etc.)."; \
	printf '$(CYAN)%s$(RESET)\n' "Press ENTER to run to check if CNI supports NetworkPolicy..."; \
	read -r _; \
	$(MAKE) -f Makefile_NetworkPolicy check-netpol-support

.PHONY: step-0-cleanup
step-0-cleanup: ## Step 0: Cleanup previous run (namespaces, pods, policies).
	@printf '$(CYAN)%s$(RESET)\n' "Step 0. Cleanup previous run (team-alpha, team-beta namespaces and resources)."; \
	printf '$(CYAN)%s$(RESET)\n' "Press ENTER to run cleanup..."; \
	read -r _; \
	$(MAKE) -f Makefile_NetworkPolicy cleanup

.PHONY: step-1-apply-namespaces
step-1-apply-namespaces: ## Step 1: Apply namespaces team-alpha and team-beta (no policies yet).
	@printf '$(CYAN)%s$(RESET)\n' "Step 1. Create (Apply) namespaces team-alpha and team-beta."; \
	printf '$(CYAN)%s$(RESET)\n' "Press ENTER to apply namespaces..."; \
	read -r _; \
	$(MAKE) -f Makefile_NetworkPolicy apply-namespaces; \
	printf '$(GREEN)%s$(RESET)\n' "Namespaces applied. You can run: kubectl get ns team-alpha team-beta"

.PHONY: step-2-apply-pods-and-test
step-2-apply-pods-and-test: ## Step 2: Apply server/client pods in both namespaces and test baseline connectivity (no NetworkPolicy).
	@printf '$(CYAN)%s$(RESET)\n' "Step 2. Create (Apply) server/service/client pods in team-alpha and team-beta namespaces."; \
	printf '$(CYAN)%s$(RESET)\n' "Press ENTER to apply pods..."; \
	read -r _; \
	$(MAKE) -f Makefile_NetworkPolicy apply-pods; \
	printf '$(GREEN)%s$(RESET)\n' "Pods applied and Ready."; \
	printf '$(CYAN)%s$(RESET)\n' "Now test baseline connectivity (no NetworkPolicy, expect ALLOWED everywhere)."; \
	printf '$(CYAN)%s$(RESET)\n' "Press ENTER to run baseline connectivity tests..."; \
	read -r _; \
	$(MAKE) -f Makefile_NetworkPolicy test-baseline-connectivity

.PHONY: step-3-apply-default-deny-and-test
step-3-apply-default-deny-and-test: ## Step 3: Apply default-deny ingress+egress for both namespaces and test that everything is blocked.
	@printf '$(CYAN)%s$(RESET)\n' "Step 3. Apply default-deny-all NetworkPolicy for team-alpha and team-beta."; \
	printf '$(CYAN)%s$(RESET)\n' "Press ENTER to apply default-deny policies..."; \
	read -r _; \
	$(MAKE) -f Makefile_NetworkPolicy apply-default-deny; \
	$(MAKE) -f Makefile_NetworkPolicy apply-least-privilege; 	
	printf '$(GREEN)%s$(RESET)\n' "Default-deny policies applied."; \
	printf '$(CYAN)%s$(RESET)\n' "Now test connectivity under default-deny (expect BLOCKED for all tests)."; \
	printf '$(CYAN)%s$(RESET)\n' "Press ENTER to run default-deny connectivity tests..."; \
	read -r _; \
	$(MAKE) -f Makefile_NetworkPolicy test-default-deny-connectivity

.PHONY: step-4-apply-alpha-allow-and-test
step-4-apply-alpha-allow-and-test: ## Step 4: Apply least-privilege allow policy for team-alpha client->server and test that only that flow is allowed.
	@printf '$(CYAN)%s$(RESET)\n' "Step 4. Apply least-privilege allow policy for team-alpha (alpha-client -> alpha-server TCP 5678)."; \
	printf '$(CYAN)%s$(RESET)\n' "Press ENTER to apply allow policy..."; \
	read -r _; \
	$(MAKE) -f Makefile_NetworkPolicy apply-allow-client-to-server; \
	printf '$(GREEN)%s$(RESET)\n' "Allow policy for team-alpha applied."; \
	printf '$(CYAN)%s$(RESET)\n' "Now test connectivity: alpha client should be ALLOWED, beta and cross-namespace should remain BLOCKED."; \
	printf '$(CYAN)%s$(RESET)\n' "Press ENTER to run least-privilege connectivity tests..."; \
	read -r _; \
	$(MAKE) -f Makefile_NetworkPolicy test-least-privilege-connectivity

.PHONY: step-5-apply-dns-egress-and-test
step-5-apply-dns-egress-and-test: ## Step 5: (Optional) Apply DNS egress policy for team-alpha and test DNS behavior.
	@printf '$(CYAN)%s$(RESET)\n' "Step 5. (Optional) Apply DNS egress NetworkPolicy for team-alpha."; \
	printf '$(CYAN)%s$(RESET)\n' "Press ENTER to apply DNS egress policy (labels may need adjustment per cluster)..."; \
	read -r _; \
	$(MAKE) -f Makefile_NetworkPolicy apply-allow-dns-egress || true; \
	printf '$(GREEN)%s$(RESET)\n' "DNS egress policy applied (if labels matched)."; \
	printf '$(CYAN)%s$(RESET)\n' "Now test DNS behavior from team-alpha pods (e.g., curl https://example.com)."; \
	printf '$(CYAN)%s$(RESET)\n' "Press ENTER to run DNS connectivity tests..."; \
	read -r _; \
	$(MAKE) -f Makefile_NetworkPolicy test-dns-connectivity || true


# You have a combined path:
# 	baseline → combined default-deny-all → least-privilege.
.PHONY: run-networkpolicy-default-deny-playbook
run-networkpolicy-default-deny-playbook: setup-minikube ## Run full guided playbook (calls step-0..step-5 in order, each with user input).
	@printf '$(CYAN)%s$(RESET)\n' "Running guided NetworkPolicy default-deny + least-privilege playbook..."; \
	$(MAKE) step-0-check-CNI-support-networkpolicy; \
	$(MAKE) step-0-cleanup; \
	$(MAKE) step-1-apply-namespaces; \
	$(MAKE) step-2-apply-pods-and-test; \
	$(MAKE) step-3-apply-default-deny-and-test; \
	$(MAKE) step-4-apply-alpha-allow-and-test; \
	$(MAKE) step-5-apply-dns-egress-and-test

# ---------------------------------------------------------------------------------------------------
# What you’ll see when you run the new playbook
# 	After Ingress-only default-deny:
# 		- No one (alpha-client, beta-client) can reach alpha-server.
# 		- alpha pods can still call other pods (e.g., alpha-client → beta-server).

# 	After Egress-only default-deny:
# 		- alpha-client can no longer call alpha-server, DNS, or external endpoints.
# 		- beta-client can still call alpha-server (unless ingress default-deny is also present).
# ---------------------------------------------------------------------------------------------------
.PHONY: run-networkpolicy-ingress-egress-playbook
run-networkpolicy-ingress-egress-playbook: setup-minikube ## Explore INGRESS-only and EGRESS-only default-deny in team-alpha.
	@printf '$(YELLOW)%s$(RESET)\n' "Step A0. Reset lab and apply namespaces/pods..."
	$(MAKE) -f Makefile_NetworkPolicy cleanup
	$(MAKE) -f Makefile_NetworkPolicy apply-namespaces
	$(MAKE) -f Makefile_NetworkPolicy apply-pods
	$(MAKE) -f Makefile_NetworkPolicy test-baseline-connectivity

	@printf '$(YELLOW)%s$(RESET)\n' "Step A1. Apply INGRESS-only default-deny in team-alpha..."
	$(MAKE) -f Makefile_NetworkPolicy apply-alpha-default-deny-ingress

	@printf '$(YELLOW)%s$(RESET)\n' "Step A2. Test behavior under INGRESS-only default-deny..."
	$(MAKE) -f Makefile_NetworkPolicy test-alpha-default-deny-ingress

	@printf '$(YELLOW)%s$(RESET)\n' "Step A3. Apply EGRESS-only default-deny in team-alpha..."
	$(MAKE) -f Makefile_NetworkPolicy apply-alpha-default-deny-egress

	@printf '$(YELLOW)%s$(RESET)\n' "Debug alpha-server wiring..."
	$(MAKE) -f Makefile_NetworkPolicy debug-alpha-server
	
	@printf '$(YELLOW)%s$(RESET)\n' "Step A4. Test behavior under EGRESS-only default-deny..."
	$(MAKE) -f Makefile_NetworkPolicy test-alpha-default-deny-egress

# --------------------------------------------------------------------------------------------------
#					playbook for myapp + Netpol
# -------------------------------------------------------------------------------------------------
.PHONY: run-myapp-least-privilege-playbook
run-myapp-least-privilege-playbook: setup-minikube ## Deploy myapp via Helm and enforce least-privilege NetworkPolicies.
	@printf '$(YELLOW)%s$(RESET)\n' "Step M0. Reset lab and apply namespaces/pods..." ;\
	printf '$(CYAN)%s$(RESET)\n' "Deleting the namespaces will automatically delete myapp, dummy Postgres, NetworkPolicies, Services, etc";\
	read -r _; \
	$(MAKE) -f Makefile_NetworkPolicy cleanup
	$(MAKE) -f Makefile_NetworkPolicy apply-namespaces
	$(MAKE) -f Makefile_NetworkPolicy apply-pods
	$(MAKE) -f Makefile_NetworkPolicy test-baseline-connectivity

	@printf '$(YELLOW)%s$(RESET)\n' "Step M0.0.1 Install/upgrade myapp into team-alpha...";\
	printf '$(CYAN)%s$(RESET)\n' "Press ENTER to Step M0..."; \
	read -r _; \
	$(MAKE) -f Makefile_Myapp myapp-install

	@printf '$(YELLOW)%s$(RESET)\n' "Step M0.0.2. Install dummy Postgres into team-alpha...";\
	printf '$(CYAN)%s$(RESET)\n' "Press ENTER to Step M0.0.1..."; \
	read -r _; \
	$(MAKE) -f Makefile_Myapp postgres-install

	@printf '$(YELLOW)%s$(RESET)\n' "Step M0.3. Validate the ingress controller, myapp service/pods, and Postgres service/pods are present and wired correctly..." ;\
	printf '$(CYAN)%s$(RESET)\n' "Press ENTER to Step M0.3..."; \
	read -r _; \
	$(MAKE) -f Makefile_NetworkPolicy debug-myapp-env

	@printf '$(YELLOW)%s$(RESET)\n' "Step M1. Apply default-deny for team-alpha (Ingress+Egress)..." ;\
	printf '$(CYAN)%s$(RESET)\n' "Press ENTER to Step M1.."; \
	read -r _; \
	$(MAKE) -f Makefile_NetworkPolicy apply-default-deny

	@printf '$(YELLOW)%s$(RESET)\n' "Step M2. Apply myapp-specific ingress/egress allow policies..." ;\
	printf '$(CYAN)%s$(RESET)\n' "Press ENTER to Step M2..."; \
	read -r _; \
	$(MAKE) -f Makefile_NetworkPolicy apply-myapp-netpol; \
    $(MAKE) -f Makefile_NetworkPolicy apply-myapp-allow-external-payment-api

	@printf '$(YELLOW)%s$(RESET)\n' "Step M3. Test myapp ingress (only ingress-nginx allowed)..." ;\
	printf '$(CYAN)%s$(RESET)\n' "Press ENTER to Step M3..."; \
	read -r _; \
	$(MAKE) -f Makefile_NetworkPolicy test-myapp-ingress

	@printf '$(YELLOW)%s$(RESET)\n' "Step M4. Test myapp egress (only Postgres:5432 allowed)..." ;\
	printf '$(CYAN)%s$(RESET)\n' "Press ENTER to Step M4..."; \
	read -r _; \
	$(MAKE) -f Makefile_NetworkPolicy test-myapp-egress

	@printf '$(YELLOW)%s$(RESET)\n' "Step M5. Create debug pod and test myapp external payment API egress (ipBlock)..." ;\
    printf '$(CYAN)%s$(RESET)\n' "Press ENTER to Step M5..."; \
    read -r _; \
    $(MAKE) -f Makefile_NetworkPolicy create-myapp-debug; \
    $(MAKE) -f Makefile_NetworkPolicy test-myapp-external-api-egress;

	@printf '$(CYAN)%s$(RESET)\n' "Press ENTER to delete myapp-debug pod..."; \
    read -r _; \
    $(MAKE) -f Makefile_NetworkPolicy delete-myapp-debug