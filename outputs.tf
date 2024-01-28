output "mon-info" {
  description = "General information about created VMs"
  value = {
    for vm in data.yandex_compute_instance.mon :
    vm.name => {
      ip_address     = vm.network_interface.*.ip_address
      nat_ip_address = vm.network_interface.*.nat_ip_address
    }
  }
}

output "mds-info" {
  description = "General information about created VMs"
  value = {
    for vm in data.yandex_compute_instance.mds :
    vm.name => {
      ip_address     = vm.network_interface.*.ip_address
      nat_ip_address = vm.network_interface.*.nat_ip_address
    }
  }
}

output "osd-info" {
  description = "General information about created VMs"
  value = {
    for vm in data.yandex_compute_instance.osd :
    vm.name => {
      ip_address     = vm.network_interface.*.ip_address
      nat_ip_address = vm.network_interface.*.nat_ip_address
    }
  }
}

output "client-info" {
  description = "General information about created VMs"
  value = {
    for vm in data.yandex_compute_instance.client :
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
