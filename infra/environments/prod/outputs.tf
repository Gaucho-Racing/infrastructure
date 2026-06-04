output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}

output "acm_certificate_arn" {
  description = "ACM ARN for the *.gauchoracing.com origin cert. Used in Ingress annotations (or picked up automatically by the ALB controller via SAN match)."
  value       = module.origin_cert.acm_certificate_arn
}

output "postgres_private_ip" {
  description = "Private IP of the Postgres EC2. Pods connect to this on 5432."
  value       = module.postgres.private_ip
}

output "postgres_public_ip" {
  description = "Public IP of the Postgres EC2 (EIP). External clients connect to this on 5432, or use gr-postgres.gauchoracing.com."
  value       = module.postgres.public_ip
}

output "postgres_password" {
  description = "Generated postgres user password. Read with `terraform output -raw postgres_password`."
  value       = module.postgres.postgres_password
  sensitive   = true
}

output "mqtt_private_ip" {
  description = "Private IP of the NanoMQ EC2. In-cluster pods can connect to this on 1883."
  value       = module.mqtt.private_ip
}

output "mqtt_public_ip" {
  description = "Public IP of the NanoMQ EC2 (EIP). The on-car TCM publishes here on 1883, or use gr-mqtt.gauchoracing.com."
  value       = module.mqtt.public_ip
}

output "mqtt_password" {
  description = "Generated MQTT password for the in-cluster gr26 user. Read with `terraform output -raw mqtt_password` → mapache-secrets/MQTT_PASSWORD."
  value       = module.mqtt.mqtt_password
  sensitive   = true
}

output "mqtt_password_tcm26" {
  description = "Generated MQTT password for the on-car tcm26 user. Read with `terraform output -raw mqtt_password_tcm26` → on-car TCM mqtt container config."
  value       = module.mqtt.mqtt_password_tcm26
  sensitive   = true
}
