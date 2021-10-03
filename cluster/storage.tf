data "kustomization_overlay" "storage" {
  resources = [
    "https://raw.githubusercontent.com/kubernetes/csi-api/cc087f1/pkg/crd/manifests/csidriver.yaml",
    "https://raw.githubusercontent.com/kubernetes/csi-api/cc087f1/pkg/crd/manifests/csinodeinfo.yaml",
    "https://raw.githubusercontent.com/hetznercloud/csi-driver/master/deploy/kubernetes/hcloud-csi.yml",
  ]
}

resource "kustomization_resource" "storage" {
  for_each = data.kustomization_overlay.storage.ids

  manifest = data.kustomization_overlay.storage.manifests[each.value]
}

resource "kubernetes_storage_class" "override-local-path" {
  metadata {
    name        = "local-path"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" : "false"
      "objectset.rio.cattle.io/id" : ""
      "objectset.rio.cattle.io/owner-gvk" : "k3s.cattle.io/v1, Kind=Addon"
      "objectset.rio.cattle.io/owner-name" : "local-storage"
      "objectset.rio.cattle.io/owner-namespace" : "kube-system"
    }
  }
  storage_provisioner = "rancher.io/local-path"
  reclaim_policy      = "Delete"
  volume_binding_mode = "WaitForFirstConsumer"
}

resource "kubernetes_secret" "hcloud-csi" {
  metadata {
    name      = "hcloud-csi"
    namespace = "kube-system"
  }
  data = {
    "token" = var.hcloud_token
  }
}