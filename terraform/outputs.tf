output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.phishing_test.id
}

output "public_ip" {
  description = "Public IP of the instance"
  value       = aws_instance.phishing_test.public_ip
}

output "public_dns" {
  description = "Public DNS of the instance"
  value       = aws_instance.phishing_test.public_dns
}

output "app_url" {
  description = "URL of the phishing-test landing page"
  value       = "http://${aws_instance.phishing_test.public_ip}/"
}

output "ssh_command" {
  description = "SSH into the instance (Ubuntu AMI)"
  value       = "ssh ubuntu@${aws_instance.phishing_test.public_ip}"
}
