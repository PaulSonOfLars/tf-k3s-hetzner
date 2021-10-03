resource "local_file" "certificate" {
  filename = "certificate.txt"
  content  = replace(module.certificate.stdout, "127.0.0.1", hcloud_load_balancer.load_balancer.ipv4)
}
resource "local_file" "certificate-err" {
  filename = "certificate-err.txt"
  content  = module.certificate.stderr
}

output certificate {
  value = local_file.certificate.content
}