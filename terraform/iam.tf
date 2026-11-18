### キャパシティプロバイダーがEC2インスタンスを管理するためのオペレーターロール
### https://docs.aws.amazon.com/lambda/latest/dg/lambda-managed-instances-operator-role.html

data "aws_iam_policy_document" "operator_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    # 他アカウントからの混乱した代理(confused deputy)を防ぐ。
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }
}

resource "aws_iam_role" "operator" {
  name               = "${var.name_prefix}-operator-role"
  assume_role_policy = data.aws_iam_policy_document.operator_trust.json
}

resource "aws_iam_role_policy_attachment" "operator" {
  role       = aws_iam_role.operator.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AWSLambdaManagedEC2ResourceOperator"
}

### GPU関数の実行ロール(ログ出力のみ)

data "aws_iam_policy_document" "function_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "function" {
  name               = "${var.name_prefix}-function-role"
  assume_role_policy = data.aws_iam_policy_document.function_trust.json
}

data "aws_iam_policy_document" "function" {
  statement {
    effect    = "Allow"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.function.arn}:*"]
  }
}

resource "aws_iam_role_policy" "function" {
  name   = "${var.name_prefix}-function-policy"
  role   = aws_iam_role.function.id
  policy = data.aws_iam_policy_document.function.json
}

### CodeBuildのサービスロール

data "aws_iam_policy_document" "codebuild_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }

    # aws_codebuild_project.image.arnを参照すると循環するため、ARNを組み立てて指定する。
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:${data.aws_partition.current.partition}:codebuild:${var.aws_region}:${local.account_id}:project/${var.name_prefix}-image-build"]
    }
  }
}

resource "aws_iam_role" "codebuild" {
  name               = "${var.name_prefix}-codebuild-role"
  assume_role_policy = data.aws_iam_policy_document.codebuild_trust.json
}

data "aws_iam_policy_document" "codebuild" {
  statement {
    sid       = "Logs"
    effect    = "Allow"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.codebuild.arn}:*"]
  }

  statement {
    sid       = "ReadSource"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.source.arn}/source-*.zip"]
  }

  # CodeBuildがS3ソースのバケットを確認するために使う。
  statement {
    sid       = "SourceBucketIdentity"
    effect    = "Allow"
    actions   = ["s3:GetBucketAcl", "s3:GetBucketLocation"]
    resources = [aws_s3_bucket.source.arn]
  }

  # GetAuthorizationTokenはリソースを絞れないAPI。
  statement {
    sid       = "EcrAuth"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "EcrPush"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = [aws_ecr_repository.this.arn]
  }
}

resource "aws_iam_role_policy" "codebuild" {
  name   = "${var.name_prefix}-codebuild-policy"
  role   = aws_iam_role.codebuild.id
  policy = data.aws_iam_policy_document.codebuild.json
}
