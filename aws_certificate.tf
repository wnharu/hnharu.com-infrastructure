variable "access_key" {}
variable "secret_key" {}
variable "region" {}

provider "aws" {
    access_key = "${var.access_key}"
    secret_key = "${var.secret_key}"
    region = "${var.region}"
}

data "aws_route53_zone" "selected" {
  name         = "wnharu.com."
  private_zone = false
}

resource "aws_acm_certificate" "cert" {
  domain_name = "wnharu.com"
  subject_alternative_names = [
    "wnharu.com"
  ]
  validation_method = "DNS"
}

resource "aws_route53_record" "cert_validation" {
  name    = "${aws_acm_certificate.cert.domain_validation_options.0.resource_record_name}"
  type    = "${aws_acm_certificate.cert.domain_validation_options.0.resource_record_type}"
  zone_id = "${data.aws_route53_zone.selected.zone_id}"
  records = ["${aws_acm_certificate.cert.domain_validation_options.0.resource_record_value}"]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "cert" {
  certificate_arn         = "${aws_acm_certificate.cert.arn}"
  validation_record_fqdns = ["${aws_route53_record.cert_validation.fqdn}"]
}

output "ip" {
  value = "${aws_acm_certificate_validation.cert.certificate_arn}"
}


resource "aws_cloudfront_distribution" "website-distribution" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  price_class         = "PriceClass_200"

  origin {
    domain_name = "wnharu.github.io"
    origin_id   = "Custom-wnharu.github.io"

    custom_origin_config {
      http_port              = "80"
      https_port             = "443"
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "Custom-wnharu.github.io"
    compress         = true

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  aliases = [
    "wnharu.com"
  ]

  viewer_certificate {
    acm_certificate_arn = "${aws_acm_certificate_validation.cert.certificate_arn}"
    ssl_support_method  = "sni-only"
  }

  tags = {}
}

# # resource "aws_route53_record" "website-cloudfront" {
# #   zone_id = "${var.website_domain["zone_id"]}"
# #   name    = "${var.website_domain["name"]}"
# #   type    = "A"

# #   alias {
# #     name                   = "${aws_cloudfront_distribution.website-distribution.domain_name}"
# #     zone_id                = "${aws_cloudfront_distribution.website-distribution.hosted_zone_id}"
# #     evaluate_target_health = false
# #   }
# # }
