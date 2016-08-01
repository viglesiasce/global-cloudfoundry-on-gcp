// Subnet for the public Cloud Foundry components
resource "google_compute_subnetwork" "cf-public-subnet-1" {
  name          = "cf-public-${var.region}"
  ip_cidr_range = "10.201.0.0/16"
  network       = "projects/vic-goog/global/networks/cf"
}

// Subnet for the private Cloud Foundry components
resource "google_compute_subnetwork" "cf-private-subnet-1" {
  name          = "cf-private-${var.region}"
  ip_cidr_range = "172.16.0.0/16"
  network       = "projects/vic-goog/global/networks/cf"
}

// Static IP address for forwarding rule
resource "google_compute_address" "cf" {
  name = "cf-${var.region}"
  region = "${var.region}"
}

// Health check
resource "google_compute_http_health_check" "cf-public" {
  name                = "cf-public-${var.region}"
  host                = "api.${google_compute_address.cf.address}.xip.io"
  request_path        = "/info"
  check_interval_sec  = 30
  timeout_sec         = 5
  healthy_threshold   = 10
  unhealthy_threshold = 2
  port = 80
}

// Load balancing target pool
resource "google_compute_target_pool" "cf-public" {
  name = "cf-public-${var.region}"

  health_checks = [
    "${google_compute_http_health_check.cf-public.name}"
  ]
}

// HTTP forwarding rule
resource "google_compute_forwarding_rule" "cf-http" {
  name        = "cf-http-${var.region}"
  target      = "${google_compute_target_pool.cf-public.self_link}"
  port_range  = "80"
  ip_protocol = "TCP"
  ip_address  = "${google_compute_address.cf.address}"
}

// HTTP forwarding rule
resource "google_compute_forwarding_rule" "cf-https" {
  name        = "cf-https-${var.region}"
  target      = "${google_compute_target_pool.cf-public.self_link}"
  port_range  = "443"
  ip_protocol = "TCP"
  ip_address  = "${google_compute_address.cf.address}"
}

// SSH forwarding rule
resource "google_compute_forwarding_rule" "cf-ssh" {
  name        = "cf-ssh-${var.region}"
  target      = "${google_compute_target_pool.cf-public.self_link}"
  port_range  = "2222"
  ip_protocol = "TCP"
  ip_address  = "${google_compute_address.cf.address}"
}

// WSS forwarding rule
resource "google_compute_forwarding_rule" "cf-wss" {
  name        = "cf-wss-${var.region}"
  target      = "${google_compute_target_pool.cf-public.self_link}"
  port_range  = "4443"
  ip_protocol = "TCP"
  ip_address  = "${google_compute_address.cf.address}"
}
