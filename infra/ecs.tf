resource "aws_ecs_cluster" "this" {
  name = var.name
}

resource "aws_cloudwatch_log_group" "app" {
  for_each          = local.environments
  name              = "/ecs/${var.name}-${each.key}"
  retention_in_days = 7
}

resource "aws_iam_role" "execution" {
  name = "${var.name}-ecs-execution"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# 最初のタスク定義だけ Terraform が作る。まだ自分のイメージが ECR に無いので、
# 公式 Node イメージで「何にでも200を返す仮サーバー」を立てておく。
# 2回目以降のリビジョンは GitHub Actions が作る。
resource "aws_ecs_task_definition" "app" {
  for_each = local.environments

  family                   = "${var.name}-${each.key}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.execution.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([{
    name      = "app"
    image     = "public.ecr.aws/docker/library/node:24-alpine"
    essential = true
    command   = ["node", "-e", "require('http').createServer((q,s)=>s.end('placeholder')).listen(${local.container_port})"]
    portMappings = [{
      containerPort = local.container_port
      protocol      = "tcp"
    }]
    environment = [{ name = "PORT", value = tostring(local.container_port) }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.app[each.key].name
        awslogs-region        = var.region
        awslogs-stream-prefix = "app"
      }
    }
  }])
}

resource "aws_ecs_service" "app" {
  for_each = local.environments

  name            = each.key
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.app[each.key].arn
  desired_count   = 1
  launch_type     = "FARGATE"

  # 新しいタスクが起動しない・ヘルスチェックに通らない場合、ECS が自動で直前のリビジョンに戻す
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.task.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.env[each.key].arn
    container_name   = "app"
    container_port   = local.container_port
  }

  # 以後のタスク定義は GitHub Actions が更新するので、Terraform が仮サーバーに戻さないようにする
  lifecycle {
    ignore_changes = [task_definition]
  }

  depends_on = [aws_lb_listener.env]
}
