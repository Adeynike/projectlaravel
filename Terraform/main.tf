
# Create a VPC
resource "aws_vpc" "cloudgen_vpc" {
  cidr_block = "10.0.0.0/16"
    enable_dns_support   = true
  enable_dns_hostnames = true
}

# Create a public subnet
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.cloudgen_vpc.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "us-east-1a"  # Replace with your desired availability zone
  map_public_ip_on_launch = true
}

resource "aws_subnet" "public_subnet2" {
  vpc_id                  = aws_vpc.cloudgen_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"  # Replace with your desired availability zone
  map_public_ip_on_launch = true
}

resource "aws_subnet" "private_subnet" {
  vpc_id                  = aws_vpc.cloudgen_vpc.id
  cidr_block              = "10.0.4.0/24"
  availability_zone       = "us-east-1a"  # Replace with your desired availability zone
  map_public_ip_on_launch = true
}

resource "aws_subnet" "private_subnet2" {
  vpc_id                  = aws_vpc.cloudgen_vpc.id
  cidr_block              = "10.0.5.0/24"
  availability_zone       = "us-east-1b"  # Replace with your desired availability zone
  map_public_ip_on_launch = true
}

# Create an internet gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.cloudgen_vpc.id
}

# # Attach the internet gateway to the VPC
# resource "aws_internet_gateway_attachment" "attach_gw" {
#   internet_gateway_id = aws_internet_gateway.gw.id
#   vpc_id              = aws_vpc.cloudgen_vpc.id
# }

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.cloudgen_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "Public Route Table"
  }
}  

resource "aws_route_table_association" "public_1_rt_a" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}


# Create a security group for the load balancer
# # Create a security group for the EC2 instances
resource "aws_security_group" "cloudgen_ec2_sg" {
  vpc_id = aws_vpc.cloudgen_vpc.id
  ingress {
    description      = "TLS from VPC"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "TLS from VPC"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }


  ingress {
    description      = "TLS from VPC"
    from_port        = 3306
    to_port          = 3306
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "ssh from ec2"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }


  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_instance" "laravel_instance" {
  ami           = var.ami
  instance_type = var.instance_type
  key_name      = "mykeypair"

  subnet_id                   = aws_subnet.public_subnet.id
  vpc_security_group_ids      = [aws_security_group.cloudgen_ec2_sg.id]
  associate_public_ip_address = true

  user_data = "${file("./userdata.sh")}"

  tags = {
    "Name" : "laravel_webserver"
  }
}

# Create an SQS queue
resource "aws_sqs_queue" "my_queue" {
  name                      = "my-queue"
  delay_seconds             = 0
  max_message_size          = 262144
  message_retention_seconds = 345600  # 4 days
  visibility_timeout_seconds = 30
  receive_wait_time_seconds = 10
  tags = {
    Environment = "Production"
  }
}

# IAM Role for accessing SQS queue
resource "aws_iam_role" "laravelsqs_role" {
  name               = "laravelsqs_role"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "sqs.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
}

# Output the IAM role ARN
output "iam_role_arn" {
  value = aws_iam_role.laravelsqs_role.arn
}

# IAM policy for allowing access to the SQS queue
data "aws_iam_policy_document" "sqs_policy" {
  statement {
    actions   = ["sqs:*"]
    resources = [aws_sqs_queue.my_queue.arn]
    # principals {
    #   type        = "AWS"
    #   identifiers = [aws_iam_role.laravelsqs_role.arn]  # Restrict this to specific IAM roles or users for better security
    # }
  }
}

# IAM policy attachment
resource "aws_iam_policy" "sqs_policy" {
  name   = "sqs_policy"
  policy = data.aws_iam_policy_document.sqs_policy.json
}

# IAM policy attachment to a role (or user)
resource "aws_iam_policy_attachment" "sqs_attachment" {
  name       = "sqs_attachment"
  roles      = [aws_iam_role.laravelsqs_role.name]  # Update with the IAM role name that needs access to the SQS queue
  policy_arn = aws_iam_policy.sqs_policy.arn
}

# Output the SQS queue URL
output "sqs_queue_url" {
  value = aws_sqs_queue.my_queue.id
}


# Create a security group for the load balancer
resource "aws_security_group" "lb_sg" {
  vpc_id = aws_vpc.cloudgen_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
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


# Create an application load balancer
resource "aws_lb" "cloudgen_lb" {
  name               = "cloudgen-load-balancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets            = [aws_subnet.public_subnet.id, aws_subnet.private_subnet2.id]
}

# Create a listener for the ALB
resource "aws_lb_listener" "cloudgen_listener" {
  load_balancer_arn = aws_lb.cloudgen_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "fixed-response"
    fixed_response {
    status_code      = "200"
    content_type     = "text/plain"
    message_body     = "OK"
    }
  }
}

# Create a target group
resource "aws_lb_target_group" "cloudgen_target_group" {
  name     = "cloudgen-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.cloudgen_vpc.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 30
  }
}

# Register targets (EC2 instances) with the target group
resource "aws_lb_target_group_attachment" "cloudgen_target_group_attachment" {
  target_group_arn = aws_lb_target_group.cloudgen_target_group.arn
  target_id        = "i-06656ef348c3c393d" 
}

# Create a listener rule to forward traffic to the target group
resource "aws_lb_listener_rule" "cloudgen_listener_rule" {
  listener_arn = aws_lb_listener.cloudgen_listener.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.cloudgen_target_group.arn
  }

  condition {
    host_header {
      values = ["example.com"]
    }
  }
}


# Create an Auto Scaling Group
resource "aws_autoscaling_group" "laravel_asg" {
  name                 = "laravel-asg"
  max_size             = 3
  min_size             = 1
  desired_capacity     = 1
  health_check_type    = "ELB"
  health_check_grace_period = 300
  vpc_zone_identifier  = [aws_subnet.public_subnet.id, aws_subnet.private_subnet2.id]

  # Define the launch template
  launch_template {
    id      = aws_launch_template.laravel_launch_template.id
    version = "$Latest"
  }

  # Define the target group
  target_group_arns    = [aws_lb_target_group.laravel_target_group.arn]

  # Define tags for the Auto Scaling Group
  tag {
    key                 = "Name"
    value               = "laravel-asg-instance"
    propagate_at_launch = true
  }
}

# Create a launch template
resource "aws_launch_template" "laravel_launch_template" {
  # Specify the configuration for your launch template here
  # For example:
  name_prefix   = "laravel-launch-template"
  image_id      = var.ami
  instance_type = var.instance_type
  # Add any other required configurations
}

# Create a target group
resource "aws_lb_target_group" "laravel_target_group" {
  # Specify the configuration for your target group here
  # For example:
  name     = "laravel-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.cloudgen_vpc.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 30
  }
}


# Create an RDS instance
resource "aws_db_instance" "laravel-rds" {
  identifier              = "laravel"
  allocated_storage       = 20

  engine                  = "mysql"          # Replace with your desired database engine
  engine_version          = "8.0.28"
  #instance_class          = "db.t3.micro"       # Replace with your desired engine version
  instance_class          = var.instance_class   # Replace with your desired instance type
  username                = var.username   # Replace with your desired database username
  password                = var.password   # Replace with your desired database password
  publicly_accessible     = true
  parameter_group_name    = "default.mysql8.0"
  db_subnet_group_name    = aws_db_subnet_group.cloudgen_db_subnet.name
  vpc_security_group_ids  = [aws_security_group.cloudgen_ec2_sg.id]
  skip_final_snapshot     = true
}

# Create a database subnet group
resource "aws_db_subnet_group" "cloudgen_db_subnet" {
  name       = "cloudgen-subnet-groups"
  subnet_ids = [aws_subnet.private_subnet.id, aws_subnet.private_subnet2.id]
}

