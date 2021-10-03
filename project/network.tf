resource "hcloud_load_balancer" "load_balancer" {
  name               = "cluster-lb"
  load_balancer_type = "lb11"
  location           = "nbg1"
}

// create network for all servers
resource "hcloud_network" "cluster-network" {
  name     = "cluster-network"
  ip_range = "10.0.0.0/16"
  labels = {
    "purpose" : "k3s-cluster"
  }
}

resource "hcloud_network_subnet" "cluster-subnet" {
  type         = "cloud"
  network_id   = hcloud_network.cluster-network.id
  network_zone = "eu-central"
  ip_range     = "10.0.0.0/24"
}

resource "hcloud_load_balancer_service" "load_balancer_service" {
  load_balancer_id = hcloud_load_balancer.load_balancer.id
  protocol         = "tcp"
  listen_port      = "6443"
  destination_port = "6443"
}