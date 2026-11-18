output "availability_zones" {
  description = "Managed Instancesを配置するAZ"
  value       = local.azs
}

output "capacity_provider_arn" {
  description = "キャパシティプロバイダーのARN"
  value       = aws_lambda_capacity_provider.gpu.arn
}

output "image_uri" {
  description = "ビルドしたコンテナイメージ(ダイジェスト指定)"
  value       = "${aws_ecr_repository.this.repository_url}@${data.aws_ecr_image.function.image_digest}"
}

output "function_name" {
  description = "GPU関数の名前"
  value       = var.deploy_function ? local.function_name : null
}

output "invoke_command" {
  description = "GPU関数を呼び出すコマンド例"
  value       = var.deploy_function ? "aws lambda invoke --region ${var.aws_region} --function-name ${local.function_name} --qualifier '$LATEST.PUBLISHED' --cli-binary-format raw-in-base64-out --payload '{\"size\": 4096, \"repeat\": 10}' response.json" : null
}
