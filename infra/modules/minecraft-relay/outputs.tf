output "instance_id" {
  description = "EC2 instance ID. Connect with `aws ssm start-session --target <id>`."
  value       = aws_instance.this.id
}

output "public_ip" {
  description = "EIP players and frpc connect to. Point an unproxied mc.gauchoracing.com A record at it."
  value       = aws_eip.this.public_ip
}

output "frp_token" {
  description = "Token frpc authenticates with. Seed into Vault as warden-prod.frp_token."
  value       = random_password.frp_token.result
  sensitive   = true
}
