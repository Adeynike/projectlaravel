variable "region" {
  description = "AWS region"
  default     = "us-east-1" # Update with your desired region
}

variable "ami" {
  description = "EC2 instance AMI ID"
  default     = "ami-080e1f13689e07408" # Update with your desired AMI ID
}

variable "instance_type" {
  description = "EC2 instance type"
  default     = "t2.micro" # Update with your desired instance type
}

variable "instance_class" {
  description = "RDS instance type"
  default     = "db.t3.micro" # Update with your desired instance type
}

variable "username" {
  description = "RDS instance username"
  default     = "admin" # Update with your desired username
}

variable "password" {
  description = "RDS instance password"
  default     = "admin12345" # Update with your desired password
}