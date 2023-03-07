locals {
  packerstarttime = formatdate("YYYY-MM-DD-hhmm", timestamp())
}

packer {
  required_plugins {
    amazon = {
      version = ">= 0.0.1"
      source = "github.com/hashicorp/amazon"
    }
  }
}

source "amazon-ebs" "RHEL" {
  ami_name  = "a-prd-ec2-shared-services-prd-flexcube-app-golden-image-${local.packerstarttime}"
## setup to share ami images with other accounts
  ami_users = "${var.shared_accounts}"

  region = "${var.region}"
  instance_type = "${var.instance_type}"
  iam_instance_profile = "${var.iam_instance_profile}"
  subnet_id = "${var.subnet_id}"
  kms_key_id = "${var.kms_key_id}"
  encrypt_boot = true
  temporary_security_group_source_cidrs = "${var.temporary_security_group_source_cidrs}"

  source_ami_filter {
    filters = {
      name = "a-ami-packer-general-rhel-8.6-ha-chef-agents-*"
    }
    owners = ["379930732716"]
    most_recent = true
  }

   launch_block_device_mappings {
    device_name = "/dev/sda1"
    volume_size = 350
    volume_type = "gp3"
    delete_on_termination = true
  }

  launch_block_device_mappings {
    device_name = "/dev/sdb"
    volume_size = 400
    volume_type = "gp3"
    delete_on_termination = true
  }

  communicator = "ssh"
  ssh_username = "ec2-user"

  tags = merge({"Name" = "a-prd-ec2-shared-services-prd-flxecube-app-golden-image-${local.packerstarttime}"}, "${var.tags}")
  run_volume_tags = merge({"Name" = "a-prd-ec2-shared-services-prd-flexcube-app-golden-image-${local.packerstarttime}"}, "${var.tags}")

}

build {
  sources = [
    "source.amazon-ebs.RHEL"
  ]

  provisioner "file" {
        source = "./validation.pem"
        destination = "/tmp/validation.pem"
  }

  provisioner "shell" {
	  inline = [ "mkdir -p /tmp/packer-chef-client", "chmod 777 /tmp/packer-chef-client", "sudo mkdir -p /etc/chef", "sudo chmod 777 /etc/chef"]
  }
  
  provisioner "shell" {
    inline = ["sudo cp /tmp/validation.pem /tmp/packer-chef-client/validation.pem", "sudo chmod 400 /tmp/packer-chef-client/validation.pem"]
  }  

  provisioner "shell" {
	      inline = ["sudo cp /tmp/validation.pem /etc/chef/validation.pem", "sudo chmod 400 /etc/chef/validation.pem", "sudo timedatectl set-timezone Europe/Riga"]
  }

  provisioner "shell" {
	  inline = ["sudo yum install -y unzip"]
  }

  provisioner "chef-client" {
	   server_url   = "https://chef.onelum.host/organizations/default"
           guest_os_type = "unix"
           version      ="14.15.6"
           validation_client_name = "packer-e2e-validator"
           policy_group = "flexcube_app-stg"
           policy_name  = "flexcube_app-app"
  }
}

