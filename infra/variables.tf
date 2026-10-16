variable "github_repo" {
  description = "GitHub の owner/repo (例: yourname/cicd-demo)"
  type        = string
}

variable "github_sub_repo" {
  description = "OIDCトークンの sub に出るリポジトリ表記。2026-07-15以降に作ったリポジトリは owner@ownerID/repo@repoID 形式になるので、その場合だけ指定する"
  type        = string
  default     = ""
}

variable "region" {
  type    = string
  default = "ap-northeast-1"
}

variable "name" {
  type    = string
  default = "cicd-demo"
}

variable "create_oidc_provider" {
  description = "このAWSアカウントに GitHub の OIDC プロバイダーがまだ無ければ true。既にあれば false"
  type        = bool
  default     = true
}

locals {
  environments = {
    staging    = { listener_port = 8080 }
    production = { listener_port = 80 }
  }
  container_port = 3000
}
