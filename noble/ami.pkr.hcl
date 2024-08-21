## NOTE: The below is for ARM64. For x86:
##       - Change to "x86_64" where appropriate
##       - Change instance type to c5n.large
#
## Order: surrogate.sh -> bootstrap.sh -> setup.sh
#
## DEBUGGING
##
## packer build -debug ami.pkr.pcl
##
##    -> Drops a .pem in $PWD to use to login: ssh -i the.pem ubuntu@a.b.c.d

packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = "~> 1"
    }
  }
}

# Give ability to access AWS services based on invoker's account ACLs
variable "aws_access_key_id" {
  type    = string
  default = "${env("AWS_ACCESS_KEY_ID")}"

  validation {
    condition     = length(var.aws_access_key) > 0
    error_message = "Please source your AWS envariables."
  }
}

variable "aws_secret_access_key" {
  type    = string
  default = "${env("AWS_SECRET_ACCESS_KEY")}"


  validation {
    condition     = length(var.aws_secret_key) > 0
    error_message = "Please source your AWS envariables."
  }
}

variable "aws_region" {
  type    = string
  default = "us-west-2"
}

locals {
  buildtime = "${legacy_isotime("2006-0102-1504")}"
}

data "amazon-ami" "arm" {
  filters = {
    name                = "*ubuntu-noble-24.04-arm64-server-20240815*"
    root-device-type    = "ebs"
    virtualization-type = "hvm"
  }
  most_recent = true
  owners      = ["099720109477"] // Canonical
  region      = "${var.aws_region}"
  access_key  = "${var.aws_access_key_id}"
  secret_key  = "${var.aws_secret_access_key}"
}

source "amazon-ebssurrogate" "arm" {
  ami_description  = "Ubuntu 24.04 + ZFS (web)"
  ami_name         = "aarch64-web-ubuntu-noble-zfs-${local.buildtime}"
  ami_architecture = "arm64"
  ami_virtualization_type     = "hvm"
  ami_root_device {
    delete_on_termination = true
    device_name           = "/dev/xvda"
    source_device_name    = "/dev/xvdf"
    volume_size           = 5
    volume_type           = "gp3"
  }
  associate_public_ip_address = true
  ena_support                 = true
  encrypt_boot                = true
  instance_type               = "c6gn.large"
  launch_block_device_mappings {
    volume_size           = 16
    device_name           = "/dev/xvdf"
    volume_type           = "gp3"
    iops                  = "3000"
    throughput            = "125"
    delete_on_termination = true
  }
  launch_block_device_mappings {
    volume_size           = 3
    device_name           = "/dev/xvdg"
    volume_type           = "gp3"
    iops                  = "3000"
    throughput            = "125"
    delete_on_termination = true
  }
  region = "${var.aws_region}"
  run_tags = {
    Name = "Packer: Ubuntu + ZFS"
  }
  run_volume_tags = {
    Name = "Packer: Ubuntu + ZFS"
  }
  access_key    = "${var.aws_access_key_id}"
  secret_key    = "${var.aws_secret_access_key}"
  source_ami    = "${data.amazon-ami.arm.id}"
  ssh_interface = "public_ip"
  ssh_pty       = true
  ssh_timeout   = "5m"
  ssh_username  = "ubuntu"
  tags = {
    BuildTime = "${local.buildtime}"
    Name      = "Ubuntu 24.04 + ZFS"
  }
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }
}

build {
  sources = ["source.amazon-ebssurrogate.arm"]

  provisioner "file" {
    destination = "/tmp/bootstrap.sh"
    source      = "scripts/bootstrap.sh"
  }

  provisioner "file" {
    destination = "/tmp/setup.sh"
    source      = "scripts/setup.sh"
  }

  provisioner "file" {
    destination = "/tmp/zfs.conf"
    source      = "files/zfs.conf"
  }

  provisioner "shell" {
    environment_vars    = ["AWS_ACCESS_KEY_ID=${var.aws_access_key_id}", "AWS_SECRET_ACCESS_KEY=${var.aws_secret_access_key}", "AWS_DEFAULT_REGION=${var.aws_region}", "CPUARCH=arm64"]
    execute_command     = "sudo -S --preserve-env=SSH_AUTH_SOCK sh -c '{{ .Vars }} {{ .Path }}'"
    script              = "scripts/surrogate.sh"
    skip_clean          = true
    start_retry_timeout = "5m"
  }
}

data "amazon-ami" "intel" {
  filters = {
    name                = "*ubuntu-noble-24.04-arm64-server-20240815*"
    root-device-type    = "ebs"
    virtualization-type = "hvm"
  }
  most_recent = true
  owners      = ["099720109477"] // Canonical
  region      = "${var.aws_region}"
  access_key  = "${var.aws_access_key_id}"
  secret_key  = "${var.aws_secret_access_key}"
}

source "amazon-ebssurrogate" "intel" {
  ami_description  = "Ubuntu 24.04 + ZFS (web)"
  ami_name         = "x86_64-web-ubuntu-noble-zfs-${local.buildtime}"
  ami_architecture = "x86_64"
  ami_virtualization_type     = "hvm"
  ami_root_device {
    delete_on_termination = true
    device_name           = "/dev/xvda"
    source_device_name    = "/dev/xvdf"
    volume_size           = 5
    volume_type           = "gp3"
  }
  associate_public_ip_address = true
  ena_support                 = true
  encrypt_boot                = true
  instance_type               = "c5n.large"
  launch_block_device_mappings {
    volume_size           = 16
    device_name           = "/dev/xvdf"
    volume_type           = "gp3"
    iops                  = "3000"
    throughput            = "125"
    delete_on_termination = true
  }
  launch_block_device_mappings {
    volume_size           = 3
    device_name           = "/dev/xvdg"
    volume_type           = "gp3"
    iops                  = "3000"
    throughput            = "125"
    delete_on_termination = true
  }
  region = "${var.aws_region}"
  run_tags = {
    Name = "Packer: Ubuntu + ZFS"
  }
  run_volume_tags = {
    Name = "Packer: Ubuntu + ZFS"
  }
  access_key    = "${var.aws_access_key_id}"
  secret_key    = "${var.aws_secret_access_key}"
  source_ami    = "${data.amazon-ami.intel.id}"
  ssh_interface = "public_ip"
  ssh_pty       = true
  ssh_timeout   = "5m"
  ssh_username  = "ubuntu"
  tags = {
    BuildTime = "${local.buildtime}"
    Name      = "Ubuntu 24.04 + ZFS"
  }
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }
}

build {
  sources = ["source.amazon-ebssurrogate.intel"]

  provisioner "file" {
    destination = "/tmp/bootstrap.sh"
    source      = "scripts/bootstrap.sh"
  }

  provisioner "file" {
    destination = "/tmp/setup.sh"
    source      = "scripts/setup.sh"
  }

  provisioner "file" {
    destination = "/tmp/zfs.conf"
    source      = "files/zfs.conf"
  }

  provisioner "shell" {
    environment_vars    = ["AWS_ACCESS_KEY_ID=${var.aws_access_key_id}", "AWS_SECRET_ACCESS_KEY=${var.aws_secret_access_key}", "AWS_DEFAULT_REGION=${var.aws_region}", "CPUARCH=amd64"]
    execute_command     = "sudo -S --preserve-env=SSH_AUTH_SOCK sh -c '{{ .Vars }} {{ .Path }}'"
    script              = "scripts/surrogate.sh"
    skip_clean          = true
    start_retry_timeout = "5m"
  }
}
