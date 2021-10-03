# tf-k3s-hetzner

Sample implementation of a terraform-generated k3s cluster running on hetzner

*Note*: if you can, always use managed k8s clusters! Digital ocean provide a good offering for this.

*Note*: Terraform is best used with a storage backend for the state, such that teams can cooperate together. This is not
available on hetzner, so ommitted here. Please use DO/AWS/GCP as backends if you intend to use this in prod!

Steps:

Raw cluster:

```sh
# This needs to be set
echo $HCLOUD_TOKEN

cd project
terraform apply
# Say yes when necessary.
# takes 1m30s, Creates:
# 5 servers; 3 master, 2 workers. Quorum over masters happens with etcd. 3 masters provides HA.
# 1 load balancer for access to master.
# 1 private network
# Writes one file to disk with kubernetes creds.

# List all nodes to confirm everything is alive (may take 1-2 minutes)
kubectl --kubeconfig certificate.txt get nodes
```

Monitoring/external storage/cert-manager:

```sh
# This needs to be set
echo $HCLOUD_TOKEN

cd cluster
terraform apply -vars "hcloud_token=$HCLOUD_TOKEN"
# say yes when relevant

# Creates:
# cert-manager for letsencrypt certificates
# prometheus operator
# prometheus x2 for HA
# alertmanager x3 for HA
# grafana for metrics collection (connected to prometheus)
# node-exporter x5 (for each node)
```

### TODO:

- Add autoscaling logic for hcloud
- If a master node goes unhealthy, kill it and start a new one
- prometheus alerts of cluster health
- plug in alertmanager to provide alerts
- determine 0-downtime kubernetes version upgrade path

### Known issues:
- Destruction of project terrafirn can end up stuck because of a hetzner bug in deleting subnetworks.
- Application of cluster terraform can require multiple attempts due to k8s race conditions
- Application of cluster terraform may need imports of certain pre-exisiting items
- There are issues with applying the hcloud-csi drivers. It may be best to kubectl install them instead.