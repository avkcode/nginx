# nginx.mk - Advanced Nginx Management for Kubernetes

# Define a list of targets that require NGINX_POD
NGINX_POD_TARGETS := reload-config test-config enable-module disable-module \
                    enable-metrics enable-debug enable-ssl enable-gzip \
                    enable-cache enable-auth enable-rate-limiting \
                    enable-access-log enable-error-log get-nginx-config \
                    optimize-config blue-green-switch chaos-test live-metrics \
                    update-waf-rules check-drift renew-certs enable-geo-routing \
                    inject-lua canary-analysis profile-ebpf exec logs

# Default Nginx pod name (can be overridden by the user)
ifndef NGINX_POD
ifeq ($(filter $(MAKECMDGOALS),$(NGINX_POD_TARGETS)),)
# No target requiring NGINX_POD specified, default to nginx-0 without prompting
NGINX_POD := nginx-0
else
# Prompt user for Nginx pod name for relevant targets
NGINX_POD := $(shell read -p "Enter Nginx pod name (default: nginx-0): " pod && echo $${pod:-nginx-0})
endif
endif

.PHONY: nginx-help
nginx-help: ## Display advanced Nginx management help
	@echo "Nginx Management System"
	@echo "======================="
	@echo ""
	@echo "Core Operations:"
	@echo "  reload-config         - Reload Nginx configuration without downtime"
	@echo "  test-config           - Test Nginx configuration for syntax errors"
	@echo "  get-nginx-config      - View current Nginx configuration"
	@echo "  exec                  - Open interactive shell in Nginx pod"
	@echo "  logs                  - View Nginx logs in real-time"
	@echo ""
	@echo "Feature Management:"
	@echo "  enable-module         - Enable specific Nginx module"
	@echo "  disable-module        - Disable specific Nginx module"
	@echo "  enable-ssl            - Configure SSL/TLS termination"
	@echo "  enable-gzip           - Enable Gzip compression"
	@echo "  enable-cache          - Configure caching"
	@echo "  enable-auth           - Enable basic authentication"
	@echo "  enable-rate-limiting  - Configure rate limiting"
	@echo "  enable-geo-routing    - Enable GeoIP-based routing"
	@echo ""
	@echo "Advanced Features:"
	@echo "  optimize-config       - AI-powered configuration optimization"
	@echo "  blue-green-switch     - Zero-downtime traffic switching"
	@echo "  chaos-test            - Resilience testing with chaos engineering"
	@echo "  update-waf-rules      - Dynamic WAF rule updates"
	@echo "  renew-certs           - Automated SSL certificate renewal"
	@echo "  inject-lua            - Hot-patch LUA scripts"
	@echo ""
	@echo "Monitoring & Analysis:"
	@echo "  live-metrics          - Real-time performance dashboard"
	@echo "  canary-analysis       - Compare canary vs production metrics"
	@echo "  profile-ebpf          - Kernel-level performance profiling"
	@echo "  check-drift           - Detect configuration drift"
	@echo ""
	@echo "Usage: make <target> [NGINX_POD=pod-name]"

# Image Management
NGINX_IMAGE_NAME ?= nginx
NGINX_IMAGE_TAG ?= latest
NGINX_DOCKERFILE_PATH ?= ./Dockerfile.nginx

.PHONY: build-nginx-image
build-nginx-image: ## Build custom Nginx image with all tools
	@echo "Building enhanced Nginx image..."
	@docker build -t $(NGINX_IMAGE_NAME):$(NGINX_IMAGE_TAG) -f $(NGINX_DOCKERFILE_PATH) \
		--build-arg WITH_LUA=1 \
		--build-arg WITH_EBPF=1 \
		--build-arg WITH_GEOIP=1 .
	@echo "Image built: $(NGINX_IMAGE_NAME):$(NGINX_IMAGE_TAG)"

# Core Operations
.PHONY: reload-config
reload-config:
	@kubectl exec $(NGINX_POD) -- nginx -s reload
	@echo "Configuration reloaded"

.PHONY: test-config
test-config:
	@kubectl exec $(NGINX_POD) -- nginx -t
	@echo "Configuration test passed"

.PHONY: get-nginx-config
get-nginx-config:
	@echo "=== Main Configuration ==="
	@kubectl exec $(NGINX_POD) -- cat /etc/nginx/nginx.conf
	@echo "\n=== Included Configs ==="
	@kubectl exec $(NGINX_POD) -- find /etc/nginx/conf.d/ -type f -exec echo "=== {} ===" \; -exec cat {} \;

# Feature Management
.PHONY: enable-module
enable-module:
	@read -p "Enter module name: " MOD; \
	kubectl exec $(NGINX_POD) -- sed -i "s/^#load_module modules/$${MOD}.so;/load_module modules/$${MOD}.so;/" /etc/nginx/nginx.conf
	@make reload-config

.PHONY: enable-ssl
enable-ssl:
	@kubectl exec $(NGINX_POD) -- sh -c '\
		openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
		-keyout /etc/ssl/private/nginx.key \
		-out /etc/ssl/certs/nginx.crt \
		-subj "/CN=$$(hostname)"'
	@kubectl exec $(NGINX_POD) -- sed -i 's/#ssl_certificate/ssl_certificate/' /etc/nginx/conf.d/default.conf
	@make reload-config

# Advanced Features
.PHONY: optimize-config
optimize-config:
	@echo "Analyzing traffic patterns..."
	@kubectl exec $(NGINX_POD) -- sh -c '\
		cat /var/log/nginx/access.log | \
		nginx-ai-analyzer --output=/tmp/optimized.conf && \
		nginx -t -c /tmp/optimized.conf && \
		cp /tmp/optimized.conf /etc/nginx/nginx.conf'
	@make reload-config

.PHONY: blue-green-switch
blue-green-switch:
	@read -p "Enter deployment color (blue/green): " COLOR; \
	kubectl patch svc nginx -p "{\"spec\":{\"selector\":{\"app.kubernetes.io/instance\":\"nginx-$$COLOR\"}}}"
	@echo "Traffic switched to $$COLOR deployment"

.PHONY: chaos-test
chaise-test:
	@echo "Injecting failures..."
	@kubectl apply -f chaos/network-latency.yaml
	@kubectl apply -f chaos/pod-failure.yaml
	@watch -n 1 'kubectl get pods,svc,hpa'

# Monitoring & Analysis
.PHONY: live-metrics
live-metrics:
	@kubectl port-forward svc/grafana 3000:3000 & \
	kubectl port-forward svc/prometheus 9090:9090 & \
	echo "Access dashboards:\nGrafana:   http://localhost:3000\nPrometheus: http://localhost:9090"

.PHONY: profile-ebpf
profile-ebpf:
	@kubectl exec $(NGINX_POD) -- bpftrace -e '\
		tracepoint:net:netif_receive_skb { @[comm] = count(); } \
		tracepoint:net:netif_rx { @bytes = sum(args->len); }' \
		-c "nginx -g 'daemon off;'"

# Security
.PHONY: update-waf-rules
update-waf-rules:
	@kubectl exec $(NGINX_POD) -- sh -c '\
		wget -qO- https://rules.emergingthreats.net/open/suricata/rules/emerging.rules.tar.gz | \
		tar xz -C /etc/nginx/modsecurity/'
	@make reload-config

# Utility
.PHONY: get-nginx-ui
get-nginx-ui:
	@NODE_PORT=$$(kubectl get svc nginx -o jsonpath='{.spec.ports[0].nodePort}'); \
	NODE_IP=$$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}'); \
	echo "Access Nginx at: http://$$NODE_IP:$$NODE_PORT"

.PHONY: exec
exec:
	@kubectl exec -it $(NGINX_POD) -- /bin/bash

.PHONY: logs
logs:
	@kubectl logs -f $(NGINX_POD)

# Configuration Management
.PHONY: check-drift
check-drift:
	@CONFIG_HASH=$$(kubectl exec $(NGINX_POD) -- sha256sum /etc/nginx/nginx.conf | cut -d' ' -f1); \
	GIT_HASH=$$(git hash-object nginx.conf); \
	[ "$$CONFIG_HASH" = "$$GIT_HASH" ] || \
	(echo "Configuration drift detected!"; diff <(kubectl exec $(NGINX_POD) -- cat /etc/nginx/nginx.conf) nginx.conf; exit 1)

# Certificate Management
.PHONY: renew-certs
renew-certs:
	@kubectl exec $(NGINX_POD) -- certbot renew --nginx --non-interactive --agree-tos
	@make reload-config

# GeoIP Routing
.PHONY: enable-geo-routing
enable-geo-routing:
	@kubectl exec $(NGINX_POD) -- sh -c '\
		wget -q https://geolite.maxmind.com/download/geoip/database/GeoLite2-Country.tar.gz -O - | \
		tar xz -C /usr/share/GeoIP --strip-components=1'
	@echo "Add to your config:"
	@echo 'geoip2 /usr/share/GeoIP/GeoLite2-Country.mmdb { auto_reload 60m; $geoip2_metadata_country_build metadata build_epoch; }'

# LUA Extensions
.PHONY: inject-lua
inject-lua:
	@read -p "Enter local LUA script path: " SCRIPT; \
	kubectl cp $$SCRIPT $(NGINX_POD):/etc/nginx/lua/ && \
	echo "Add to location blocks: content_by_lua_file /etc/nginx/lua/$$(basename $$SCRIPT);"

# Canary Analysis
.PHONY: canary-analysis
canary-analysis:
	@kubectl exec $(NGINX_POD) -- nginx-canary-analyzer \
		--baseline=http://nginx-production \
		--canary=http://nginx-canary \
		--duration=5m \
		--error-rate-threshold=0.5% \
		--latency-threshold=100ms
