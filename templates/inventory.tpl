
[all]
%{ for jump-server in jump-servers ~}
${ jump-server["name"] } ansible_host=${ jump-server.network_interface[0].ip_address } ip=${ jump-server.network_interface[0].ip_address }
%{ endfor ~}
%{ for db-server in db-servers ~}
${ db-server["name"] } ansible_host=${ db-server.network_interface[0].ip_address } ip=${ db-server.network_interface[0].ip_address }
%{ endfor ~}
%{ for iscsi-server in iscsi-servers ~}
${ iscsi-server["name"] } ansible_host=${ iscsi-server.network_interface[0].ip_address } ip=${ iscsi-server.network_interface[0].ip_address }
%{ endfor ~}
%{ for backend-server in backend-servers ~}
${ backend-server["name"] } ansible_host=${ backend-server.network_interface[0].ip_address } ip=${ backend-server.network_interface[0].ip_address }
%{ endfor ~}
%{ for nginx-server in nginx-servers ~}
${ nginx-server["name"] } ansible_host=${ nginx-server.network_interface[0].ip_address } ip=${ nginx-server.network_interface[0].ip_address } public_ip=${ nginx-server.network_interface[0].nat_ip_address }
%{ endfor ~}
%{ for index, consul-server in consul-servers ~}
${ consul-server["name"] } ansible_host=${ consul-server.network_interface[0].ip_address } ip=${ consul-server.network_interface[0].ip_address }
%{ endfor ~}

[jump_servers]
%{ for jump-server in jump-servers ~}
${ jump-server["name"] }
%{ endfor ~}

[db_servers]
%{ for db-server in db-servers ~}
${ db-server["name"] }
%{ endfor ~}

[iscsi_servers]
%{ for iscsi-server in iscsi-servers ~}
${ iscsi-server["name"] }
%{ endfor ~}

[backend_servers]
%{ for backend-server in backend-servers ~}
${ backend-server["name"] }
%{ endfor ~}

[nginx_servers]
%{ for nginx-server in nginx-servers ~}
${ nginx-server["name"] }
%{ endfor ~}

[consul_servers]
%{ for consul-server in consul-servers ~}
${ consul-server["name"] }
%{ endfor ~}

[all:vars]
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o ProxyJump="${ remote_user }@${ nginx-servers[0].network_interface[0].nat_ip_address }"'
#ansible_ssh_common_args='-o StrictHostKeyChecking=no -o ProxyCommand="ssh -p 22 -W %h:%p -q ${ remote_user }@${ nginx-servers[0].network_interface[0].nat_ip_address }"'

[nginx_servers:vars]
srv_name=balancer
domain=${domain_name}
token=${domain_token}
org=${domain_org}

[backend_servers:vars]
srv_name=wordpress