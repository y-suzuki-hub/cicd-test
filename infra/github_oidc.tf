# GitHub Actions が発行する短命トークン(OIDC)を AWS が信用するための設定。
# 長期のアクセスキーは一切作らない。
resource "aws_iam_openid_connect_provider" "github" {
  count          = var.create_oidc_provider ? 1 : 0
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

data "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 0 : 1
  url   = "https://token.actions.githubusercontent.com"
}

data "aws_caller_identity" "current" {}

locals {
  sub_repo          = var.github_sub_repo != "" ? var.github_sub_repo : var.github_repo
  oidc_provider_arn = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn

  # 役割ごとにロールを分け、「どのリポジトリの・どのブランチ/環境から来たトークンか」(sub) で絞る。
  # environment を指定したジョブのトークンは sub が environment:<名前> になるので、
  # 本番ロールは「production 環境の承認を通ったジョブ」からしか引き受けられない。
  gha_roles = {
    build = {
      sub = "repo:${local.sub_repo}:ref:refs/heads/main"
    }
    staging = {
      sub = "repo:${local.sub_repo}:environment:staging"
    }
    production = {
      sub = "repo:${local.sub_repo}:environment:production"
    }
  }
}

resource "aws_iam_role" "gha" {
  for_each = local.gha_roles

  name                 = "${var.name}-gha-${each.key}"
  max_session_duration = 3600
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = local.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = each.value.sub
        }
      }
    }]
  })
}

# build ロール: ECR へのイメージ push だけ
resource "aws_iam_role_policy" "build" {
  role = aws_iam_role.gha["build"].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:CompleteLayerUpload",
          "ecr:GetDownloadUrlForLayer",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart",
        ]
        Resource = aws_ecr_repository.app.arn
      },
    ]
  })
}

# staging / production ロール: 自分の環境の ECS サービスだけ更新できる
resource "aws_iam_role_policy" "deploy" {
  for_each = local.environments

  role = aws_iam_role.gha[each.key].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # これらの操作はリソース単位で絞れない (AWS側の仕様)
        Effect = "Allow"
        Action = [
          "ecs:RegisterTaskDefinition",
          "ecs:DescribeTaskDefinition",
          "ecs:ListTaskDefinitions",
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["ecs:UpdateService", "ecs:DescribeServices"]
        Resource = aws_ecs_service.app[each.key].id
      },
      {
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = aws_iam_role.execution.arn
        Condition = {
          StringEquals = { "iam:PassedToService" = "ecs-tasks.amazonaws.com" }
        }
      },
    ]
  })
}
