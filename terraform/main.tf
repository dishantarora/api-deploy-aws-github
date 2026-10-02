module "api" {
  source = "./modules/api"

  environment_name  = var.environment_name
  aws_partition     = data.aws_partition.current.partition
  lambda_source_dir = "${path.root}/../src"
}
