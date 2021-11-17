#!/bin/bash

set -e
set -o pipefail


CMDNAME=`basename $0`

# Display help information
help () {
  echo "Deploy ACS certificate bundles to all OpenShift managed clusters."
  echo ""
  echo "Prerequisites:"
  echo " - kubectl CLI must be pointing to the cluster where ACS Central server is installed"
  echo " - roxctl and yq commands must be installed"
  echo " - ROX_API_TOKEN must be defined as an environment variable"
  echo " - The init bundles and SecuredClusters must be in the stackrox namespace"
  echo ""
  echo "Usage:"
  echo "  $CMDNAME [-i bundle-file] [-c central-namespace]"
  echo ""
  echo "  -h|--help                   Display this menu"
  echo "  -i|--init <bundle-file>     The central init-bundles file name to save certs to."
  echo "                                (Default name is cluster-init-bundle.yaml"
  echo "  -c|--central <namespace>    The central server namespace"
  echo "                                (Default namespace is stackrox"
  echo ""
} >&2



NAMESPACE=stackrox
CENTRALNS=stackrox

# Parse arguments
while [[ $# -gt 0 ]]; do
        key="$1"
        case $key in
            -h|--help)
            help
            exit 0
            ;;
            -i|--init)
            shift
            BUNDLE_FILE=${1}
            shift
            ;;
            -c|--central)
            shift
            CENTRALNS=${1}
            shift
            ;;
            *)    # default
            echo "Invalid input: ${1}" >&2
            exit 1
            shift
            ;;
        esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters


# Wait for central to be ready
attempt_counter=0
max_attempts=30
echo "Waiting for central to be available..."
until $(curl -k --output /dev/null --silent --head --fail https://central); do
    if [ ${attempt_counter} -eq ${max_attempts} ];then
      echo "Max attempts reached"
      exit 1
    fi
    printf '.'
    attempt_counter=$(($attempt_counter+1))
    echo "Made attempt $attempt_counter, waiting 10 seconds..."
    sleep 10
done


ACS_HOST="$(oc get route -n $CENTRALNS central -o custom-columns=HOST:.spec.host --no-headers):443"
if [[ -z "$ACS_HOST" ]]; then
	echo "The ACS route has not been created yet. Deploy Central first." >&2
	exit 1
fi

if [[ -z $BUNDLE_FILE ]]; then
	echo "The '-i|--init <init-bundle>' parameter is required." >&2
	exit 1
fi

if [[ -z "$NAMESPACE" ]]; then
  NAMESPACE=stackrox
fi


if ! [ -x "$(command -v kubectl)" ]; then
    echo 'Error: kubectl is not installed.' >&2
    exit 1
fi

# Base64 command to use.
BASE='base64 -w 0'

if [ -f "${BUNDLE_FILE}" ]; then
	echo "# Using existing bundle file." >&2
else
	echo "# Creating new bundle file." >&2
	roxctl -p "$PASSWORD" -e "$ACS_HOST" central init-bundles generate cluster-init-bundle --output ${BUNDLE_FILE} >&2
	if [ $? -ne 0 ]; then
		echo "Failed to create the init-bundles required with 'roxctl'." >&2
		exit 1
	fi
fi

CACERT=`yq eval '.ca.cert' ${BUNDLE_FILE} | sed 's/^/                    /'`
cat <<EOF >> /manifests/stackrox-ns.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: ${NAMESPACE}

EOF

cat <<EOF >> /manifests/stackrox-staging-ns.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: ${NAMESPACE}-staging

EOF

cat <<EOF >> /manifests/stackrox-channel-ns.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: ${NAMESPACE}-cluster-channel

EOF

cat <<EOF >> /manifests/admission-control-tls-secret.yaml
apiVersion: v1
data:
  admission-control-cert.pem: `yq eval '.admissionControl.serviceTLS.cert' ${BUNDLE_FILE} | ${BASE}`
  admission-control-key.pem: `yq eval '.admissionControl.serviceTLS.key' ${BUNDLE_FILE} | ${BASE}`
  ca.pem: `yq eval '.ca.cert' ${BUNDLE_FILE} | ${BASE}`
kind: Secret
metadata:
  annotations:
    apps.open-cluster-management.io/deployables: "true"
  name: admission-control-tls
  namespace: ${NAMESPACE}-staging
type: Opaque

EOF

cat <<EOF >> /manifests/collector-tls-secret.yaml
apiVersion: v1
data:
  collector-cert.pem: `yq eval '.collector.serviceTLS.cert' ${BUNDLE_FILE} | ${BASE}`
  collector-key.pem: `yq eval '.collector.serviceTLS.key' ${BUNDLE_FILE} | ${BASE}`
  ca.pem: `yq eval '.ca.cert' ${BUNDLE_FILE} | ${BASE}`
kind: Secret
metadata:
  annotations:
    apps.open-cluster-management.io/deployables: "true"
  name: collector-tls
  namespace: ${NAMESPACE}-staging
type: Opaque

EOF

cat <<EOF >> /manifests/sensor-tls-secret.yaml
apiVersion: v1
data:
  sensor-cert.pem: `yq eval '.sensor.serviceTLS.cert' ${BUNDLE_FILE} | ${BASE}`
  sensor-key.pem: `yq eval '.sensor.serviceTLS.key' ${BUNDLE_FILE} | ${BASE}`
  ca.pem: `yq eval '.ca.cert' ${BUNDLE_FILE} | ${BASE}`
  acs-host: `echo ${ACS_HOST} | ${BASE}`
kind: Secret
metadata:
  annotations:
    apps.open-cluster-management.io/deployables: "true"
  name: sensor-tls
  namespace: ${NAMESPACE}-staging
type: Opaque

EOF

cat <<EOF >> /manifests/secured-cluster-channel.yaml
apiVersion: apps.open-cluster-management.io/v1
kind: Channel
metadata:
  name: secured-cluster-resources
  namespace: ${NAMESPACE}-staging
spec:
  pathname: ${NAMESPACE}-staging
  type: Namespace

EOF

cat <<EOF >> /manifests/secured-cluster-subscription.yaml
apiVersion: apps.open-cluster-management.io/v1
kind: Subscription
metadata:
  name: secured-cluster-sub
  namespace: ${NAMESPACE}
spec:
  channel: ${NAMESPACE}-staging/secured-cluster-resources
  placement:
    placementRef:
      kind: PlacementRule
      name: secured-cluster-placement

EOF

cat <<EOF >> /manifests/secured-cluster-placementrule.yaml
apiVersion: apps.open-cluster-management.io/v1
kind: PlacementRule
metadata:
  name: secured-cluster-placement
  namespace: ${NAMESPACE}
spec:
  clusterConditions:
    - status: 'True'
      type: ManagedClusterConditionAvailable
  clusterSelector:
    matchExpressions:
      - key: vendor
        operator: In
        values:
          - OpenShift

EOF

cat <<EOF >> /manifests/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - stackrox-ns.yaml
  - stackrox-staging-ns.yaml
  - stackrox-channel-ns.yaml
  - admission-control-tls-secret.yaml
  - collector-tls-secret.yaml
  - sensor-tls-secret.yaml
  - secured-cluster-channel.yaml
  - secured-cluster-placementrule.yaml
  - secured-cluster-subscription.yaml

EOF

ls -ls /manifests

echo "Apply all resources."
oc apply -k /manifests
