# ---------------------------------------------------------------
# DNS and the public TLS certificate for this environment.
# The parent zone already exists and is only READ here; everything this
# layer creates lives under var.dns_subdomain.
# ---------------------------------------------------------------
data "aws_route53_zone" "parent" {
  name         = var.parent_domain
  private_zone = false

  lifecycle {
    postcondition {
      condition     = endswith(var.dns_subdomain, ".${trimsuffix(self.name, ".")}")
      error_message = "dns_subdomain must be inside parent_domain."
    }
  }
}

# CAA lists which certificate authorities may issue for a name; CAs use
# the closest record walking up the tree. This record applies only to
# dev.<domain> and below, so the apex policy (Amazon only) is untouched.
resource "aws_route53_record" "caa" {
  zone_id = data.aws_route53_zone.parent.zone_id
  name    = var.dns_subdomain
  type    = "CAA"
  ttl     = 300
  records = [
    "0 issue \"amazon.com\"",      # ACM (ALB certificate)
    "0 issue \"letsencrypt.org\"", # cert-manager
  ]
}

# Public certificate for the ALB. ACM certificates are free and renew
# automatically while in use. The Load Balancer Controller finds it by
# matching the Ingress host name, so apps do not need the ARN.
resource "aws_acm_certificate" "wildcard" {
  domain_name       = "*.${var.dns_subdomain}"
  validation_method = "DNS"

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }

  # ACM checks CAA at issuance.
  depends_on = [aws_route53_record.caa]
}

# Proves domain ownership to ACM with a CNAME record.
resource "aws_route53_record" "acm_validation" {
  for_each = {
    for dvo in aws_acm_certificate.wildcard.domain_validation_options :
    dvo.domain_name => dvo
  }

  zone_id = data.aws_route53_zone.parent.zone_id
  name    = each.value.resource_record_name
  type    = each.value.resource_record_type
  ttl     = 300
  records = [each.value.resource_record_value]
}

# Waits until ACM reports the certificate as ISSUED (usually 1-5 minutes).
resource "aws_acm_certificate_validation" "wildcard" {
  certificate_arn         = aws_acm_certificate.wildcard.arn
  validation_record_fqdns = [for r in aws_route53_record.acm_validation : r.fqdn]
}
