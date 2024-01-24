
[all]
%{ for host in jump ~}
${ host["name"] } ansible_host=${ host.network_interface[0].ip_address } ip=${ host.network_interface[0].ip_address }
%{ endfor ~}
%{ for host in osd ~}
${ host["name"] } ansible_host=${ host.network_interface[0].ip_address } ip=${ host.network_interface[0].ip_address }
%{ endfor ~}
%{ for host in mds ~}
${ host["name"] } ansible_host=${ host.network_interface[0].ip_address } ip=${ host.network_interface[0].ip_address }
%{ endfor ~}
%{ for host in mon ~}
${ host["name"] } ansible_host=${ host.network_interface[0].ip_address } ip=${ host.network_interface[0].ip_address }
%{ endfor ~}

[jump]
%{ for host in jump ~}
${ host["name"] }
%{ endfor ~}

[osd]
%{ for host in osd ~}
${ host["name"] }
%{ endfor ~}

[mds]
%{ for host in mds ~}
${ host["name"] }
%{ endfor ~}

[mon]
%{ for host in mon ~}
${ host["name"] }
%{ endfor ~}

[all:vars]
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o ProxyJump="${ remote_user }@${ jump[0].network_interface[0].nat_ip_address }"'
#ansible_ssh_common_args='-o StrictHostKeyChecking=no -o ProxyCommand="ssh -p 22 -W %h:%p -q ${ remote_user }@${ jump[0].network_interface[0].nat_ip_address }"'
