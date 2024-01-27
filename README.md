# lab-14
otus | ceph

### Домашнее задание
настройка CEPH

#### Цель:
Поднять отказоустойчивый кластер одним из способов, с фактором репликации 2 или выше, для использования rbd, cephfs, s3. 
Подключить клиентов к созданному хранилищу. Отработать сценарии сбоев.

#### Описание/Пошаговая инструкция выполнения домашнего задания:
C помощью terraform и ansible поднять отказоустойчивый кластер одним из способов, с фактором репликации 2 или выше, для использования rbd, cephfs

1. Cделать расчет кластера
2. Просчитать pg для pool'ов из расчета:
   rbd - 5/10 объема дисков
   cephfs - 3/10 объема дисков
   объяснить логику расчёта, создать пулы.
3. Создать и пробросить на клиентские машины:
   3 rbd
   cephfs (общий раздел на каждую машину)
4. Аварии и масштабирование:
   Сгенерировать split-brain, посмотреть поведение кластера, решить проблему (результат - запись консоли с выполнением)
   Сгенерировать сбой ноды с osd, вывести из кластера, добавить новую
   Сгенерировать сбой/обслуживание серверной/дата центра, проверить работоспособность сервисов (результат - запись консоли)
   Расширить кластер на 2+osd, сделать перерасчёт pg, объяснить логику
   Уменьшить кластер на 1+osd, сделать перерасчёт pg, объяснить логику

#### Формат сдачи
terraform манифесты
ansible роль (можно использовать https://github.com/ceph/ceph-ansible.git)
README.md

#### Критерии оценки:
Статус "Принято" ставится при выполнении перечисленных требований.

---

### Выполнение домашнего задания

Стенд будем разворачивать с помощью Terraform на YandexCloud, настройку серверов будем выполнять с помощью Kubernetes.

Необходимые файлы размещены в репозитории GitHub по ссылке:
```
https://github.com/SergSha/lab-14.git
```

Для начала получаем OAUTH токен:
```
https://cloud.yandex.ru/docs/iam/concepts/authorization/oauth-token
```

Настраиваем аутентификации в консоли:
```bash
export YC_TOKEN=$(yc iam create-token)
export TF_VAR_yc_token=$YC_TOKEN
```

Скачиваем проект с гитхаба:
```bash
git clone https://github.com/SergSha/lab-14.git && cd ./lab-14
```

В файле input.auto.tfvars нужно вставить свой 'cloud_id':
```bash
cloud_id  = "..."
```

Kubernetes кластер будем разворачивать с помощью Terraform, а все установки и настройки необходимых приложений будем реализовывать с помощью команд kubectl и helm.

Установка kubectl с помощью встроенного пакетного менеджера:
```bash
# This overwrites any existing configuration in /etc/yum.repos.d/kubernetes.repo
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/repodata/repomd.xml.key
EOF
sudo dnf install -y kubectl
```

Установка helm:
```bash
curl -LO https://get.helm.sh/helm-v3.13.3-linux-amd64.tar.gz
tar -xf ./helm-v3.13.3-linux-amd64.tar.gz
sudo mv ./linux-amd64/helm /usr/local/bin/
rm -rf ./helm-v3.13.3-linux-amd64.tar.gz ./linux-amd64/
```

Для того чтобы развернуть kubernetes кластер, нужно выполнить следующую команду:
```bash
terraform init && terraform apply -auto-approve
```


Saving cluster configuration to /var/lib/ceph/703ee3b2-bc81-11ee-bb01-d00db067b937/config directory
Enabling autotune for osd_memory_target
You can access the Ceph CLI as following in case of multi-cluster or non-default config:

	sudo /usr/sbin/cephadm shell --fsid 703ee3b2-bc81-11ee-bb01-d00db067b937 -c /etc/ceph/ceph.conf -k /etc/ceph/ceph.client.admin.keyring

Or, if you are only running a single cluster on this host:

	sudo /usr/sbin/cephadm shell 

Please consider enabling telemetry to help improve Ceph:

	ceph telemetry on

For more information see:

	https://docs.ceph.com/en/latest/mgr/telemetry/

Bootstrap complete.
[root@mon-01 ~]# 


Create two pools with default settings for use with a file system, you might run the following commands:
```bash
ceph osd pool create cephfs_data
ceph osd pool create cephfs_metadata
```

Once the pools are created, you may enable the file system using the fs new command:
```bash
ceph fs new myfs cephfs_metadata cephfs_data
```
```bash
ceph fs ls
```

Create directory for ceph mount:
```bash
mkdir /mnt/cephfs
```

Get fsid of ceph cluster:
```bash
ceph fsid
df544aea-bd4d-11ee-8e82-d00d13a36aec
```

Mount ceph fs to /mnt/cephfs:
```bash
mount.ceph admin@df544aea-bd4d-11ee-8e82-d00d13a36aec.myfs=/ /mnt/cephfs/
```
or
```bash
mount.ceph admin@.myfs=/ /mnt/cephfs/
```
