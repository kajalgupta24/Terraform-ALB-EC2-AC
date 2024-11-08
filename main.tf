resource "aws_vpc" "project-1" {
    cidr_block = var.cidr_block
}

resource "aws_subnet" "subnet-1" {
    vpc_id = aws_vpc.project-1.id
    cidr_block = "10.0.0.0/24"
    availability_zone = "ap-south-1a"
    map_public_ip_on_launch = true
}

resource "aws_subnet" "subnet-2" {
    vpc_id = aws_vpc.project-1.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "ap-south-1b"
    map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.project-1.id
}

resource "aws_route_table" "RT" {
    vpc_id = aws_vpc.project-1.id
    
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw.id
    }
}

resource "aws_route_table_association" "RTA-1" {
    subnet_id = aws_subnet.subnet-1.id
    route_table_id = aws_route_table.RT.id
}

resource "aws_route_table_association" "RTA-2" {
    subnet_id = aws_subnet.subnet-2.id
    route_table_id = aws_route_table.RT.id
}

resource "aws_security_group" "mysg" {
    name_prefix = "web-sg"
    vpc_id = aws_vpc.project-1.id
    
    ingress {
        description = "HTTP from VPC"
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"] #everyone can access this port
    }
    ingress {
        description = "SSH"
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        description = "ALL ip"
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
      "Name" = "Web-sg" 
    }
}

resource "aws_s3_bucket" "bucket-1" {
    bucket = "bucket-1-project-sample"
}

resource "aws_instance" "instance-1" {
    ami           = "ami-0c94855ba95c71c99"
    instance_type = "t2.micro"
    vpc_security_group_ids = [aws_security_group.mysg.id]
    subnet_id = aws_subnet.subnet-1.id
    user_data = base64decode(file("user_data.sh"))
}

resource "aws_instance" "instance-2" {
    ami           = "ami-0c94855ba95c71c99"
    instance_type = "t2.micro"
    vpc_security_group_ids = [aws_security_group.mysg.id]
    subnet_id = aws_subnet.subnet-2.id
    user_data = base64decode(file("user_data1.sh"))
}

resource "aws_lb" "myalb" {
    name = "myalb"
    internal = false
    load_balancer_type = "application"
    security_groups = [aws_security_group.mysg.id]
    subnets = [aws_subnet.subnet-1.id, aws_subnet.subnet-2.id]

    tags = {
        Name = "web"
    }
}

resource "aws_lb_target_group" "tg" {
    name     = "tg"
    port     = 80
    protocol = "HTTP"
    vpc_id   = aws_vpc.vpc-1.id

    health_check {
      path = "/"
      port = "traffic-port"
    }
}

resource "aws_lb_target_group_attachment" "attach1" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id = aws_instance.instance-1.id
  port = 80
}

resource "aws_lb_target_group_attachment" "attach2" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id = aws_instance.instance-2.id
  port = 80
}

resource "aws_lb_listener" "listener" {
    load_balancer_arn = aws_lb.myalb.arn
    port = 80
    protocol = "HTTP"

    default_action {
      target_group_arn = aws_lb_target_group.tg.arn
      type             = "forward"
    }
}

output "loadbalancerdns" {
    value = aws_lb.myalb.dns_name
}
