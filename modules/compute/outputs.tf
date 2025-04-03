output "web_security_group_id" {
  description = "ID of the web server security group"
  value       = aws_security_group.web.id
}

output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = aws_security_group.alb.id
}

output "alb_id" {
  description = "ID of the application load balancer"
  value       = aws_lb.web.id
}

output "alb_dns_name" {
  description = "DNS name of the application load balancer"
  value       = aws_lb.web.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the application load balancer"
  value       = aws_lb.web.zone_id
}

output "asg_name" {
  description = "Name of the auto scaling group"
  value       = aws_autoscaling_group.web.name
}

output "launch_template_id" {
  description = "ID of the launch template"
  value       = aws_launch_template.web.id
}

output "iam_role_name" {
  description = "Name of the IAM role for web servers"
  value       = aws_iam_role.web.name
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = aws_lb_target_group.web.arn
}