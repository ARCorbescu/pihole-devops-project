resource "local_file" "ansible_inventory" {
  content = <<EOF
[pihole_servers]
${aws_instance.pihole.public_ip} ansible_user=ubuntu ansible_ssh_private_key_file=../terraform/pihole_key
EOF

  filename = "${path.module}/../ansible/inventory.ini"
}
