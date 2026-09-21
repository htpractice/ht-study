# Stage kubeadm bootstrap scripts on nodes via file provisioner (+ chmod only).
# Skipped when copy_scripts_via_ssh=false (GitHub Actions — SG allows laptop IP only).

locals {
  scripts_dir = abspath("${path.module}/../../scripts")
  all_scripts_hash = md5(join(",", [
    filemd5("${local.scripts_dir}/prep-node-common.sh"),
    filemd5("${local.scripts_dir}/prep-node-master.sh"),
    filemd5("${local.scripts_dir}/prep-node-worker.sh"),
    filemd5("${local.scripts_dir}/reset-node.sh"),
  ]))
}

resource "null_resource" "copy_scripts_master" {
  for_each = var.copy_scripts_via_ssh ? module.master : {}

  triggers = {
    scripts_hash = local.all_scripts_hash
    instance_id  = each.value.id
  }

  connection {
    type        = "ssh"
    host        = each.value.public_ip
    user        = "ubuntu"
    private_key = tls_private_key.instance_key.private_key_pem
    timeout     = "5m"
  }

  provisioner "file" {
    source      = "${local.scripts_dir}/prep-node-common.sh"
    destination = "/home/ubuntu/prep-node-common.sh"
  }
  provisioner "file" {
    source      = "${local.scripts_dir}/prep-node-master.sh"
    destination = "/home/ubuntu/prep-node-master.sh"
  }
  provisioner "file" {
    source      = "${local.scripts_dir}/reset-node.sh"
    destination = "/home/ubuntu/reset-node.sh"
  }
  provisioner "remote-exec" {
    inline = ["chmod +x /home/ubuntu/prep-node-common.sh /home/ubuntu/prep-node-master.sh /home/ubuntu/reset-node.sh"]
  }
}

resource "null_resource" "copy_scripts_worker" {
  for_each = var.copy_scripts_via_ssh ? module.worker : {}

  triggers = {
    scripts_hash = local.all_scripts_hash
    instance_id  = each.value.id
  }

  connection {
    type        = "ssh"
    host        = each.value.public_ip
    user        = "ubuntu"
    private_key = tls_private_key.instance_key.private_key_pem
    timeout     = "5m"
  }

  provisioner "file" {
    source      = "${local.scripts_dir}/prep-node-common.sh"
    destination = "/home/ubuntu/prep-node-common.sh"
  }
  provisioner "file" {
    source      = "${local.scripts_dir}/prep-node-worker.sh"
    destination = "/home/ubuntu/prep-node-worker.sh"
  }
  provisioner "file" {
    source      = "${local.scripts_dir}/reset-node.sh"
    destination = "/home/ubuntu/reset-node.sh"
  }
  provisioner "remote-exec" {
    inline = ["chmod +x /home/ubuntu/prep-node-common.sh /home/ubuntu/prep-node-worker.sh /home/ubuntu/reset-node.sh"]
  }
}
