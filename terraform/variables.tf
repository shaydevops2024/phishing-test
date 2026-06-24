variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "ami_id" {
  description = "AMI for the EC2 instance"
  type        = string
  default     = "ami-0f8a61b66d1accaee"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "key_name" {
  description = "Name of an existing EC2 key pair for SSH access (leave empty to skip)."
  type        = string
  default     = ""
}

variable "ssh_cidr" {
  description = "CIDR allowed to reach SSH (22). Lock this to your office/home IP, e.g. 1.2.3.4/32."
  type        = string
  default     = "0.0.0.0/0"
}

variable "http_cidr" {
  description = "CIDR allowed to reach the phishing-test web app (80)."
  type        = string
  default     = "0.0.0.0/0"
}

variable "project_name" {
  description = "Name tag / prefix for created resources."
  type        = string
  default     = "phishing-test"
}
