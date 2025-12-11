##################################################################################
# 🌉 BRIDGE: TERRAFORM -> ANSIBLE
#
# This file dynamically generates the Ansible Inventory file (`inventory.ini`).
# It takes the IP address of the EC2 instance we just created and writes it
# to the file that Ansible reads. This is how Ansible knows where to connect.
##################################################################################
resource "local_file" "ansible_inventory" {
  content = <<EOF
[pihole_servers]
${aws_instance.pihole.public_ip} ansible_user=ubuntu ansible_ssh_private_key_file=../terraform/pihole_key
EOF

  filename = "${path.module}/../ansible/inventory.ini"
}
