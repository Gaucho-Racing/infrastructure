output "acm_certificate_arn" {
  description = "ARN of the imported certificate in AWS ACM. Reference this on Ingress resources via the alb.ingress.kubernetes.io/certificate-arn annotation."
  value       = aws_acm_certificate.this.arn
}

output "cloudflare_certificate_id" {
  description = "ID of the Cloudflare Origin CA Certificate. Used by Cloudflare to track + revoke."
  value       = cloudflare_origin_ca_certificate.this.id
}
