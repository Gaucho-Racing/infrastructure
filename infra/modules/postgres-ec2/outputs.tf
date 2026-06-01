output "instance_id" {
  description = "EC2 instance ID. Useful for SSM/console access."
  value       = aws_instance.this.id
}

output "private_ip" {
  description = "Private IP address. Pods connect to this on 5432."
  value       = aws_instance.this.private_ip
}

output "security_group_id" {
  description = "Security group ID of the Postgres instance. Add ingress rules for any additional callers."
  value       = aws_security_group.this.id
}

output "postgres_password" {
  description = "Generated postgres user password. Read via `terraform output -raw postgres_password` and put into the k8s Secret manually."
  value       = random_password.postgres.result
  sensitive   = true
}

output "connection_string_template" {
  description = "Postgres connection string for the application database, password elided. Use with the password output."
  value       = "postgres://postgres:<password>@${aws_instance.this.private_ip}:5432/${var.db_name}?sslmode=disable"
}
