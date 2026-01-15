.PHONY: help monitoring-deploy monitoring-status monitoring-delete metrics-test grafana-url grafana-password

# Default target
help:
	@echo "Task Manager - Monitoring Commands"
	@echo ""
	@echo "Available targets:"
	@echo "  monitoring-deploy     - Deploy complete monitoring stack (Grafana + Prometheus)"
	@echo "  monitoring-status     - Show status of monitoring components"
	@echo "  monitoring-delete     - Remove monitoring stack"
	@echo "  metrics-test          - Test metrics endpoint"
	@echo "  grafana-url           - Get Grafana dashboard URL"
	@echo "  grafana-password      - Get Grafana admin password"
	@echo "  generate-traffic      - Generate test HTTP traffic"
	@echo ""

# Deploy monitoring stack
monitoring-deploy:
	@echo "Deploying monitoring stack..."
	@chmod +x scripts/deploy-monitoring.sh
	@./scripts/deploy-monitoring.sh

# Show monitoring status
monitoring-status:
	@echo "=== Monitoring Namespace ==="
	@kubectl get all -n monitoring
	@echo ""
	@echo "=== PodMonitoring Resources ==="
	@kubectl get podmonitoring -A
	@echo ""
	@echo "=== GMP System ==="
	@kubectl get pods -n gmp-system
	@echo ""
	@echo "=== Grafana Ingress ==="
	@kubectl get ingress -n monitoring

# Delete monitoring stack
monitoring-delete:
	@echo "WARNING: This will delete Grafana and all dashboards!"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		helm uninstall grafana -n monitoring || true; \
		kubectl delete namespace monitoring || true; \
		kubectl delete podmonitoring task-manager || true; \
		echo "Monitoring stack deleted"; \
	else \
		echo "Cancelled"; \
	fi

# Test metrics endpoint
metrics-test:
	@echo "Port-forwarding to Task Manager pod..."
	@kubectl port-forward deployment/task-manager 8080:8080 &
	@sleep 2
	@echo ""
	@echo "Fetching metrics from /metrics endpoint..."
	@curl -s http://localhost:8080/metrics | head -50
	@echo ""
	@echo "... (truncated, showing first 50 lines)"
	@pkill -f "kubectl port-forward"

# Get Grafana URL
grafana-url:
	@echo "Grafana Dashboard URL:"
	@GRAFANA_IP=$$(kubectl get ingress grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null); \
	if [ -z "$$GRAFANA_IP" ]; then \
		echo "  Status: Load Balancer IP not yet assigned"; \
		echo "  Run: kubectl get ingress grafana -n monitoring --watch"; \
	else \
		echo "  http://$$GRAFANA_IP"; \
	fi

# Get Grafana password
grafana-password:
	@echo "Grafana Login Credentials:"
	@echo "  Username: admin"
	@echo "  Password: changeme123"
	@echo ""
	@echo "IMPORTANT: Change this password after first login!"

# Generate test traffic
generate-traffic:
	@echo "Generating test HTTP traffic..."
	@TASK_MANAGER_IP=$$(kubectl get ingress task-manager -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null); \
	if [ -z "$$TASK_MANAGER_IP" ]; then \
		echo "Error: Task Manager ingress IP not found"; \
		exit 1; \
	fi; \
	echo "Target: http://$$TASK_MANAGER_IP/healthz"; \
	for i in $$(seq 1 100); do \
		curl -s -o /dev/null http://$$TASK_MANAGER_IP/healthz; \
		echo -n "."; \
	done; \
	echo ""; \
	echo "Sent 100 requests. Check Grafana dashboard for metrics."
