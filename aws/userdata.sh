#!/bin/bash

# Update the base instance and set up/start docker
yum update -y
yum install -y docker
service docker start
chkconfig docker on

# Get the latest PMM image.
docker pull percona/pmm-server:2

# Set up the pmm-data volume and launch PMM with DBaaS enabled.
docker volume create pmm-data
docker run --detach --restart always \
--env ENABLE_DBAAS=1 \
--publish 443:443 \
-v pmm-data:/srv \
--name pmm-server \
percona/pmm-server:2
echo "PMM containter started..."

# Fetch the k8s config file with a running cluster from the instance tags.
KUBECONFIG_BUCKET=$(wget -q -O - http://169.254.169.254/latest/meta-data/tags/instance/kubeconfig-bucket)
KUBECONFIG_FILE=$(wget -q -O - http://169.254.169.254/latest/meta-data/tags/instance/kubeconfig-file)

echo "Download and JSON-ify s3:$KUBECONFIG_BUCKET/$KUBECONFIG_FILE"

# Download the kubeconfig file locally and convert to JSON format.
aws s3api get-object --bucket "$KUBECONFIG_BUCKET" --key "$KUBECONFIG_FILE" /tmp/kubeconfig.yaml
KUBECONF_JSON=$(sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/\\n/g' /tmp/kubeconfig.yaml)

echo "Now make sure PMM is ready for API calls..."
READY="no"
while [[ "$READY" != "{}" ]]
do
	sleep 2
	READY=$(curl -X 'GET' 'https://admin:admin@127.0.0.1/v1/readyz' -k -s)
done

echo "PMM API is alive... now register the k8s cluster."

# Make local API call to register the k8s cluster.
curl -X 'POST' 'https://admin:admin@127.0.0.1/v1/management/DBaaS/Kubernetes/Register' \
-H 'accept: application/json' \
-H 'Content-Type: application/json' \
-k -s \
-d '{"kubernetes_cluster_name" : "free-k8s-from-percona","kube_auth" : {"kubeconfig" : "'"$KUBECONF_JSON"'"}}'

echo "PMM is ready to roll with DBaaS!"

echo "Now install some extra tools for k8s testing..."

cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch
enabled=1
gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF
sudo yum install -y kubectl

# Verify we can use kubectl with provided config
mkdir ~/.kube
cp /tmp/kubeconfig.yaml ~/.kube/config
kubectl --kubeconfig ~/.kube/config get pods

# Print out the final landing page.
PUBLIC_IP=$(wget -q -O - http://169.254.169.254/latest/meta-data/public-ipv4)
echo "K8s Landing Page: https://$PUBLIC_IP/graph/dbaas/kubernetes"
