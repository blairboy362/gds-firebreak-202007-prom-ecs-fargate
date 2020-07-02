provider "aws" {
}

module "vpc" {
  source = "btower-labz/btlabz-vpc-ha-3x/aws"

  vpc_name = "drb-test"

  vpc_cidr       = "10.5.0.0/16"
  public_a_cidr  = "10.5.0.0/20"
  public_b_cidr  = "10.5.16.0/20"
  public_c_cidr  = "10.5.32.0/20"
  private_a_cidr = "10.5.48.0/20"
  private_b_cidr = "10.5.64.0/20"
  private_c_cidr = "10.5.80.0/20"

  tags = map(
    "kubernetes.io/cluster/drb-test", "shared",
  )
}

module "prometheus" {
  source = "./modules/prom-ecs-fargate"

  private_subnet_ids = [
    module.vpc.private_a,
    module.vpc.private_b,
    module.vpc.private_c,
  ]

  public_subnet_ids = [
    module.vpc.public_a,
    module.vpc.public_b,
    module.vpc.public_c,
  ]

  vpc_id  = module.vpc.vpc_id
  zone_id = "Z1R5NJUX1TKL6G"
}

output "fqdn" {
  value = module.prometheus.fqdn
}
