#VPC id
output "project-vpc" {
  value = aws_vpc.project-vpc.id
}

#public subnet 1 id
output "public_subnet_1" {
  value = aws_subnet.public_subnet_1.id
}

#public subnet 2 id
output "public_subnet_2" {
  value = aws_subnet.public_subnet_2.id
}

#private subnet 1 id
output "private_subnet_1" {
  value = aws_subnet.private_subnet_1.id
}

# Instance 1 id
output "server_1" {
  value = aws_instance.server_1.id
}

# Instance 2 id
output "server_2" {
  value = aws_instance.server_2.id
}

# Instance 1 public ip
output "instance_public_ip" {
  value = aws_instance.server_1.public_ip
}

output "alb_hostname" {
  value = "aws_alb.alb.dns_name"
}