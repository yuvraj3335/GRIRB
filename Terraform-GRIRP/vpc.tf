   # VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "main-vpc"
  }
}

# Internet 
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "main-igw"
  }
}

# Public Subnets
resource "aws_subnet" "public" {
  count                   = 3
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.${count.index}.0/24"
  availability_zone       = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet-${count.index}"
  }
}

# Private Subnets
resource "aws_subnet" "private" {
  count             = 3
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 3}.0/24"
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  tags = {
    Name = "private-subnet-${count.index}"
  }
}

# Route Table for Public Subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = {
    Name = "public-rt"
  }
}

# Associate Public Subnets with Route Table
resource "aws_route_table_association" "public" {
  count          = 3
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

data "aws_availability_zones" "available" {}

# Security Groups
resource "aws_security_group" "alb" {
  vpc_id = aws_vpc.main.id
  name   = "alb-sg"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ecs" {
  vpc_id = aws_vpc.main.id
  name   = "ecs-sg"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "ecs_egress_rds" {
  type                     = "egress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.rds.id
  security_group_id        = aws_security_group.ecs.id
}

resource "aws_security_group_rule" "ecs_egress_msk" {
  type                     = "egress"
  from_port                = 9092
  to_port                  = 9092
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.msk.id
  security_group_id        = aws_security_group.ecs.id
}

resource "aws_security_group" "rds" {
  vpc_id = aws_vpc.main.id
  name   = "rds-sg"

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }
}

resource "aws_security_group" "msk" {
  vpc_id = aws_vpc.main.id
  name   = "msk-sg"

  ingress {
    from_port       = 9092
    to_port         = 9092
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }
}

# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_execution_role" {
  name = "ecs_execution_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "ecs_execution_policy" {
  name   = "ecs_execution_policy"
  role   = aws_iam_role.ecs_execution_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:CreateLogGroup"
        ]
        Resource = "*"
      }
    ]
  })
}

# RDS Instances
resource "aws_db_instance" "incident_db" {
  allocated_storage      = 20
  engine                 = "postgres"
  engine_version         = "13"
  instance_class         = "db.t3.micro"
  db_name                = "incident_db"
  username               = "incident_user"
  password               = "incident_password" # Use Secrets Manager in production
  skip_final_snapshot    = true
  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name
}

resource "aws_db_instance" "task_db" {
  allocated_storage      = 20
  engine                 = "postgres"
  engine_version         = "13"
  instance_class         = "db.t3.micro"
  db_name                = "task_db"
  username               = "task_user"
  password               = "task_password" # Use Secrets Manager in production
  skip_final_snapshot    = true
  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name
}

resource "aws_db_subnet_group" "main" {
  name       = "main"
  subnet_ids = aws_subnet.private[*].id
}

# MSK Cluster
resource "aws_msk_cluster" "main" {
  cluster_name           = "KafkaCluster"
  kafka_version          = "2.8.1"
  number_of_broker_nodes = 3

  broker_node_group_info {
    instance_type   = "kafka.m5.large"
    client_subnets  = aws_subnet.private[*].id
    security_groups = [aws_security_group.msk.id]
  }

  tags = {
    Name = "KafkaCluster"
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "EcsCluster"
}

data "aws_ecr_repository" "incident" {
  name = "incident-service"
}

data "aws_ecr_repository" "task" {
  name = "task-service"
}

# ECS Task Definitions
resource "aws_ecs_task_definition" "incident" {
  family                   = "IncidentTaskDef"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn # Added execution role

  container_definitions = jsonencode([{
    name  = "IncidentContainer"
    image = "${data.aws_ecr_repository.incident.repository_url}:latest"
    essential = true
    portMappings = [{
      containerPort = 8080
      hostPort      = 8080
    }]
    environment = [
      {
        name  = "SPRING_DATASOURCE_URL"
        value = "jdbc:postgresql://${aws_db_instance.incident_db.endpoint}/incident_db"
      },
      {
        name  = "SPRING_KAFKA_BOOTSTRAP_SERVERS"
        value = aws_msk_cluster.main.bootstrap_brokers
      }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/incident"
        "awslogs-region"        = "ap-south-1"
        "awslogs-stream-prefix" = "incident"
      }
    }
  }])
}

resource "aws_ecs_task_definition" "task" {
  family                   = "TaskTaskDef"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn # Added execution role

  container_definitions = jsonencode([{
    name  = "TaskContainer"
    image = "${data.aws_ecr_repository.task.repository_url}:latest"
    essential = true
    portMappings = [{
      containerPort = 8081
      hostPort      = 8081
    }]
    environment = [
      {
        name  = "SPRING_DATASOURCE_URL"
        value = "jdbc:postgresql://${aws_db_instance.task_db.endpoint}/task_db"
      },
      {
        name  = "SPRING_KAFKA_BOOTSTRAP_SERVERS"
        value = aws_msk_cluster.main.bootstrap_brokers
      },
      {
        name  = "SERVER_PORT"
        value = "8081"
      }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/task"
        "awslogs-region"        = "ap-south-1"
        "awslogs-stream-prefix" = "task"
      }
    }
  }])
}

# ECS Services
resource "aws_ecs_service" "incident" {
  name            = "IncidentService"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.incident.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = aws_subnet.private[*].id
    security_groups = [aws_security_group.ecs.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.incident.arn
    container_name   = "IncidentContainer"
    container_port   = 8080
  }

  depends_on = [aws_lb_listener.incident]
}

resource "aws_ecs_service" "task" {
  name            = "TaskService"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.task.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = aws_subnet.private[*].id
    security_groups = [aws_security_group.ecs.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.task.arn
    container_name   = "TaskContainer"
    container_port   = 8081
  }

  depends_on = [aws_lb_listener.task]
}

# Application Load Balancers
resource "aws_lb" "incident" {
  name               = "incident-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id
}

resource "aws_lb_target_group" "incident" {
  name        = "incident-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"
  health_check {
    path = "/actuator/health"
  }
}

resource "aws_lb_listener" "incident" {
  load_balancer_arn = aws_lb.incident.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.incident.arn
  }
}

resource "aws_lb" "task" {
  name               = "task-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id
}

resource "aws_lb_target_group" "task" {
  name        = "task-tg"
  port        = 8081
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"
  health_check {
    path = "/actuator/health"
  }
}

resource "aws_lb_listener" "task" {
  load_balancer_arn = aws_lb.task.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.task.arn
  }
}