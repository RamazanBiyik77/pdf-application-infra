output "blog_database" {
  value = aws_db_instance.apphostdb.endpoint
}

output "bastionhost_ip" {
  value = ["${aws_instance.bastionhost.public_ip}"]
}

output "apphost_ip" {
  value = ["${aws_instance.apphost.private_ip}"]
}