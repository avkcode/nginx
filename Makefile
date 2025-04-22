SHELL := /bin/bash

# Check if DEBUG=1 is set, and conditionally add MAKEFLAGS
ifeq ($(DEBUG),1)
	MAKEFLAGS += --no-print-directory
	MAKEFLAGS += --keep-going
	MAKEFLAGS += --ignore-errors
endif

# Default goal
.DEFAULT_GOAL := help

.PHONY: help
help:
	@echo "Available targets:"
	@echo ""
	@echo "  generate-chart    - Generate Helm chart from Kubernetes manifests"
	@echo "  template          - Generate Kubernetes manifests from templates"
	@echo "  apply             - Apply generated manifests to the Kubernetes cluster"
	@echo "  delete            - Delete Kubernetes resources defined in the manifests"
	@echo "  validate-%        - Validate a specific manifest using yq, e.g. make validate-rbac"
	@echo "  print-%           - Print the value of a specific variable"
	@echo "  switch-namespace  - Switch the current Kubernetes namespace"
	@echo "  archive           - Create a git archive"
	@echo "  bundle            - Create a git bundle"
	@echo "  clean             - Clean up generated files"
	@echo "  release           - Create a Git tag and release on GitHub"
	@echo "  show-params       - Show contents of the parameter file for the current environment"
	@echo "  interactive       - Start an interactive session"
	@echo "  create-release    - Create a Kubernetes secret with VERSION set to Git commit SHA"
	@echo "  remove-release    - Remove the dynamically created Kubernetes secret"
	@echo "  dump-manifests    - Dump manifests in both YAML and JSON formats to the current directory"
	@echo "  convert-to-json   - Convert manifests to JSON format"
	@echo "  validate-server   - Validate JSON manifests against the Kubernetes API (server-side)"
	@echo "  validate-client   - Validate JSON manifests against the Kubernetes API (client-side)"
	@echo "  list-vars         - List all non-built-in variables, their origins, and values."
	@echo "  package           - Create a tar.gz archive of the entire directory"
	@echo "  diff              - Interactive diff selection menu"
	@echo "  diff-live         - Compare live cluster state with generated manifests"
	@echo "  diff-previous     - Compare previous applied manifests with current generated manifests"
	@echo "  diff-revisions    - Compare manifests between two git revisions"
	@echo "  diff-environments - Compare manifests between two environments"
	@echo "  diff-params       - Compare parameters between two environments"
	@echo "  help              - Display this help message"

##########
##########

ENV ?= dev
# This allows users to override the ENV variable by passing it as an argument to `make`.

ALLOWED_ENVS := global dev sit uat prod
# Define a list of allowed environments. These are the valid values for the ENV variable.

ifeq ($(filter $(ENV),$(ALLOWED_ENVS)),)
    $(error Invalid ENV value '$(ENV)'. Allowed values are: $(ALLOWED_ENVS))
endif

PARAM_FILE := $(ENV).param
ifeq ($(wildcard $(PARAM_FILE)),)
	$(error Parameter file for environment '$(ENV)' not found: $(PARAM_FILE))
endif
include $(PARAM_FILE)
# This ensures that only predefined environments can be used.

# The global.param file contains shared parameters that apply to all environments unless explicitly overridden.
# For example, it might define default values for DOCKER_IMAGE, or resource allocation (CPU_REQUEST, MEMORY_REQUEST, etc.).
include global.param

include diff.mk

include labels.mk

##########
##########

define serviceaccount
---
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
$(call generate_labels)
  name: release-name-ingress-nginx
  namespace: default
automountServiceAccountToken: true
endef
export serviceaccount

define configmap
---
apiVersion: v1
kind: ConfigMap
metadata:
  labels:
$(call generate_labels)
  name: release-name-ingress-nginx-controller
  namespace: default
data:
endef
export configmap

define clusterrole
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  labels:
$(call generate_labels)
  name: release-name-ingress-nginx
rules:
  - apiGroups:
      - ""
    resources:
      - configmaps
      - endpoints
      - nodes
      - pods
      - secrets
      - namespaces
    verbs:
      - list
      - watch
  - apiGroups:
      - coordination.k8s.io
    resources:
      - leases
    verbs:
      - list
      - watch
  - apiGroups:
      - ""
    resources:
      - nodes
    verbs:
      - get
  - apiGroups:
      - ""
    resources:
      - services
    verbs:
      - get
      - list
      - watch
  - apiGroups:
      - networking.k8s.io
    resources:
      - ingresses
    verbs:
      - get
      - list
      - watch
  - apiGroups:
      - ""
    resources:
      - events
    verbs:
      - create
      - patch
  - apiGroups:
      - networking.k8s.io
    resources:
      - ingresses/status
    verbs:
      - update
  - apiGroups:
      - networking.k8s.io
    resources:
      - ingressclasses
    verbs:
      - get
      - list
      - watch
  - apiGroups:
      - discovery.k8s.io
    resources:
      - endpointslices
    verbs:
      - list
      - watch
      - get
endef
export clusterrole

define clusterrolebinding
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  labels:
$(call generate_labels)
  name: release-name-ingress-nginx
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: release-name-ingress-nginx
subjects:
  - kind: ServiceAccount
    name: release-name-ingress-nginx
    namespace: default
endef
export clusterrolebinding

define role
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  labels:
$(call generate_labels)
  name: release-name-ingress-nginx
  namespace: default
rules:
  - apiGroups:
      - ""
    resources:
      - namespaces
    verbs:
      - get
  - apiGroups:
      - ""
    resources:
      - configmaps
      - pods
      - secrets
      - endpoints
    verbs:
      - get
      - list
      - watch
  - apiGroups:
      - ""
    resources:
      - services
    verbs:
      - get
      - list
      - watch
  - apiGroups:
      - networking.k8s.io
    resources:
      - ingresses
    verbs:
      - get
      - list
      - watch
  - apiGroups:
      - networking.k8s.io
    resources:
      - ingresses/status
    verbs:
      - update
  - apiGroups:
      - networking.k8s.io
    resources:
      - ingressclasses
    verbs:
      - get
      - list
      - watch
  - apiGroups:
      - coordination.k8s.io
    resources:
      - leases
    resourceNames:
      - release-name-ingress-nginx-leader
    verbs:
      - get
      - update
  - apiGroups:
      - coordination.k8s.io
    resources:
      - leases
    verbs:
      - create
  - apiGroups:
      - ""
    resources:
      - events
    verbs:
      - create
      - patch
  - apiGroups:
      - discovery.k8s.io
    resources:
      - endpointslices
    verbs:
      - list
      - watch
      - get
endef
export role

define rolebinding
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  labels:
$(call generate_labels)
  name: release-name-ingress-nginx
  namespace: default
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: release-name-ingress-nginx
subjects:
  - kind: ServiceAccount
    name: release-name-ingress-nginx
    namespace: default
endef
export rolebinding

define webhook_service
---
apiVersion: v1
kind: Service
metadata:
  labels:
$(call generate_labels)
  name: release-name-ingress-nginx-controller-admission
  namespace: default
spec:
  type: ClusterIP
  ports:
    - name: https-webhook
      port: 443
      targetPort: webhook
      appProtocol: https
  selector:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/instance: release-name
    app.kubernetes.io/component: controller
endef
export webhook_service

define controller_service
---
apiVersion: v1
kind: Service
metadata:
  annotations:
  labels:
$(call generate_labels)
  name: release-name-ingress-nginx-controller
  namespace: default
spec:
  type: LoadBalancer
  ipFamilyPolicy: SingleStack
  ipFamilies: 
    - IPv4
  ports:
    - name: http
      port: 80
      protocol: TCP
      targetPort: http
      appProtocol: http
    - name: https
      port: 443
      protocol: TCP
      targetPort: https
      appProtocol: https
  selector:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/instance: release-name
    app.kubernetes.io/component: controller
endef
export controller_service

define deployment
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
$(call generate_labels)
  name: release-name-ingress-nginx-controller
  namespace: default
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: ingress-nginx
      app.kubernetes.io/instance: release-name
      app.kubernetes.io/component: controller
  replicas: 1
  revisionHistoryLimit: 10
  minReadySeconds: 0
  template:
    metadata:
      labels:
    $(call generate_labels)
    spec:
      dnsPolicy: ClusterFirst
      containers:
        - name: controller
          image: registry.k8s.io/ingress-nginx/controller:v1.12.1@sha256:d2fbc4ec70d8aa2050dd91a91506e998765e86c96f32cffb56c503c9c34eed5b
          imagePullPolicy: IfNotPresent
          lifecycle: 
            preStop:
              exec:
                command:
                - /wait-shutdown
          args: 
            - /nginx-ingress-controller
            - --publish-service=$(POD_NAMESPACE)/release-name-ingress-nginx-controller
            - --election-id=release-name-ingress-nginx-leader
            - --controller-class=k8s.io/ingress-nginx
            - --ingress-class=nginx
            - --configmap=$(POD_NAMESPACE)/release-name-ingress-nginx-controller
            - --validating-webhook=:8443
            - --validating-webhook-certificate=/usr/local/certificates/cert
            - --validating-webhook-key=/usr/local/certificates/key
          securityContext: 
            runAsNonRoot: true
            runAsUser: 101
            runAsGroup: 82
            allowPrivilegeEscalation: false
            seccompProfile: 
              type: RuntimeDefault
            capabilities:
              drop:
              - ALL
              add:
              - NET_BIND_SERVICE
            readOnlyRootFilesystem: false
          env:
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: POD_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
            - name: LD_PRELOAD
              value: /usr/local/lib/libmimalloc.so
          livenessProbe: 
            failureThreshold: 5
            httpGet:
              path: /healthz
              port: 10254
              scheme: HTTP
            initialDelaySeconds: 10
            periodSeconds: 10
            successThreshold: 1
            timeoutSeconds: 1
          readinessProbe: 
            failureThreshold: 3
            httpGet:
              path: /healthz
              port: 10254
              scheme: HTTP
            initialDelaySeconds: 10
            periodSeconds: 10
            successThreshold: 1
            timeoutSeconds: 1
          ports:
            - name: http
              containerPort: 80
              protocol: TCP
            - name: https
              containerPort: 443
              protocol: TCP
            - name: webhook
              containerPort: 8443
              protocol: TCP
          volumeMounts:
            - name: webhook-cert
              mountPath: /usr/local/certificates/
              readOnly: true
          resources: 
            requests:
              cpu: 100m
              memory: 90Mi
      nodeSelector: 
        kubernetes.io/os: linux
      serviceAccountName: release-name-ingress-nginx
      automountServiceAccountToken: true
      terminationGracePeriodSeconds: 300
      volumes:
        - name: webhook-cert
          secret:
            secretName: release-name-ingress-nginx-admission
endef
export deployment

define ingressclass
---
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  labels:
$(call generate_labels)
  name: nginx
spec:
  controller: k8s.io/ingress-nginx
endef
export ingressclass

define validatingwebhook
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingWebhookConfiguration
metadata:
  annotations:
  labels:
$(call generate_labels)
  name: release-name-ingress-nginx-admission
webhooks:
  - name: validate.nginx.ingress.kubernetes.io
    matchPolicy: Equivalent
    rules:
      - apiGroups:
          - networking.k8s.io
        apiVersions:
          - v1
        operations:
          - CREATE
          - UPDATE
        resources:
          - ingresses
    failurePolicy: Fail
    sideEffects: None
    admissionReviewVersions:
      - v1
    clientConfig:
      service:
        name: release-name-ingress-nginx-controller-admission
        namespace: default
        port: 443
        path: /networking/v1/ingresses
endef
export validatingwebhook

define admission_serviceaccount
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: release-name-ingress-nginx-admission
  namespace: default
  annotations:
    "helm.sh/hook": pre-install,pre-upgrade,post-install,post-upgrade
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
  labels:
$(call generate_labels)
automountServiceAccountToken: true
endef
export admission_serviceaccount

define admission_clusterrole
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: release-name-ingress-nginx-admission
  labels:
$(call generate_labels)
rules:
  - apiGroups:
      - admissionregistration.k8s.io
    resources:
      - validatingwebhookconfigurations
    verbs:
      - get
      - update
endef
export admission_clusterrole

define admission_clusterrolebinding
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: release-name-ingress-nginx-admission
  labels:
$(call generate_labels)
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: release-name-ingress-nginx-admission
subjects:
  - kind: ServiceAccount
    name: release-name-ingress-nginx-admission
    namespace: default
endef
export admission_clusterrolebinding

define admission_role
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: release-name-ingress-nginx-admission
  namespace: default
  annotations:
    "helm.sh/hook": pre-install,pre-upgrade,post-install,post-upgrade
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
  labels:
$(call generate_labels)
rules:
  - apiGroups:
      - ""
    resources:
      - secrets
    verbs:
      - get
      - create
endef
export admission_role

define admission_rolebinding
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: release-name-ingress-nginx-admission
  namespace: default
  annotations:
    "helm.sh/hook": pre-install,pre-upgrade,post-install,post-upgrade
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
  labels:
$(call generate_labels)
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: release-name-ingress-nginx-admission
subjects:
  - kind: ServiceAccount
    name: release-name-ingress-nginx-admission
    namespace: default
endef
export admission_rolebinding

define create_secret_job
---
apiVersion: batch/v1
kind: Job
metadata:
  name: release-name-ingress-nginx-admission-create
  namespace: default
  labels:
$(call generate_labels)
spec:
  template:
    metadata:
      name: release-name-ingress-nginx-admission-create
      labels:
    $(call generate_labels)
    spec:
      containers:
        - name: create
          image: registry.k8s.io/ingress-nginx/kube-webhook-certgen:v1.5.2@sha256:e8825994b7a2c7497375a9b945f386506ca6a3eda80b89b74ef2db743f66a5ea
          imagePullPolicy: IfNotPresent
          args:
            - create
            - --host=release-name-ingress-nginx-controller-admission,release-name-ingress-nginx-controller-admission.$(POD_NAMESPACE).svc
            - --namespace=$(POD_NAMESPACE)
            - --secret-name=release-name-ingress-nginx-admission
          env:
            - name: POD_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
          securityContext: 
            allowPrivilegeEscalation: false
            capabilities:
              drop:
              - ALL
            readOnlyRootFilesystem: true
            runAsGroup: 65532
            runAsNonRoot: true
            runAsUser: 65532
            seccompProfile:
              type: RuntimeDefault
      restartPolicy: OnFailure
      serviceAccountName: release-name-ingress-nginx-admission
      automountServiceAccountToken: true
      nodeSelector: 
        kubernetes.io/os: linux
endef
export create_secret_job

define patch_webhook_job
---
apiVersion: batch/v1
kind: Job
metadata:
  name: release-name-ingress-nginx-admission-patch
  namespace: default
  labels:
$(call generate_labels)
spec:
  template:
    metadata:
      name: release-name-ingress-nginx-admission-patch
      labels:
    $(call generate_labels)
    spec:
      containers:
        - name: patch
          image: registry.k8s.io/ingress-nginx/kube-webhook-certgen:v1.5.2@sha256:e8825994b7a2c7497375a9b945f386506ca6a3eda80b89b74ef2db743f66a5ea
          imagePullPolicy: IfNotPresent
          args:
            - patch
            - --webhook-name=release-name-ingress-nginx-admission
            - --namespace=$(POD_NAMESPACE)
            - --patch-mutating=false
            - --secret-name=release-name-ingress-nginx-admission
            - --patch-failure-policy=Fail
          env:
            - name: POD_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
          securityContext: 
            allowPrivilegeEscalation: false
            capabilities:
              drop:
              - ALL
            readOnlyRootFilesystem: true
            runAsGroup: 65532
            runAsNonRoot: true
            runAsUser: 65532
            seccompProfile:
              type: RuntimeDefault
      restartPolicy: OnFailure
      serviceAccountName: release-name-ingress-nginx-admission
      automountServiceAccountToken: true
      nodeSelector: 
        kubernetes.io/os: linux
endef
export patch_webhook_job

##########
##########

manifests += $${serviceaccount}
manifests += $${configmap}
manifests += $${clusterrole}
manifests += $${clusterrolebinding}
manifests += $${role}
manifests += $${rolebinding}
manifests += $${webhook_service}
manifests += $${controller_service}
manifests += $${deployment}
manifests += $${ingressclass}
manifests += $${validatingwebhook}
manifests += $${admission_serviceaccount}
manifests += $${admission_clusterrole}
manifests += $${admission_clusterrolebinding}
manifests += $${admission_role}
manifests += $${admission_rolebinding}
manifests += $${create_secret_job}
manifests += $${patch_webhook_job}

.PHONY: template apply delete

# Outputs the generated Kubernetes manifests to the console.
template:
	@$(foreach manifest,$(manifests),echo "$(manifest)";)

# Applies the generated Kubernetes manifests to the cluster using `kubectl apply`.
apply: create-release
	@$(foreach manifest,$(manifests),echo "$(manifest)" | kubectl apply -f - ;)

# Deletes the Kubernetes resources defined in the generated manifests using `kubectl delete`.
delete: remove-release
	@$(foreach manifest,$(manifests),echo "$(manifest)" | kubectl delete -f - ;)

# Validates a specific manifest using `yq`.
validate-%:
	@echo "$$$*" | yq eval -P '.' -

# Prints the value of a specific variable.
print-%:
	@echo "$$$*"

##########
##########

.PHONY: interactive
interactive:
	@echo "Interactive mode:"
	@read -p "Enter the environment (dev/sit/uat/prod): " env; \
	$(MAKE) ENV=$$env apply

.PHONY: show-params
show-params:
	@echo "Contents of $(PARAM_FILE):"
	@cat $(PARAM_FILE)

.PHONY: switch-namespace
switch-namespace:
	@echo "Listing all available namespaces..."
	@NAMESPACES=$$(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}'); \
	echo "$$NAMESPACES"; \
		read -p "Enter the namespace you want to switch to: " SELECTED_NAMESPACE; \
		if echo "$$NAMESPACES" | grep -qw "$$SELECTED_NAMESPACE"; then \
			kubectl config set-context --current --namespace=$$SELECTED_NAMESPACE; \
			echo "Switched to namespace: $$SELECTED_NAMESPACE"; \
		else \
			echo "Error: Namespace '$$SELECTED_NAMESPACE' not found."; \
		fi

GIT_BRANCH := $(shell git rev-parse --abbrev-ref HEAD)
GIT_COMMIT := $(shell git rev-parse --short HEAD)

.PHONY: archive
archive:
	@echo "Creating git archive..."
	git archive --format=tar.gz --output=archive-$(GIT_BRANCH)-$(GIT_COMMIT).tar.gz HEAD
	@echo "Archive created: archive-$(GIT_BRANCH)-$(GIT_COMMIT).tar.gz"

.PHONY: bundle
bundle:
	@echo "Creating git bundle..."
	git bundle create bundle-$(GIT_BRANCH)-$(GIT_COMMIT).bundle --all
	@echo "Bundle created: bundle-$(GIT_BRANCH)-$(GIT_COMMIT).bundle"

.PHONY: clean
clean:
	@rm -f archive-*.tar.gz bundle-*.bundle manifest.yaml manifest.json

.PHONY: release
release:
	@echo "Creating Git tag and releasing on GitHub..."
	@read -p "Enter the version number (e.g., v1.0.0): " version; \
	git tag -a $$version -m "Release $$version"; \
	git push origin $$version; \
	gh release create $$version --generate-notes
	@echo "Release $$version created and pushed to GitHub."

.PHONY: create-release
create-release:
	@echo "Creating Kubernetes secret with VERSION set to Git commit SHA..."
	@SECRET_NAME="app-version-secret"; \
	JSON_DATA="{\"VERSION\":\"$(GIT_COMMIT)\"}"; \
	kubectl create secret generic $$SECRET_NAME \
		--from-literal=version.json="$$JSON_DATA" \
		--dry-run=client -o yaml | kubectl apply -f -
	@echo "Secret created successfully: app-version-secret"

.PHONY: remove-release
remove-release:
	@echo "Deleting Kubernetes secret: app-version-secret..."
	@SECRET_NAME="app-version-secret"; \
	kubectl delete secret $$SECRET_NAME 2>/dev/null || true
	@echo "Secret deleted successfully: app-version-secret"

.PHONY: show-release
show-release:
	@SECRET_NAME="app-version-secret"; \
	kubectl get secret $$SECRET_NAME -o jsonpath='{.data.version\.json}' | base64 --decode | jq -r .VERSION

.PHONY: convert-to-json
convert-to-json:
	@$(foreach manifest,$(manifests),echo "$(manifest)" | yq eval -o=json -P '.' -;)

.PHONY: validate-server
validate-server:
	@echo "Validating JSON manifests against the Kubernetes API (server-side validation)..."
	@$(foreach manifest,$(manifests), \
		echo "Validating manifest: $(manifest)" && \
		printf '%s' "$(manifest)" | yq eval -o=json -P '.' - | kubectl apply --dry-run=server -f - || exit 1; \
	)
	@echo "All JSON manifests passed server-side validation successfully."

.PHONY: validate-client
validate-client:
	@echo "Validating JSON manifests against the Kubernetes API (client-side validation)..."
	@$(foreach manifest,$(manifests), \
		echo "Validating manifest: $(manifest)" && \
		printf '%s' "$(manifest)" | yq eval -o=json -P '.' - | kubectl apply --dry-run=client -f - || exit 1; \
	)
	@echo "All JSON manifests passed client-side validation successfully."

.PHONY: dump-manifests
dump-manifests: template convert-to-json
	@echo "Dumping manifests to manifest.yaml and manifest.json..."
	@make template > manifest.yaml
	@make convert-to-json > manifest.json
	@echo "Manifests successfully dumped to manifest.yaml and manifest.json."

.PHONY: list-vars
list-vars:
	@echo "Variable Name       Origin"
	@echo "-------------------- -----------"
	@$(foreach var, $(filter-out .% %_FILES, $(.VARIABLES)), \
		$(if $(filter-out default automatic, $(origin $(var))), \
			printf "%-20s %s\\n" "$(var)" "$(origin $(var))"; \
		))

.PHONY: package
package:
	@echo "Creating a tar.gz archive of the entire directory..."
	@DIR_NAME=$$(basename $$(pwd)); \
	TAR_FILE="$$DIR_NAME.tar.gz"; \
	tar -czvf $$TAR_FILE .; \
	echo "Archive created successfully: $$TAR_FILE"
