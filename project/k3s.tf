# Create first master node that other masters will join.
# We call this the "root" because it is the first one; but once the others pick up, it will have the exact same configuration and role.
resource "hcloud_server" "cluster_root_master" {
  name        = "cluster-master-0"
  image       = "ubuntu-20.04"
  server_type = "cx11"
  location    = "nbg1"
  user_data   = <<EOF
#cloud-config

runcmd:
  # No firewall here - might interfere with k8s services.
  # Disable SSH password login
  - sed -i -e '/^PasswordAuthentication/s/^.*$/PasswordAuthentication no/' /etc/ssh/sshd_config
  - sed -i -e '/^UsePAM/s/^.*$/UsePAM no/' /etc/ssh/sshd_config
  - systemctl restart sshd
  # Disable root password expiry for TTY-less SSH access
  - chage -d 1 root
  # Setup k3s
  - "curl -sfL https://get.k3s.io | sh -s - server --node-taint CriticalAddonsOnly=true:NoExecute --cluster-init --tls-san '${hcloud_load_balancer.load_balancer.ipv4}'"

ssh_authorized_keys:
  - ssh-rsa ${local.ssh_key}

EOF
  labels      = {
    "purpose" : "k3s-cluster"
    "node-type" : "master"
  }
}

# Wait for master node to start - 60s should be enough.
resource "time_sleep" "wait_for_ready_root_master" {
  depends_on      = [hcloud_server.cluster_root_master]
  create_duration = "60s"
}

# Obtain node token from the first master node once it has started
module "node_token" {
  depends_on = [time_sleep.wait_for_ready_root_master]

  source  = "matti/resource/shell"
  command = "ssh -o 'StrictHostKeyChecking=no' root@${hcloud_server.cluster_root_master.ipv4_address} cat /var/lib/rancher/k3s/server/node-token"
}

# Obtain the kubernetes config to connect to the cluster for later use
module "certificate" {
  depends_on = [time_sleep.wait_for_ready_root_master]

  source  = "matti/resource/shell"
  command = "ssh -o 'StrictHostKeyChecking=no' root@${hcloud_server.cluster_root_master.ipv4_address} cat /etc/rancher/k3s/k3s.yaml"
}


# Create alternate master nodes for HA
resource "hcloud_server" "cluster_alternate_masters" {
  depends_on = [time_sleep.wait_for_ready_root_master]

  count       = 2
  name        = "cluster-master-${count.index+1}"
  image       = "ubuntu-20.04"
  server_type = "cx11"
  location    = "nbg1"
  user_data   = <<EOF
#cloud-config

runcmd:
  # No firewall here - might interfere with k8s services.
  # Disable SSH password login
  - sed -i -e '/^PasswordAuthentication/s/^.*$/PasswordAuthentication no/' /etc/ssh/sshd_config
  - sed -i -e '/^UsePAM/s/^.*$/UsePAM no/' /etc/ssh/sshd_config
  - systemctl restart sshd
  # Disable root password expiry for TTY-less SSH access
  - chage -d 1 root
  # Setup k3s
  - "curl -sfL https://get.k3s.io | K3S_URL='https://${hcloud_load_balancer.load_balancer.ipv4}:6443' K3S_TOKEN='${module.node_token.stdout}' sh -s - server --node-taint CriticalAddonsOnly=true:NoExecute --tls-san='${hcloud_load_balancer.load_balancer.ipv4}'"

ssh_authorized_keys:
  - ssh-rsa ${local.ssh_key}

EOF
  labels      = {
    "purpose" : "k3s-cluster"
    "node-type" : "master"
  }
}

# Sign up root master to load balancer
resource "hcloud_load_balancer_target" "root_master_lb" {
  depends_on = [hcloud_server.cluster_root_master, hcloud_load_balancer.load_balancer]

  type             = "server"
  load_balancer_id = hcloud_load_balancer.load_balancer.id
  server_id        = hcloud_server.cluster_root_master.id
}

resource "hcloud_server_network" "root_master_internal_nw" {
  depends_on = [hcloud_server.cluster_root_master]

  server_id  = hcloud_server.cluster_root_master.id
  network_id = hcloud_network.cluster-network.id
  alias_ips  = []
}


# Sign up alternate masters to load balancer
resource "hcloud_load_balancer_target" "alternate_masters_lb" {
  depends_on = [hcloud_server.cluster_alternate_masters, hcloud_load_balancer.load_balancer]
  for_each   = {for v in hcloud_server.cluster_alternate_masters : v.name => v.id}

  type             = "server"
  load_balancer_id = hcloud_load_balancer.load_balancer.id
  server_id        = each.value
}

resource "hcloud_server_network" "alternate_masters_internal_nw" {
  depends_on = [hcloud_server.cluster_alternate_masters]

  for_each = {for s in hcloud_server.cluster_alternate_masters : s.name => s.id}

  server_id  = each.value
  network_id = hcloud_network.cluster-network.id
  alias_ips  = []
}

# Create cluster workers to connect to the master nodes
resource "hcloud_server" "cluster_workers" {
  depends_on = [
    module.node_token
  ]

  count       = 2
  name        = "cluster-workers-${count.index}"
  image       = "ubuntu-20.04"
  server_type = "cx11"
  location    = "nbg1"
  user_data   = <<EOF
#cloud-config

runcmd:
  # No firewall here - might interfere with k8s services.
  # Disable SSH password login
  - sed -i -e '/^PasswordAuthentication/s/^.*$/PasswordAuthentication no/' /etc/ssh/sshd_config
  - sed -i -e '/^UsePAM/s/^.*$/UsePAM no/' /etc/ssh/sshd_config
  - systemctl restart sshd
  # Disable root password expiry for TTY-less SSH access
  - chage -d 1 root
  # Setup k3s
  - "curl -sfL https://get.k3s.io | K3S_URL='https://${hcloud_load_balancer.load_balancer.ipv4}:6443' K3S_TOKEN='${module.node_token.stdout}' sh -"

ssh_authorized_keys:
  - ssh-rsa ${local.ssh_key}

EOF

  labels = {
    "purpose" : "k3s-cluster"
    "node-type" : "worker"
  }
}

resource "hcloud_server_network" "workers_internal_nw" {
  depends_on = [hcloud_server.cluster_workers]

  for_each = {for s in hcloud_server.cluster_workers : s.name => s.id}

  server_id  = each.value
  network_id = hcloud_network.cluster-network.id
  alias_ips  = []
}