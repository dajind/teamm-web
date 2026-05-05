terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.3.0"
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_security_group" "teampbk_sg" {
  name        = "teampbk-sg"
  description = "Security group for teamPBK web app"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
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

  tags = {
    Name = "teampbk-sg"
    Team = "teamPBK"
  }
}

resource "aws_instance" "teampbk_web" {
  ami                    = "ami-0c7217cdde317cfec" # Ubuntu 24.04 LTS us-east-1
  instance_type          = "t3.micro"
  key_name               = "group1"
  vpc_security_group_ids = [aws_security_group.teampbk_sg.id]
  availability_zone      = "us-east-1b"

  user_data = <<-EOF
    #!/bin/bash
    set -e
    apt-get update -y
    apt-get install -y ca-certificates curl
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
      -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
    echo "deb [arch=$(dpkg --print-architecture) \
      signed-by=/etc/apt/keyrings/docker.asc] \
      https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo $VERSION_CODENAME) stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io
    usermod -aG docker ubuntu
    systemctl enable docker
    systemctl start docker

    docker pull deep2end/teampbk-web:latest
    docker run -d \
      --name teampbk-web \
      --restart unless-stopped \
      -p 80:80 \
      deep2end/teampbk-web:latest

    docker run -d \
      --name watchtower \
      --restart unless-stopped \
      -e DOCKER_API_VERSION=1.41 \
      -v /var/run/docker.sock:/var/run/docker.sock \
      containrrr/watchtower \
      --interval 30 \
      teampbk-web
  EOF

  tags = {
    Name = "teampbk-web"
    Team = "teamPBK"
  }
}

output "public_ip" {
  description = "Публічна IP-адреса інстансу"
  value       = aws_instance.teampbk_web.public_ip
}

output "public_dns" {
  description = "Публічний DNS інстансу"
  value       = aws_instance.teampbk_web.public_dns
}

output "web_url" {
  description = "URL вебзастосунку"
  value       = "http://${aws_instance.teampbk_web.public_ip}"
}
