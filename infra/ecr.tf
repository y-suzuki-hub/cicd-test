resource "aws_ecr_repository" "app" {
  name = var.name

  # 同じタグの上書きを禁止する。「sha=abc123 のイメージ」が後から別物に変わらないので、
  # ロールバック先が確実に当時のイメージになる。
  image_tag_mutability = "IMMUTABLE"

  # 練習用: terraform destroy 時にイメージが残っていても削除できるようにする
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "keep last 30 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 30
      }
      action = { type = "expire" }
    }]
  })
}
