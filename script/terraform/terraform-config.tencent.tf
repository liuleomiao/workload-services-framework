#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

variable "disk_spec_1" {
  default = {
    disk_count = 1
    disk_size = 200
    disk_format = "ext4"
    disk_type = "CLOUD_SSD"
    disk_iops = 0
  }
}

variable "disk_spec_2" {
  default = {
    disk_count = 1
    disk_size = 200
    disk_format = "ext4"
    disk_type = "CLOUD_SSD"
    disk_iops = 0
  }
}

variable "region" {
  default = null
}

variable "zone" {
  default = "ap-shanghai-3"
}

variable "owner" {
  default = ""
}

variable "spot_instance" {
  default = true
}

variable "custom_tags" {
  default = {}
}

variable "wl_name" {
  default = ""
}

variable "wl_registry_map" {
  default = ""
}

variable "wl_namespace" {
  default = ""
}

variable "worker_profile" {
  default = {
    name = "worker"
    instance_type = "S4.MEDIUM4"
    cpu_model_regex = null
    vm_count = 1

    os_image = null
    os_type = "ubuntu2204"
    os_disk_type = "CLOUD_SSD"
    os_disk_size = 200

    data_disk_spec = null
  }
}

variable "client_profile" {
  default = {
    name = "client"
    instance_type = "S4.MEDIUM4"
    cpu_model_regex = null
    vm_count = 1

    os_image = null
    os_type = "ubuntu2204"
    os_disk_type = "CLOUD_SSD"
    os_disk_size = 200

    data_disk_spec = null
  }
}

variable "controller_profile" {
  default = {
    name = "controller"
    instance_type = "S4.MEDIUM4"
    cpu_model_regex = null
    vm_count = 1

    os_image = null
    os_type = "ubuntu2204"
    os_disk_type = "CLOUD_SSD"
    os_disk_size = 200

    data_disk_spec = null
  }
}

module "wsf" {
  source = "./template/terraform/tencent/main"

  region = var.region
  zone = var.zone
  job_id = var.wl_namespace

  sg_whitelist_cidr_blocks = compact(split("\n",file("proxy-ip-list.txt")))
  ssh_pub_key = file("ssh_access.key.pub")

  common_tags = {
    for k,v in merge(var.custom_tags, {
      owner: var.owner,
      workload: var.wl_name,
    }) : k => substr(replace(lower(v), "/[^a-z0-9_-]/", ""), 0, 63)
  }

  instance_profiles = [
    merge(var.worker_profile, {
      data_disk_spec: null,
    }),
    merge(var.client_profile, {
      data_disk_spec: null,
    }),
    merge(var.controller_profile, {
      data_disk_spec: null,
    }),
  ]

  spot_instance = var.spot_instance
}

output "options" {
  value = {
    wl_name : var.wl_name,
    wl_registry_map : var.wl_registry_map,
    wl_namespace : var.wl_namespace,

    docker_dist_repo: "https://mirrors.aliyun.com/docker-ce",
    docker_registry_mirrors: [
      "https://registry.cn-hangzhou.aliyuncs.com",
    ],
    k8s_repo_key_url: {
      "ubuntu": "http://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg",
    },
    k8s_repo_url: {
      "ubuntu": "http://mirrors.aliyun.com/kubernetes/apt",
    },
    k8s_kubeadm_options: {
      "ClusterConfiguration": {
        "imageRepository": "registry.aliyuncs.com/google_containers",
      },
    },
    containerd_pause_registry: "registry.aliyuncs.com/google_containers",
    k8s_nfd_registry: "docker.io/raspbernetes",
  }
}

output "instances" {
  value = {
    for k,v in module.wsf.instances : k => merge(v, {
      csp = "tencent",
      zone = var.zone,
    })
  }
}

output "terraform_replace" {
  value = lookup(module.wsf, "terraform_replace", null)==null?null:{
    command = replace(module.wsf.terraform_replace.command, "=", "=module.wsf.")
    cpu_model = module.wsf.terraform_replace.cpu_model
  }
}
