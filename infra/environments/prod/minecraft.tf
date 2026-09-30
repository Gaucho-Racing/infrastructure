# Public relay for the Minecraft server, which runs on gr-foundry
# (kubernetes/gr-foundry/manifests/warden).

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

module "minecraft_relay" {
  source = "../../modules/minecraft-relay"

  name      = "minecraft-relay"
  vpc_id    = data.aws_vpc.default.id
  subnet_id = sort(data.aws_subnets.default.ids)[0]
}
