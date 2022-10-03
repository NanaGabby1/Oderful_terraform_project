
provider "aws" {
  region     = var.region
  access_key = var.access_key
  secret_key = var.secret_key
}

##########################################################
#Creating the VPC
##########################################################
resource "aws_vpc" "project-vpc" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "${var.tag_name_prefix}-vpc"
  }
}

##########################################################
#Creating 2 private and 2 public subnets
#########################################################
resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.project-vpc.id
  cidr_block              = var.public_subnet_1_cidr_block
  availability_zone       = var.availability_zone_1
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.tag_name_prefix}-public_subnet_1"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id            = aws_vpc.project-vpc.id
  cidr_block        = var.public_subnet_2_cidr_block
  availability_zone = var.availability_zone_2

  tags = {
    Name = "${var.tag_name_prefix}-public_subnet_2"
  }
}

#Creating private subnets
resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.project-vpc.id
  cidr_block        = var.private_subnet_1_cidr_block
  availability_zone = var.availability_zone_1

  tags = {
    Name = "${var.tag_name_prefix}-private_subnet_1"
  }
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.project-vpc.id
  cidr_block        = var.private_subnet_2_cidr_block
  availability_zone = var.availability_zone_2

  tags = {
    Name = "${var.tag_name_prefix}-private_subnet_2"
  }
}


#######################################################
#Creating internet gateway
#######################################################
resource "aws_internet_gateway" "internet_GW" {
  vpc_id = aws_vpc.project-vpc.id

  tags = {
    Name = "${var.tag_name_prefix}-internet_gw"
  }
}


#######################################################
#Route tables and association for subnets
#######################################################
#For public subnets
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.project-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_GW.id
  }
  tags = {
    Name = "${var.tag_name_prefix}-public_route_table"
  }
}

# Route table association for public subnet1
resource "aws_route_table_association" "public_subnet_1_association" {
  route_table_id = aws_route_table.public_route_table.id
  subnet_id      = aws_subnet.public_subnet_1.id
}

# Route table association for public subnet2
resource "aws_route_table_association" "public_subnet_2_association" {
  route_table_id = aws_route_table.public_route_table.id
  subnet_id      = aws_subnet.public_subnet_2.id
}


#Route tables for private subnets with respect to NAT
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.project-vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_GW_1.id
  }

  tags = {
    Name = "${var.tag_name_prefix}-private_route_table"
  }
}

#Route table association between private subnets & NAT GW
# Route table association for private subnet 2
resource "aws_route_table_association" "private_subnet_1_association" {
  route_table_id = aws_route_table.private_route_table.id
  subnet_id      = aws_subnet.private_subnet_1.id
}

# Route table association for private subnet2
resource "aws_route_table_association" "private_subnet_2_association" {
  route_table_id = aws_route_table.private_route_table.id
  subnet_id      = aws_subnet.private_subnet_2.id
}


########################################################
#2 EIPS & 2 NAT GW
#######################################################
resource "aws_eip" "eip1_for_nat_gw" {
  vpc        = true
  depends_on = [aws_internet_gateway.internet_GW]

  tags = {
    Name = "${var.tag_name_prefix}-eip1"
  }
}

resource "aws_eip" "eip2_for_nat_gw" {
  vpc        = true
  depends_on = [aws_internet_gateway.internet_GW]

  tags = {
    Name = "${var.tag_name_prefix}-eip2"
  }
}


#2 NAT GW to associate public subnets to EIPs
resource "aws_nat_gateway" "nat_GW_1" {
  subnet_id     = aws_subnet.public_subnet_1.id
  allocation_id = aws_eip.eip1_for_nat_gw.id
  depends_on    = [aws_internet_gateway.internet_GW]


  tags = {
    Name = "${var.tag_name_prefix}-nat_GW_1"
  }
}

resource "aws_nat_gateway" "nat_GW_2" {
  subnet_id     = aws_subnet.public_subnet_2.id
  allocation_id = aws_eip.eip2_for_nat_gw.id
  depends_on    = [aws_internet_gateway.internet_GW]

  tags = {
    Name = "${var.tag_name_prefix}-nat_GW_2"
  }
}



####################################################################
#EC2 Instances
####################################################################
#AMI
data "aws_ami" "ubuntu_linux" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}



resource "aws_instance" "server_1" {
  ami                         = data.aws_ami.ubuntu_linux.id
  instance_type               = "t2.micro"
  key_name                    = var.keypair
  subnet_id                   = aws_subnet.private_subnet_1.id
  availability_zone           = var.availability_zone_1
  vpc_security_group_ids      = [aws_security_group.SG_ecs.id]
  associate_public_ip_address = true
  monitoring                  = true

  tags = {
    Name = "${var.tag_name_prefix}-server_1"
  }

  user_data = file("install_script.sh")
}



resource "aws_instance" "server_2" {
  ami                         = data.aws_ami.ubuntu_linux.id
  instance_type               = "t2.micro"
  key_name                    = var.keypair
  subnet_id                   = aws_subnet.private_subnet_2.id
  availability_zone           = var.availability_zone_2
  vpc_security_group_ids      = [aws_security_group.SG_ecs.id]
  associate_public_ip_address = true
  monitoring                  = true

  tags = {
    Name = "${var.tag_name_prefix}-server_2"
  }

  user_data = file("install_script.sh")
}


#################################################################################
#Security group for ECS/Instances
#################################################################################
resource "aws_security_group" "SG_ecs" {
  name        = "security_group_instances"
  description = "Allow inbound traffic from ALB only"
  vpc_id      = aws_vpc.project-vpc.id

  #Port 80 for HTTP
  ingress {
    description     = "HTTP"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
    security_groups = [aws_security_group.SG_alb.id]
  }

  #Port 443 for HTTPS
  ingress {
    description     = "HTTPS"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
    security_groups = [aws_security_group.SG_alb.id]
  }

  #Port 22 for SSH
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my-ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    name = "${var.tag_name_prefix}-SG_ instances"
  }
}



#################################################################################
#Security group for the external load balancer
#################################################################################
resource "aws_security_group" "SG_alb" {
  name        = "security_group_lb"
  description = "Allow HTTP web and SSH traffic into VPC and allow all egress"
  vpc_id      = aws_vpc.project-vpc.id

  #Port 80 for HTTP
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] #needed to connect to internet download docker files
  }

  #Port 443 for HTTPS
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] #needed to connect to internet download docker files
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    name = "${var.tag_name_prefix}-SG_lb"
  }
}


##############################################################
#External load balancer
##############################################################
resource "aws_lb" "external_lb" {
  name               = "external-lb"
  internal           = false
  ip_address_type    = "ipv4"
  security_groups    = [aws_security_group.SG_alb.id]
  load_balancer_type = "application"
  subnets = [
    "${aws_subnet.public_subnet_1.id}",
    "${aws_subnet.public_subnet_2.id}"
  ]
}

# Target group and listener for external lb to forward incoming traffic on port 80 to ECS
resource "aws_lb_target_group" "test-app_tg" {
  name        = "target-group-for-cluster"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.project-vpc.id
  target_type = "instance"

  health_check {
    healthy_threshold   = "2"
    interval            = "60"
    protocol            = "HTTP"
    matcher             = "200"
    timeout             = "3"
    path                = "/v1/status"
    unhealthy_threshold = "2"
  }
}

#lb listener on port 80
resource "aws_lb_listener" "test-app_listener" {
  load_balancer_arn = aws_lb.external_lb.id
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.test-app_tg.id
    type             = "forward"
  }
}


###########################################################################
#IAM role and policy for ECS
###########################################################################
#ECS IAM role
resource "aws_iam_role" "ecs_task_definition_role" {
  description = "IAM role for the creation of ECS tasks"
  assume_role_policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Principal" : {
            "Service" : [
              "ecs-tasks.amazonaws.com", "ec2.amazonaws.com"
            ]
          },
          "Action" : "sts:AssumeRole"
        }
      ]
    }

  )
}


#ECS IAM role policy
resource "aws_iam_role_policy" "ecs_task_definition_policy" {
  name = "IAM_policy_for_ecs_service"
  role = aws_iam_role.ecs_task_definition_role.id
  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : ["ecs:*","ec2:*"]
          "Resource" : "*"
        }
      ]
  })
}

#ECS IAM policy & role attachment
resource "aws_iam_role_policy_attachment" "ecs_policy_attach" {
  role       = aws_iam_role.ecs_task_definition_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"

}


###########################################################################
#ECS cluster task definition
###########################################################################
resource "aws_ecs_task_definition" "ecs_task_definition" {
  family = "task_definition_for_ESC"
  memory = "1024"
  cpu = "512"
  container_definitions = jsonencode([
    {
      portMappings : [
        {
          "hostPort" : 80,
          "protocol" : "tcp",
          "containerPort" : 4545
        }
      ],
      environment : [
        {
          "name" : "MODE",
          "value" : "real"
        },
        {
          name : "NODE_ENV",
          value : "prod"
        }
      ],
      name : "test-app",
      image : "public.ecr.aws/j3t8a0t2/devops-challenge:latest",
    }
  ])

  task_role_arn = aws_iam_role.ecs_task_definition_role.arn
}



#################################################################
# ECS cluster and Service
#################################################################
#Creating the ECS CLuster with cloud watch log group
resource "aws_ecs_cluster" "test-app_ecs_cluster" {
  name = "test-app_ecs_cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

#CLoudwatch log group
resource "aws_cloudwatch_log_group" "test-app_log_group" {
  name = "log_group_for_test-app_on_cloudwatch"

  tags = {
    Name = "${var.tag_name_prefix}-log_group"
  }
}


#ECS Service
resource "aws_ecs_service" "test-app_ecs_service" {
  name                = "test-app_ecs_service"
  cluster             = aws_ecs_cluster.test-app_ecs_cluster.id
  task_definition     = aws_ecs_task_definition.ecs_task_definition.arn
  launch_type         = "EC2"
  desired_count       = 4
  scheduling_strategy = "REPLICA"


  ordered_placement_strategy {
    type  = "binpack"
    field = "cpu"
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.test-app_tg.arn
    container_name   = "test-app"
    container_port   = 4545
  }
  depends_on = [aws_lb_listener.test-app_listener, aws_iam_role_policy.ecs_task_definition_policy]
}


#################################################################
#IAM role with attached policy for auto scaling
#################################################################
#Service linked IAM_role
resource "aws_iam_role" "AWSServiceRoleForApplicationAutoScaling_ECSService" {
  name = "IAM_role_for_autoscaling"

  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "ecs.application-autoscaling.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
})
}


#IAM policy
resource "aws_iam_policy" "auto_scale_policy" {
  name        = "ECS_IAM_policy"
  description = "Policy allowing auto scaling to call ECS service and cloudwatch"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "ecs:DescribeServices",
          "ecs:UpdateService",
          "cloudwatch:PutMetricAlarm",
          "cloudwatch:DescribeAlarms",
          "cloudwatch:DeleteAlarms"
        ],
        "Resource" : [
          "*"
        ]
      }
    ]
  })
}


####################################################################
#Auto scaling group
#Target with 2 policies
####################################################################
resource "aws_appautoscaling_target" "ecs_target" {
  max_capacity       = 5
  min_capacity       = 4
  resource_id        = "service/test-app_ecs_cluster/test-app_ecs_service"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
  role_arn           = aws_iam_role.AWSServiceRoleForApplicationAutoScaling_ECSService.arn
  depends_on = [aws_ecs_service.test-app_ecs_service]
}

resource "aws_appautoscaling_policy" "CPU_policy" {
  name               = "scale_up_with_CPU"
  policy_type        = "StepScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Maximum"

    step_adjustment {
      metric_interval_lower_bound = 2
      scaling_adjustment          = 1
    }
  }
}

#Cloudwatch alarm to trigger autoscaling
resource "aws_cloudwatch_metric_alarm" "cloudwatch_ASG_alarm" {
  alarm_name          = "tes-app_cpu_alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  period              = "120"
  statistic           = "Maximum"
  threshold           = "80"
  alarm_description   = "This metric monitors ec2 cpu utilization"
  namespace           = "AWS/Logs"
}

