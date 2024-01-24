%{ for host in mon ~}
service_type: host
addr: ${ host.network_interface[0].ip_address }
hostname: ${ host["name"] }.${ domain_name }
---
%{ endfor ~}
%{ for host in mds ~}
service_type: host
addr: ${ host.network_interface[0].ip_address }
hostname: ${ host["name"] }.${ domain_name }
---
%{ endfor ~}
%{ for host in osd ~}
service_type: host
addr: ${ host.network_interface[0].ip_address }
hostname: ${ host["name"] }.${ domain_name }
---
%{ endfor ~}
service_type: mon
placement:
  host_pattern: 'mon*'
---
service_type: mgr
placement:
  host_pattern: 'mon*'
---
service_type: mds
service_id: otus_ceph_fs
placement:
  host_pattern: 'mds*'
---
service_type: osd
service_id: default_placement_group
placement:
  host_pattern: 'osd*'
data_devices:
  paths:
  - /dev/vdb
  - /dev/vdc
