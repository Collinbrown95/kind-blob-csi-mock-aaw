CLUSTER := blob-csi-driver
KUBECTL := kubectl --context kind-$(CLUSTER)

AZURE_BLOB_CSI_NAMESPACE := azure-blob-csi-system
K8S_VERSION := "kindest/node:v1.19.11"

KUSTOMIZE_OPTS := --load-restrictor LoadRestrictionsNone

install: kind-create azure-secret push profile-crd manifests
destroy: azure-destroy kind-destroy

profile-crd:
	$(KUBECTL) apply -f https://raw.githubusercontent.com/kubeflow/kubeflow/master/components/profile-controller/config/crd/bases/kubeflow.org_profiles.yaml

manifests: manifests/blob-csi-driver.yaml
	kustomize build manifests/ $(KUSTOMIZE_OPTS) | $(KUBECTL) apply -f -

kind-create:
	kind get clusters | grep -q $(CLUSTER) || \
		kind create cluster --name $(CLUSTER) --image $(K8S_VERSION)

	kind get clusters | grep -q $(CLUSTER) || \
	CID=$$(docker ps | grep $(CLUSTER)-control-plane | awk '{print $$1}') \
	docker exec $(CID) sh -c 'apt-get install libcurl3-gnutls'


# Blob CSI
helm-setup:
	helm repo add blob-csi-driver \
		https://raw.githubusercontent.com/kubernetes-sigs/blob-csi-driver/master/charts || true

manifests/blob-csi-driver.yaml: helm-setup
	mkdir -p $$(dirname $@)
	helm template blob-csi-driver \
		blob-csi-driver/blob-csi-driver \
		--set node.enableBlobfuseProxy=true \
		--namespace kube-system \
		--version v1.9.0 > $@

terraform/terraform.tfstate:
	cd terraform; \
	terraform init; \
	terraform apply

AZURE_DEPS := $(AZURE_BLOB_CSI_NAMESPACE) terraform/terraform.tfstate
$(AZURE_BLOB_CSI_NAMESPACE):
	$(KUBECTL) create ns $@ || true

azure-secret: azure-secret-standard azure-secret-premium azure-secret-fdi-unclassified azure-secret-fdi-prob
azure-secret-standard: $(AZURE_DEPS)
	export NAME=$$(terraform -chdir=terraform output name | tr -d '"'); \
	export KEY=$$(terraform -chdir=terraform output access_key | tr -d '"'); \
	$(KUBECTL) get secret azure-secret -n $(AZURE_BLOB_CSI_NAMESPACE) || \
	$(KUBECTL) create secret generic azure-secret -n $(AZURE_BLOB_CSI_NAMESPACE) \
		--from-literal azurestorageaccountname=$$NAME \
		--from-literal azurestorageaccountkey=$$KEY

azure-secret-premium: $(AZURE_DEPS)
	export NAME=$$(terraform -chdir=terraform output premium_name | tr -d '"'); \
	export KEY=$$(terraform -chdir=terraform output premium_access_key | tr -d '"'); \
	$(KUBECTL) get secret azure-secret-premium -n $(AZURE_BLOB_CSI_NAMESPACE) || \
	$(KUBECTL) create secret generic azure-secret-premium -n $(AZURE_BLOB_CSI_NAMESPACE) \
		--from-literal azurestorageaccountname=$$NAME \
		--from-literal azurestorageaccountkey=$$KEY

azure-secret-fdi-prob: $(AZURE_DEPS)
	export NAME=$$(terraform -chdir=terraform output fdi_prob_name | tr -d '"'); \
	export KEY=$$(terraform -chdir=terraform output fdi_prob_access_key | tr -d '"'); \
	$(KUBECTL) get secret azure-secret-fdi-prob -n $(AZURE_BLOB_CSI_NAMESPACE) || \
	$(KUBECTL) create secret generic azure-secret-fdi-prob -n $(AZURE_BLOB_CSI_NAMESPACE) \
		--from-literal azurestorageaccountname=$$NAME \
		--from-literal azurestorageaccountkey=$$KEY

azure-secret-fdi-unclassified: $(AZURE_DEPS)
	export NAME=$$(terraform -chdir=terraform output fdi_unclassified_name | tr -d '"'); \
	export KEY=$$(terraform -chdir=terraform output fdi_unclassified_access_key | tr -d '"'); \
	$(KUBECTL) get secret azure-secret-fdi-unclassified -n $(AZURE_BLOB_CSI_NAMESPACE) || \
	$(KUBECTL) create secret generic azure-secret-fdi-unclassified -n $(AZURE_BLOB_CSI_NAMESPACE) \
		--from-literal azurestorageaccountname=$$NAME \
		--from-literal azurestorageaccountkey=$$KEY


# Images
build:
	cd apps/blob-csi-injector && docker build . -t blob-csi-injector:latest
	cd apps/create-pvc        && docker build . -t create-pvc:latest

push: build
	kind load docker-image blob-csi-injector:latest --name $(CLUSTER)
	kind load docker-image create-pvc:latest        --name $(CLUSTER)



# Destroy
azure-destroy:
	cd terraform; \
	terraform destroy

kind-delete:
	kind delete cluster --name $(CLUSTER)
