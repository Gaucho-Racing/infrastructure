output "instance_id" {
  description = "EC2 instance ID. Useful for SSM/console access."
  value       = aws_instance.this.id
}

output "private_ip" {
  description = "Private IP address. In-cluster pods can connect to this on 1883."
  value       = aws_instance.this.private_ip
}

output "public_ip" {
  description = "EIP-assigned public IP, if associate_public_ip = true; null otherwise. The on-car TCM dials this on 1883."
  value       = try(aws_eip.this[0].public_ip, null)
}

output "public_dns" {
  description = "EC2 public DNS hostname. AWS split-horizon DNS resolves it to the private IP from inside the VPC and the EIP from outside, so pods + the on-car TCM can both use this single name."
  value       = try("ec2-${replace(aws_eip.this[0].public_ip, ".", "-")}.us-west-2.compute.amazonaws.com", null)
}

output "security_group_id" {
  description = "Security group ID. Add ingress rules for any additional callers."
  value       = aws_security_group.this.id
}

output "mqtt_user" {
  description = "Configured MQTT username. Pair with mqtt_password to authenticate."
  value       = var.mqtt_user
}

output "mqtt_password" {
  description = "Generated MQTT password. Read via `terraform output -raw mqtt_password` and put into the k8s Secret + on-car TCM config."
  value       = random_password.mqtt.result
  sensitive   = true
}
