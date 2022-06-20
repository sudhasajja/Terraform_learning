provider "aws" {
  region = "eu-central-1"
}

data "aws_vpc" "default" {
  default = true
}
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}
resource "aws_launch_configuration" "as_conf" {
  name                        = "lunch_configuration"
  image_id                    = "ami-09439f09c55136ecf"
  instance_type               = "t2.micro"
  security_groups             = [aws_security_group.instance.id]
  associate_public_ip_address = true
  user_data                   = file("./script.sh")

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "asg" {
  launch_configuration = aws_launch_configuration.as_conf.name
  vpc_zone_identifier  = data.aws_subnets.default.ids
  min_size             = 1
  max_size             = 2
  tag {
    key                 = "Name"
    value               = "terraform-asg-example"
    propagate_at_launch = true
  }
}

resource "aws_lb" "test" {
  name               = "test-lb-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.instance.id]
  subnets            = data.aws_subnets.default.ids

  enable_deletion_protection = true
  tags = {
    Environment = "testing env"
  }
}
resource "aws_lb_target_group" "test_target_group" {
  name     = "tf-example-lb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id
}
resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.test.arn
  port              = "80"
  protocol          = "HTTP"
   default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.test_target_group.arn
  }
}
  
resource "aws_autoscaling_attachment" "asg_attachment_bar" {
  autoscaling_group_name = aws_autoscaling_group.asg.id

  lb_target_group_arn    = aws_lb_target_group.test_target_group.arn
}

resource "aws_security_group" "instance" {

  name = "terraform1-sg"

  ingress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
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

