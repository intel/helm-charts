#!/bin/bash

if [ ! -d ./pki ]; then
    bash generate_certificates.sh
fi

if [ `kubectl get ns|grep minio|wc -l` -eq 0 ]; then
    kubectl create namespace minio
fi

if [ `kubectl get secret -n minio|grep kes-crts|wc -l` -eq 0 ]; then

    kubectl create secret generic kes-crts --from-file=pki/private.key --from-file=pki/public.crt --from-file=pki/kes-server.crt --from-file=pki/kes-server.key --from-file=pki/vault-server.crt -n minio
fi

# if [ `kubectl get configmap -n minio|grep kes-config|wc -l` -eq 0 ]; then
#     kubectl create configmap kes-config --from-file=./config/kes-config.yaml -n minio
# fi

# if [ `kubectl get pods -n minio|grep kes-|wc -l` -eq 0 ]; then
#     kubectl apply -f ./templates/kes-k8s.yaml
# fi
