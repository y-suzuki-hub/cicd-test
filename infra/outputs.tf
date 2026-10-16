output "staging_url" {
  value = "http://${aws_lb.this.dns_name}:8080"
}

output "production_url" {
  value = "http://${aws_lb.this.dns_name}"
}

# GitHub 側に登録する値。そのままターミナルに貼れば gh CLI で登録される。
output "gh_variable_commands" {
  value = <<-EOT
    gh variable set AWS_REGION      --repo ${var.github_repo} --body ${var.region}
    gh variable set ECR_REPOSITORY  --repo ${var.github_repo} --body ${aws_ecr_repository.app.name}
    gh variable set ECS_CLUSTER     --repo ${var.github_repo} --body ${aws_ecs_cluster.this.name}
    gh variable set BUILD_ROLE_ARN  --repo ${var.github_repo} --body ${aws_iam_role.gha["build"].arn}
    gh variable set AWS_ROLE_ARN    --repo ${var.github_repo} --env staging    --body ${aws_iam_role.gha["staging"].arn}
    gh variable set ECS_SERVICE     --repo ${var.github_repo} --env staging    --body ${aws_ecs_service.app["staging"].name}
    gh variable set APP_URL         --repo ${var.github_repo} --env staging    --body http://${aws_lb.this.dns_name}:8080
    gh variable set AWS_ROLE_ARN    --repo ${var.github_repo} --env production --body ${aws_iam_role.gha["production"].arn}
    gh variable set ECS_SERVICE     --repo ${var.github_repo} --env production --body ${aws_ecs_service.app["production"].name}
    gh variable set APP_URL         --repo ${var.github_repo} --env production --body http://${aws_lb.this.dns_name}
  EOT
}
