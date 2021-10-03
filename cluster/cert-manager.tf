data "kustomization_build" "cert-manager" {
  path = "kustomizations/cert-manager"
}

resource "kustomization_resource" "cert-manager" {
  for_each = data.kustomization_build.cert-manager.ids

  manifest = data.kustomization_build.cert-manager.manifests[each.value]
}
