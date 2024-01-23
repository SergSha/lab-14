output "jump-servers-info" {
  description = "General information about created VMs"
  value = {
    for vm in data.yandex_compute_instance.jump-servers :
    vm.name => {
      ip_address     = vm.network_interface.*.ip_address
      nat_ip_address = vm.network_interface.*.nat_ip_address
    }
  }
}

output "db-servers-info" {
  description = "General information about created VMs"
  value = {
    for vm in data.yandex_compute_instance.db-servers :
    vm.name => {
      ip_address     = vm.network_interface.*.ip_address
      nat_ip_address = vm.network_interface.*.nat_ip_address
    }
  }
}

output "iscsi-servers-info" {
  description = "General information about created VMs"
  value = {
    for vm in data.yandex_compute_instance.iscsi-servers :
    vm.name => {
      ip_address     = vm.network_interface.*.ip_address
      nat_ip_address = vm.network_interface.*.nat_ip_address
    }
  }
}

output "backend-servers-info" {
  description = "General information about created VMs"
  value = {
    for vm in data.yandex_compute_instance.backend-servers :
    vm.name => {
      ip_address     = vm.network_interface.*.ip_address
      nat_ip_address = vm.network_interface.*.nat_ip_address
    }
  }
}

output "nginx-servers-info" {
  description = "General information about created VMs"
  value = {
    for vm in data.yandex_compute_instance.nginx-servers :
    vm.name => {
      ip_address     = vm.network_interface.*.ip_address
      nat_ip_address = vm.network_interface.*.nat_ip_address
    }
  }
}

output "consul-servers-info" {
  description = "General information about created VMs"
  value = {
    for vm in data.yandex_compute_instance.consul-servers :
    vm.name => {
      ip_address     = vm.network_interface.*.ip_address
      nat_ip_address = vm.network_interface.*.nat_ip_address
    }
  }
}
/*
output "loadbalancer-info" {
  description = "General information about loadbalancer"
  value = data.yandex_lb_network_load_balancer.mylb.*
}
*/
