output "project_name" {
  description = "CodeBuild project name; jobs use runs-on: codebuild-<project_name>-<run_id>-<run_attempt>."
  value       = aws_codebuild_project.runner.name
}

output "security_group_id" {
  description = "Security group of the runner builds; the cluster layer allows it to reach the EKS API."
  value       = aws_security_group.runner.id
}

output "role_arn" {
  description = "CodeBuild service role of the runner."
  value       = aws_iam_role.runner.arn
}
