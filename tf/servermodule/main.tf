variable "name" {
  description = "Name of the dedicated server"
}

variable "memory" {
  description = "Memory in GB for the server"
}

variable "cpu" {
  description = "CPU units"
}

variable "long_name" {
  description = "The world facing name of the dedicated server"
}

variable "server_password" {
  description = "The server password that players will have to enter"
}

variable "efs_fs_id" {
  description = "The server password that players will have to enter"
}

locals {
  vpc_id    = "vpc-ddde07bb"
  efs_fs_id = var.efs_fs_id
  subnet_id = "subnet-c88e2a92"
}


resource "aws_cloudwatch_log_group" "lg" {
  name = "${var.name}-logs"
}

data "aws_iam_policy_document" "task_permissions" {
  statement {
    effect = "Allow"

    resources = [
      aws_cloudwatch_log_group.lg.arn,
      "${aws_cloudwatch_log_group.lg.arn}:*"
    ]

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
  }
}

resource "aws_efs_access_point" "saves" {
  file_system_id = local.efs_fs_id

  posix_user {
    gid = 0
    uid = 0
  }

  root_directory {
    path = "/server/${var.name}/saves"
    creation_info {
      owner_gid = 0
      owner_uid = 0
      permissions = "777"
    }
  }

}

resource "aws_efs_access_point" "server" {
  file_system_id = local.efs_fs_id

  posix_user {
    gid = 0
    uid = 0
  }

  root_directory {
    path = "/server/${var.name}/server"
    creation_info {
      owner_gid = 0
      owner_uid = 0
      permissions = "777"
    }
  }
}

resource "aws_efs_access_point" "backup" {
  file_system_id = local.efs_fs_id

  posix_user {
    gid = 0
    uid = 0
  }

  root_directory {
    path = "/server/${var.name}/backup"
    creation_info {
      owner_gid = 0
      owner_uid = 0
      permissions = "777"
    }
  }
}

data "aws_iam_policy_document" "task_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "execution" {
  name               = "${var.name}-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.task_assume.json
}

resource "aws_iam_role" "task" {
  name               = "${var.name}-task-role"
  assume_role_policy = data.aws_iam_policy_document.task_assume.json
}

resource "aws_iam_role_policy" "logs" {
  name = "${var.name}-logs-permission"
  policy = data.aws_iam_policy_document.task_permissions.json
  role = aws_iam_role.task.id
}

variable "world_file" {
  default = "The name of the world file."
}

resource "aws_ecs_task_definition" "taskdef" {
  family = "${var.name}"

  depends_on = [
    aws_efs_access_point.saves,
    aws_efs_access_point.backup,
    aws_efs_access_point.server
  ]

  execution_role_arn = aws_iam_role.task.arn
  task_role_arn      = aws_iam_role.task.arn

  cpu    = var.cpu
  memory = var.memory
  network_mode = "awsvpc"

  container_definitions = jsonencode([
    {
      name      = var.name,
      image     = "mbround18/valheim:latest",
      essential = true,
      memory    = var.memory,
      cpu       = var.cpu,
      networkMode = "awsvpc"
      portMappings = [
        {
          containerPort = 2456,
          hostPort      = 2456,
          protocol      = "udp"
        },
        {
          containerPort = 2457,
          hostPort      = 2457,
          protocol      = "udp"
        },
        {
          containerPort = 2458,
          hostPort      = 2458,
          protocol      = "udp"
        }
      ],
      environment = [
        { name = "PORT", value = "2456" },
        { name = "NAME", value = var.name },
        { name = "WORLD", value = var.world_file },
        { name = "PASSWORD", value = var.server_password },
        { name = "TZ", value = "America/Los_Angeles" },
        { name = "PUBLIC", value = "0" },
        { name = "AUTO_UPDATE", value = "1" },
        { name = "AUTO_UPDATE_SCHEDULE", value = "0 5 * * *" },
        { name = "AUTO_BACKUP", value = "1" },
        { name = "AUTO_BACKUP_SCHEDULE", value = "30 * * * *" },
        { name = "AUTO_BACKUP_REMOVE_OLD", value = "1" },
        { name = "AUTO_BACKUP_DAYS_TO_LIVE", value = "30" },
        { name = "AUTO_BACKUP_ON_UPDATE", value = "1" },
        { name = "AUTO_BACKUP_ON_SHUTDOWN", value = "1" },
        { name = "foo", value = "1" }
      ],
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = aws_cloudwatch_log_group.lg.name,
          awslogs-region        = "us-west-1",
          awslogs-stream-prefix = var.name
        }
      },
      mountPoints = [
        {
          sourceVolume  = "saves",
          containerPath = "/home/steam/.config/unity3d/IronGate/Valheim"
        },
        {
          sourceVolume  = "server",
          containerPath = "/home/steam/valheim"
        },
        {
          sourceVolume  = "backups",
          containerPath = "/home/steam/backups"
        }
      ],
      requiresCompatibilities = ["FARGATE"]
    }
  ])

  volume {
    name = "saves"

    efs_volume_configuration {
      file_system_id = local.efs_fs_id
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = aws_efs_access_point.saves.id
      }
    }
  }

  volume {
    name = "server"

    efs_volume_configuration {
      file_system_id = local.efs_fs_id
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = aws_efs_access_point.server.id
      }
    }
  }

  volume {
    name = "backups"

    efs_volume_configuration {
      file_system_id = local.efs_fs_id
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = aws_efs_access_point.backup.id
      }
    }
  }

  requires_compatibilities = ["FARGATE"]
}

resource "aws_security_group" "allow_valheim_inbound" {
  name        = "allow_valheim_access_${var.name}"
  description = "allows inbound access to the ports required by valheim"
  vpc_id      = local.vpc_id

  ingress {
    protocol    = "udp"
    from_port   = 2456
    to_port     = 2458
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_ecs_service" "service" {
  name            = "${var.name}-service"
  cluster         = "valheim"
  task_definition = "${aws_ecs_task_definition.taskdef.family}:${max(aws_ecs_task_definition.taskdef.revision, 1)}"
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    assign_public_ip = true
    subnets          = [local.subnet_id]
    security_groups  = [aws_security_group.allow_valheim_inbound.id]
  }

  lifecycle {
    create_before_destroy = true
  }

}