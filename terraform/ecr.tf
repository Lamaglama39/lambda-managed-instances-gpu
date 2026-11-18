resource "aws_ecr_repository" "this" {
  name = "${var.name_prefix}-function"

  # 同じタグで中身を差し替えられないようにする。タグにはソースのハッシュを使う。
  image_tag_mutability = "IMMUTABLE"

  # 検証用のため、イメージが残っていてもdestroyで削除できるようにする。
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep the latest 5 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 5
      }
      action = { type = "expire" }
    }]
  })
}

# このリポジトリを使う関数(バージョン付きARNを含む)にだけイメージの取得を許可する。
# 未設定だと関数作成時にLambdaがリポジトリポリシーを書き換え、Terraformの管理外の差分になる。
data "aws_iam_policy_document" "ecr_lambda_pull" {
  statement {
    sid     = "LambdaECRImageRetrievalPolicy"
    effect  = "Allow"
    actions = ["ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "aws:sourceArn"
      values = [
        "arn:${data.aws_partition.current.partition}:lambda:${var.aws_region}:${local.account_id}:function:${local.function_name}",
        "arn:${data.aws_partition.current.partition}:lambda:${var.aws_region}:${local.account_id}:function:${local.function_name}:*",
      ]
    }
  }
}

resource "aws_ecr_repository_policy" "this" {
  repository = aws_ecr_repository.this.name
  policy     = data.aws_iam_policy_document.ecr_lambda_pull.json
}
