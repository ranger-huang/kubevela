#!/usr/bin/env bash

helm upgrade -i --create-namespace -n vela-system --devel --version 1.2.0-rc.2  kubevela kubevela/vela-core --set multicluster.enabled=true

vela cluster join local-cluster.kubeconfig --name local-cls

cd examples/catalog
ls -al *.cue | while read f;
do
  vela def apply $f -n default
done

# kubectl apply -f app.yaml
# kubectl apply -f app-2.yaml
# kubectl apply -f app-3.yaml
# kubectl apply -f app-4.yaml
