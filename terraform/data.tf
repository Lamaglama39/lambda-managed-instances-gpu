data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

# GPUインスタンスはすべてのAZで提供されているとは限らない(東京の1dではg5/g6系が未提供)。
# 提供されていないAZのサブネットを含めるとキャパシティプロバイダーの作成に失敗するため、提供AZから選ぶ。
data "aws_ec2_instance_type_offerings" "gpu" {
  location_type = "availability-zone"

  filter {
    name   = "instance-type"
    values = [var.gpu_instance_type]
  }
}

locals {
  account_id = data.aws_caller_identity.current.account_id
  # 東京のg6.xlargeのように提供AZがaz_countより少ない場合は、提供されているAZだけを使う。
  azs           = slice(sort(data.aws_ec2_instance_type_offerings.gpu.locations), 0, min(var.az_count, length(data.aws_ec2_instance_type_offerings.gpu.locations)))
  function_name = "${var.name_prefix}-function"
}
