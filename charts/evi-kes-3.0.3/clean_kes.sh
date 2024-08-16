#!/bin/bash

# if [ `kubectl get pods -n minio|grep kes-|wc -l` -eq 1 ]; then
#     kubectl delete -f ./templates/kes-k8s.yaml
# fi

# if [ `kubectl get configmap -n minio|grep kes-config|wc -l` -eq 1 ]; then
#     kubectl delete configmap kes-config -n minio
# fi

if [ `kubectl get secret -n minio|grep kes-crts|wc -l` -eq 1 ]; then

    kubectl delete secret kes-crts -n minio
fi

if [ `kubectl get ns|grep minio|wc -l` -eq 1 ]; then
    if [ `kubectl get pods -n minio|grep kes-|wc -l` -eq 1 -o `kubectl get pods -n minio|wc -l` -eq 0 ]; then
        kubectl delete namespace minio
    fi
fi

if [ -d ./pki ]; then
    rm -rf ./pki
fi