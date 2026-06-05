output "instance_id" {
  description = "EC2 instance ID. Useful for SSM/console access."
  value       = aws_instance.this.id
}

output "private_ip" {
  description = "Private IP address. In-cluster pods can connect to this on 8123/9000."
  value       = aws_instance.this.private_ip
}

output "public_ip" {
  description = "EIP-assigned public IP, if associate_public_ip = true; null otherwise. External admin clients dial this."
  value       = try(aws_eip.this[0].public_ip, null)
}

output "public_dns" {
  description = "EC2 public DNS hostname. AWS split-horizon DNS resolves it to the private IP from inside the VPC and the EIP from outside, so pods + admins can both use this single name."
  value       = try("ec2-${replace(aws_eip.this[0].public_ip, ".", "-")}.us-west-2.compute.amazonaws.com", null)
}

output "security_group_id" {
  description = "Security group ID. Add ingress rules for any additional callers."
  value       = aws_security_group.this.id
}

output "admin_user" {
  description = "Admin username created on first boot. Pair with admin_password."
  value       = var.admin_user
}

output "admin_password" {
  description = "Generated admin password (32-char random). Read via `terraform output -raw clickhouse_admin_password` and put into the k8s Secret + clickhouse-client config."
  value       = random_password.admin.result
  sensitive   = true
}
