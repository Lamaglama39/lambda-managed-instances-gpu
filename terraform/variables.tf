variable "aws_region" {
  description = "検証を実施するAWSリージョン"
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "作成するリソース名に付与するプレフィックス"
  type        = string
  default     = "lmi-gpu"
}

variable "vpc_cidr" {
  description = "検証用VPCのCIDR。/24単位でパブリック1つとプライベートをaz_count個切り出す。"
  type        = string
  default     = "10.30.0.0/16"
}

variable "az_count" {
  description = "Managed Instancesを配置するAZの数の上限。GPUインスタンスタイプを提供しているAZから選び、提供AZがこれより少なければ提供AZをすべて使う。"
  type        = number
  default     = 3
}

variable "gpu_instance_type" {
  description = "キャパシティプロバイダーで許可するGPUインスタンスタイプ"
  type        = string
  default     = "g6.xlarge"
}

variable "max_vcpu_count" {
  description = "キャパシティプロバイダー全体のvCPU上限。g6.xlarge(4 vCPU)3台なら12。"
  type        = number
  default     = 12

  # 12未満はインスタンスタイプによらず「below the recommended minimum」で拒否される(2026-11-18に確認)。
  validation {
    condition     = var.max_vcpu_count >= 12
    error_message = "max_vcpu_count must be 12 or greater (Lambda rejects smaller values as below the recommended minimum)."
  }
}

variable "base_image" {
  description = "コンテナイメージのベース。AWS公式のLambdaベースイメージをダイジェストで固定する。"
  type        = string
  default     = "public.ecr.aws/lambda/python:3.13@sha256:f997db32f844709767d5dae2c1767a93797fc88e2f15c4075e3e50866368213d"

  # buildspecがこの値で--build-argを上書きするため、タグだけの指定で固定が外れないようにする。
  validation {
    condition     = can(regex("^public\\.ecr\\.aws/lambda/python:[^@]+@sha256:[0-9a-f]{64}$", var.base_image))
    error_message = "base_image must be an AWS Lambda Python base image pinned by digest (public.ecr.aws/lambda/python:<tag>@sha256:<digest>)."
  }
}

variable "deploy_function" {
  description = "GPU関数を作成するかどうか。関数の作成時にGPUインスタンスが起動するため、GPUクォータの承認後にtrueにする。"
  type        = bool
  default     = false
}

variable "accelerator_memory_size" {
  description = "実行環境ごとに割り当てるGPUメモリ(GiB)。有効値は3, 6, 12, 16, 24, 48。"
  type        = number
  default     = 24

  validation {
    condition     = contains([3, 6, 12, 16, 24, 48], var.accelerator_memory_size)
    error_message = "accelerator_memory_size must be one of 3, 6, 12, 16, 24, 48."
  }
}

variable "function_memory_size" {
  description = "関数のメモリ(MB)。g6.xlarge(4 vCPU / 16 GiB)はOS用に1 vCPU / 1 GBが予約されるため、1台に1実行環境が収まるサイズにする。"
  type        = number
  default     = 8192
}

variable "execution_environment_memory_gib_per_vcpu" {
  description = "実行環境のメモリとvCPUの比率(2, 4, 8)。8192 MBで4なら2 vCPU。"
  type        = number
  default     = 4
}

variable "min_execution_environments" {
  description = "関数の最小実行環境数。既定値はAZ冗長のための3。"
  type        = number
  default     = 3
}

variable "max_execution_environments" {
  description = "関数の最大実行環境数"
  type        = number
  default     = 3
}

variable "tags" {
  description = "全リソースに付与する共通タグ"
  type        = map(string)
  default = {
    Project   = "lambda-managed-instances-gpu-verification"
    ManagedBy = "terraform"
  }
}
