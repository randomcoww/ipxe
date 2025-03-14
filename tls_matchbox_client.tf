data "terraform_remote_state" "sr" {
  backend = "s3"
  config = {
    bucket                      = "terraform"
    key                         = "state/cluster_resources-0.tfstate"
    region                      = "auto"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
    use_path_style              = true
  }
}

resource "tls_private_key" "matchbox-client" {
  algorithm   = data.terraform_remote_state.sr.outputs.matchbox.ca.algorithm
  ecdsa_curve = "P521"
  rsa_bits    = 2048
}

resource "tls_cert_request" "matchbox-client" {
  private_key_pem = tls_private_key.matchbox-client.private_key_pem

  subject {
    common_name = "matchbox-client"
  }
}

resource "tls_locally_signed_cert" "matchbox-client" {
  cert_request_pem   = tls_cert_request.matchbox-client.cert_request_pem
  ca_private_key_pem = data.terraform_remote_state.sr.outputs.matchbox.ca.private_key_pem
  ca_cert_pem        = data.terraform_remote_state.sr.outputs.matchbox.ca.cert_pem

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}

resource "local_file" "matchbox-ca-cert" {
  content  = data.terraform_remote_state.sr.outputs.matchbox.ca.cert_pem
  filename = "matchbox-ca.pem"
}

resource "local_file" "matchbox-client-cert" {
  content  = tls_locally_signed_cert.matchbox-client.cert_pem
  filename = "matchbox-client-cert.pem"
}

resource "local_file" "matchbox-client-key" {
  content  = tls_private_key.matchbox-client.private_key_pem
  filename = "matchbox-client-key.pem"
}