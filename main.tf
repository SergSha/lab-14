locals {
  vm_user         = "cloud-user"
  ssh_public_key  = "~/.ssh/id_rsa.pub"
  ssh_private_key = "~/.ssh/id_rsa"
  #vm_name         = "instance"
  vpc_name        = "my_vpc_network"

  folders = {
    "lab-folder" = {}
    #"loadbalancer-folder" = {}
    #"nginx_folder" = {}
    #"backend_folder" = {}
  }

  subnets = {
    "lab-subnet" = {
      v4_cidr_blocks = ["10.10.10.0/24"]
    }
    /*
    "loadbalancer-subnet" = {
      v4_cidr_blocks = ["10.10.10.0/24"]
    }
    "nginx-subnet" = {
      v4_cidr_blocks = ["10.10.20.0/24"]
    }
    "backend-subnet" = {
      v4_cidr_blocks = ["10.10.30.0/24"]
    }
    */
  }

  #subnet_cidrs  = ["10.10.50.0/24"]
  #subnet_name   = "my_vpc_subnet"
  jump_count  = "1"
  osd_count   = "5"
  mds_count   = "1"
  mon_count   = "3"
  disks_count = "3"
  /*
  disk = {
    "web" = {
      "size" = "1"
    }
  }
  */
}

#resource "yandex_resourcemanager_folder" "folders" {
#  for_each = local.folders
#  name     = each.key
#  cloud_id = var.cloud_id
#}

#data "yandex_resourcemanager_folder" "folders" {
#  for_each   = yandex_resourcemanager_folder.folders
#  name       = each.value["name"]
#  depends_on = [yandex_resourcemanager_folder.folders]
#}

resource "yandex_vpc_network" "vpc" {
  #folder_id = yandex_resourcemanager_folder.folders["lab-folder"].id
  name      = local.vpc_name
}

data "yandex_vpc_network" "vpc" {
  #folder_id = yandex_resourcemanager_folder.folders["lab-folder"].id
  name      = yandex_vpc_network.vpc.name
}

#resource "yandex_vpc_subnet" "subnet" {
#  count          = length(local.subnet_cidrs)
#  #folder_id      = yandex_resourcemanager_folder.folders["lab-folder"].id
#  v4_cidr_blocks = local.subnet_cidrs
#  zone           = var.zone
#  name           = "${local.subnet_name}${format("%1d", count.index + 1)}"
#  network_id     = yandex_vpc_network.vpc.id
#}

resource "yandex_vpc_subnet" "subnets" {
  for_each = local.subnets
  name           = each.key
  #folder_id      = yandex_resourcemanager_folder.folders["lab-folder"].id
  v4_cidr_blocks = each.value["v4_cidr_blocks"]
  zone           = var.zone
  network_id     = data.yandex_vpc_network.vpc.id
  route_table_id = yandex_vpc_route_table.rt.id
}

#data "yandex_vpc_subnet" "subnets" {
#  for_each   = yandex_vpc_subnet.subnets
#  name       = each.value["name"]
#  #folder_id      = yandex_resourcemanager_folder.folders["lab-folder"].id
#  depends_on = [yandex_vpc_subnet.subnets]
#}

resource "yandex_vpc_gateway" "nat_gateway" {
  name = "test-gateway"
  #folder_id = yandex_resourcemanager_folder.folders["lab-folder"].id
  shared_egress_gateway {}
}

resource "yandex_vpc_route_table" "rt" {
  name       = "test-route-table"
  #folder_id  = yandex_resourcemanager_folder.folders["lab-folder"].id
  network_id = yandex_vpc_network.vpc.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.nat_gateway.id
    #next_hop_address   = yandex_compute_instance.nat-instance.network_interface.0.ip_address
    #next_hop_address = data.yandex_lb_network_load_balancer.keepalived.internal_address_spec.0.address
  }
}

module "jump" {
  source         = "./modules/instances"
  count          = local.jump_count
  vm_name        = "jump-${format("%02d", count.index + 1)}"
  vpc_name       = local.vpc_name
  #folder_id      = yandex_resourcemanager_folder.folders["lab-folder"].id
  network_interface = {
    for subnet in yandex_vpc_subnet.subnets :
    subnet.name => {
      subnet_id = subnet.id
      nat       = true
    }
    if subnet.name == "lab-subnet"
  }
  #subnet_cidrs   = yandex_vpc_subnet.subnet.v4_cidr_blocks
  #subnet_name    = yandex_vpc_subnet.subnet.name
  #subnet_id      = yandex_vpc_subnet.subnet.id
  vm_user        = local.vm_user
  ssh_public_key = local.ssh_public_key
  secondary_disk = {}
  depends_on     = [yandex_compute_disk.disks]
}

data "yandex_compute_instance" "jump" {
  count      = length(module.jump)
  name       = module.jump[count.index].vm_name
  #folder_id  = yandex_resourcemanager_folder.folders["lab-folder"].id
  depends_on = [module.jump]
}

module "mds" {
  source         = "./modules/instances"
  count          = local.mds_count
  vm_name        = "mds-${format("%02d", count.index + 1)}"
  vpc_name       = local.vpc_name
  #folder_id      = yandex_resourcemanager_folder.folders["lab-folder"].id
  network_interface = {
    for subnet in yandex_vpc_subnet.subnets :
    subnet.name => {
      subnet_id = subnet.id
      #nat       = true
    }
    if subnet.name == "lab-subnet" #|| subnet.name == "backend-subnet"
  }
  #subnet_cidrs   = yandex_vpc_subnet.subnet.v4_cidr_blocks
  #subnet_name    = yandex_vpc_subnet.subnet.name
  #subnet_id      = yandex_vpc_subnet.subnet.id
  vm_user        = local.vm_user
  ssh_public_key = local.ssh_public_key
  secondary_disk = {}
  depends_on = [yandex_compute_disk.disks]
}

data "yandex_compute_instance" "mds" {
  count      = length(module.mds)
  name       = module.mds[count.index].vm_name
  #folder_id  = yandex_resourcemanager_folder.folders["lab-folder"].id
  depends_on = [module.mds]
}

module "mon" {
  source         = "./modules/instances"
  count          = local.mon_count
  vm_name        = "nginx-${format("%02d", count.index + 1)}"
  vpc_name       = local.vpc_name
  #folder_id      = yandex_resourcemanager_folder.folders["lab-folder"].id
  network_interface = {
    for subnet in yandex_vpc_subnet.subnets :
    subnet.name => {
      subnet_id = subnet.id
      #nat       = true
    }
    if subnet.name == "lab-subnet" #|| subnet.name == "nginx-subnet"
  }
  #subnet_cidrs   = yandex_vpc_subnet.subnet.v4_cidr_blocks
  #subnet_name    = yandex_vpc_subnet.subnet.name
  #subnet_id      = yandex_vpc_subnet.subnet.id
  vm_user        = local.vm_user
  ssh_public_key = local.ssh_public_key
  secondary_disk = {}
  depends_on     = [yandex_compute_disk.disks]
}

data "yandex_compute_instance" "mon" {
  count      = length(module.mon)
  name       = module.mon[count.index].vm_name
  #folder_id  = yandex_resourcemanager_folder.folders["lab-folder"].id
  depends_on = [module.mon]
}

module "osd" {
  source         = "./modules/instances"
  count          = local.osd_count
  vm_name        = "osd-${format("%02d", count.index + 1)}"
  vpc_name       = local.vpc_name
  #folder_id      = yandex_resourcemanager_folder.folders["lab-folder"].id
  network_interface = {
    for subnet in yandex_vpc_subnet.subnets :
    subnet.name => {
      subnet_id = subnet.id
      #nat       = true
    }
    if subnet.name == "lab-subnet"
  }
  #subnet_cidrs   = yandex_vpc_subnet.subnet.v4_cidr_blocks
  #subnet_name    = yandex_vpc_subnet.subnet.name
  #subnet_id      = yandex_vpc_subnet.subnet.id
  vm_user        = local.vm_user
  ssh_public_key = local.ssh_public_key
  secondary_disk = {
    #disk_id = yandex_compute_disk.disks[count.index * local.disks_count + secondary_disk.value].id
    #name    = "osd-${format("%02d", floor(count.index / local.disks_count) + 1)}-disk-${format("%02d", count.index % local.disks_count + 1)}"
    
    for disk in yandex_compute_disk.disks :
    disk.name => {
      disk_id = disk.id
      #"auto_delete" = true
      #"mode"        = "READ_WRITE"
    }
    if "${substr(disk.name,0,6)}" == "osd-${format("%02d", count.index + 1)}"
  }
  depends_on     = [yandex_compute_disk.disks]
}

data "yandex_compute_instance" "osd" {
  count      = length(module.osd)
  name       = module.osd[count.index].vm_name
  #folder_id  = yandex_resourcemanager_folder.folders["lab-folder"].id
  depends_on = [module.osd]
}
#resource "yandex_compute_disk" "disks" {
#  for_each  = local.disks
#  name      = each.key
#  #folder_id = yandex_resourcemanager_folder.folders["lab-folder"].id
#  size      = each.value["size"]
#  zone      = var.zone
#}

resource "yandex_compute_disk" "disks" {
  count     = local.osd_count * local.disks_count
  name      = "osd-${format("%02d", floor(count.index / local.disks_count) + 1)}-disk-${format("%02d", count.index % local.disks_count + 1)}"
  #folder_id = yandex_resourcemanager_folder.folders["lab-folder"].id
  size      = "1"
  zone      = var.zone
}

#data "yandex_compute_disk" "disks" {
#  for_each   = yandex_compute_disk.disks
#  name       = each.value["name"]
#  #folder_id  = yandex_resourcemanager_folder.folders["lab-folder"].id
#  depends_on = [yandex_compute_disk.disks]
#}

resource "local_file" "inventory_file" {
  content = templatefile("${path.module}/templates/inventory.tpl",
    {
      jump        = data.yandex_compute_instance.jump
      osd         = data.yandex_compute_instance.osd
      mds         = data.yandex_compute_instance.mds
      mon         = data.yandex_compute_instance.mon
      remote_user = local.vm_user
      domain_name = var.domain_name
    }
  )
  filename = "${path.module}/inventory.ini"
}
/*
resource "yandex_lb_target_group" "webservers" {
  name      = "webservers-group"
  region_id = "ru-central1"
  #folder_id = yandex_resourcemanager_folder.folders["lab-folder"].id

  dynamic "target" {
    for_each = data.yandex_compute_instance.mon[*].network_interface.0.ip_address
    content {
      subnet_id = yandex_vpc_subnet.subnets["lab-subnet"].id
      address   = target.value
    }
  }
}

resource "yandex_lb_target_group" "dashboards" {
  name      = "dashboards-group"
  region_id = "ru-central1"
  #folder_id = yandex_resourcemanager_folder.folders["lab-folder"].id

  dynamic "target" {
    for_each = data.yandex_compute_instance.jump[*].network_interface.0.ip_address
    content {
      subnet_id = yandex_vpc_subnet.subnets["lab-subnet"].id
      address   = target.value
    }
  }
}

resource "yandex_lb_network_load_balancer" "mylb" {
  name = "mylb"
  #folder_id = yandex_resourcemanager_folder.folders["lab-folder"].id

  listener {
    name = "webservers-listener"
    port = 80
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  listener {
    name = "dashboards-listener"
    port = 5601
    external_address_spec {
      ip_version = "ipv4"
    }
  }
  
  attached_target_group {
    target_group_id = yandex_lb_target_group.webservers.id

    healthcheck {
      name = "tcp"
      tcp_options {
        port = 80
      }
    }
  }
  
  attached_target_group {
    target_group_id = yandex_lb_target_group.dashboards.id

    healthcheck {
      name = "tcp"
      tcp_options {
        port = 5601
      }
    }
  }
}

data "yandex_lb_network_load_balancer" "mylb" {
  name = "mylb"
  #folder_id = yandex_resourcemanager_folder.folders["lab-folder"].id
  depends_on = [yandex_lb_network_load_balancer.mylb]
}
*/
/*
resource "null_resource" "mon" {

  count = length(module.mon)

  # Changes to the instance will cause the null_resource to be re-executed
  triggers = {
    name = module.mon[count.index].vm_name
  }

  
  # Running the remote provisioner like this ensures that ssh is up and running
  # before running the local provisioner

  provisioner "remote-exec" {
    inline = ["echo 'Wait until SSH is ready'"]
  }

  connection {
    type        = "ssh"
    user        = local.vm_user
    private_key = file(local.ssh_private_key)
    host        = "${module.mon[count.index].instance_external_ip_address}"
  }

  # Note that the -i flag expects a comma separated list, so the trailing comma is essential!

  provisioner "local-exec" {
    command = "ansible-playbook -u '${local.vm_user}' --private-key '${local.ssh_private_key}' --become -i ./inventory.ini -l '${module.mon[count.index].instance_external_ip_address},' provision.yml"
    #command = "ansible-playbook provision.yml -u '${local.vm_user}' --private-key '${local.ssh_private_key}' --become -i '${element(module.mon.nat_ip_address, 0)},' "
  }
  
}
*/
/*
resource "null_resource" "mds" {

  count = length(module.mds)

  # Changes to the instance will cause the null_resource to be re-executed
  triggers = {
    name = "${module.mds[count.index].vm_name}"
  }

  # Running the remote provisioner like this ensures that ssh is up and running
  # before running the local provisioner

  provisioner "remote-exec" {
    inline = ["echo 'Wait until SSH is ready'"]
  }

  connection {
    type        = "ssh"
    user        = local.vm_user
    private_key = file(local.ssh_private_key)
    host        = "${module.mds[count.index].instance_external_ip_address}"
  }

  # Note that the -i flag expects a comma separated list, so the trailing comma is essential!

  provisioner "local-exec" {
    command = "ansible-playbook -u '${local.vm_user}' --private-key '${local.ssh_private_key}' --become -i '${module.mds[count.index].instance_external_ip_address},' provision.yml"
    #command = "ansible-playbook provision.yml -u '${local.vm_user}' --private-key '${local.ssh_private_key}' --become -i '${element(module.mds.nat_ip_address, 0)},' "
  }
}
*/
