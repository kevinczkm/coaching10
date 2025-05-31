# 1. S3 bucket for hosting
resource "aws_s3_bucket" "static_bucket" {
  bucket = "vins3-sctp-sandbox.com"
}

#resource "aws_s3_bucket_ownership_controls" "ownership" {
 # bucket = aws_s3_bucket.static_bucket.id
  #rule {
   # object_ownership = "BucketOwnerPreferred"
  #}
#}


resource "aws_s3_bucket_acl" "acl" {
  bucket = aws_s3_bucket.static_bucket.id
  acl    = "private"
  #depends_on = [aws_s3_bucket_ownership_controls.ownership]
}

resource "aws_s3_bucket_public_access_block" "block" {
  bucket = aws_s3_bucket.static_bucket.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

# 2. Upload index.html
resource "aws_s3_object" "index_html" {
  bucket       = aws_s3_bucket.static_bucket.id
  key          = "index.html"
  source       = "./static-website-example/index.html"
  content_type = "text/html"
  etag         = filemd5("./static-website-example/index.html")
}


# 5. ACM Certificate in us-east-1
resource "aws_acm_certificate" "cert" {
  provider          = aws.us_east_1
  domain_name       = "vins3-3105.sctp-sandbox.com"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Environment = "production"
  }
}

# 6. Route53 zone (data)
data "aws_route53_zone" "zone" {
  name = "sctp-sandbox.com"
}

# 7. DNS validation record
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id = data.aws_route53_zone.zone.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
}

# 8. ACM Certificate validation wait
resource "aws_acm_certificate_validation" "cert_validation" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}



# 10. Route53 Record pointing to CloudFront
resource "aws_route53_record" "alias" {
  zone_id = data.aws_route53_zone.zone.zone_id
  name    = "vins3-3105"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.cf.domain_name
    zone_id                = aws_cloudfront_distribution.cf.hosted_zone_id
    evaluate_target_health = false
  }
}
