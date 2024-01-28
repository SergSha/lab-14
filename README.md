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



Просчитать pg для pool'ов:
rbd - 5/10 объема дисков 
cephfs - 3/10 объема дисков 
объяснить логику расчёта, создать пулы.

Формула для расчета: 
Total PGs = (total_number_of_OSD * %_usage) / max_replication_count

Получаем для 6 osd с дисками по 10 Гб:

Для RBD: 
```
total PGs = (6 * 5/10 * 100) / 3 = 100 => 128 pg
```

Создаем пул: 
```bash
ceph osd pool create myrbd 128
ceph osd pool application enable myrbd rbd
```
```
[root@mon-01 ~]# ceph osd pool create myrbd 128
pool 'myrbd' created
[root@mon-01 ~]# ceph osd pool application enable myrbd rbd
enabled application 'rbd' on pool 'myrbd'
[root@mon-01 ~]# 

```

Для cephfs: 
```
total PGs = (6 * 3/10 * 100) / 3 = 60 => 64 pg
```

Создаем пул для данных: 
```bash
ceph osd pool create cephfs_data 64
```
```
[root@mon-01 ~]# ceph osd pool create cephfs_data 64
pool 'cephfs_data' created
[root@mon-01 ~]# 
```

и для метаданных: 
```bash
ceph osd pool create cephfs_meta
```
```
[root@mon-01 ~]# ceph osd pool create cephfs_meta
pool 'cephfs_meta' created
[root@mon-01 ~]# 
```

Создать и пробросить на клиентские машины
3 rbd 
cephfs (общий раздел на каждую машину)

#### RBD

Создаем 3 rbd диска:
```bash
rbd create disk1 --size 5G --pool myrbd
rbd create disk2 --size 10G --pool myrbd
rbd create disk3 --size 15G --pool myrbd
```
```
[root@mon-01 ~]# rbd create disk1 --size 5G --pool myrbd
[root@mon-01 ~]# rbd create disk2 --size 10G --pool myrbd
[root@mon-01 ~]# rbd create disk3 --size 15G --pool myrbd
[root@mon-01 ~]# rbd ls --pool myrbd
disk1
disk2
disk3
[root@mon-01 ~]# 
```

Скопируем ceph конфиг файл /etc/ceph/ceph.conf на клиентскую машину:
```
[root@client-01 ~]# vi /etc/ceph/ceph.conf
# minimal ceph.conf for 0941ec88-bdfb-11ee-8c1c-d00dd111fe9b
[global]
	fsid = 0941ec88-bdfb-11ee-8c1c-d00dd111fe9b
	mon_host = [v2:10.10.10.28:3300/0,v1:10.10.10.28:6789/0] [v2:10.10.10.27:3300/0,v1:10.10.10.27:6789/0] [v2:10.10.10.14:3300/0,v1:10.10.10.14:6789/0]
```

Также скопируем ключ клиента /etc/ceph/ceph.client.admin.keyring:
```
vi /etc/ceph/ceph.client.admin.keyring
[client.admin]
        key = AQCBgrZl77pDHBAAU0DzqH7rSnwSYVeExWscUA==
        caps mds = "allow *"
        caps mgr = "allow *"
        caps mon = "allow *"
        caps osd = "allow *"
```

Подключим блочное устройство disk3 к клиенту:
```bash
rbd device map myrbd/disk3
```
```
[root@client-01 ~]# rbd device map myrbd/disk3 
/dev/rbd0
[root@client-01 ~]# rbd showmapped
id  pool   namespace  image  snap  device   
0   myrbd             disk3  -     /dev/rbd0
[root@client-01 ~]# 
```

Создадим файловую систему и смонтируем устройство:
```bash
mkfs.xfs /dev/rbd/myrbd/disk3
```
```
[root@client-01 ~]# mkfs.xfs /dev/rbd/myrbd/disk3
meta-data=/dev/rbd/myrbd/disk3   isize=512    agcount=16, agsize=245760 blks
         =                       sectsz=512   attr=2, projid32bit=1
         =                       crc=1        finobt=1, sparse=1, rmapbt=0
         =                       reflink=1    bigtime=1 inobtcount=1 nrext64=0
data     =                       bsize=4096   blocks=3932160, imaxpct=25
         =                       sunit=16     swidth=16 blks
naming   =version 2              bsize=4096   ascii-ci=0, ftype=1
log      =internal log           bsize=4096   blocks=16384, version=2
         =                       sectsz=512   sunit=16 blks, lazy-count=1
realtime =none                   extsz=4096   blocks=0, rtextents=0
Discarding blocks...Done.
[root@client-01 ~]# 
```

Создадим директорий для монтирования:
```bash
mkdir /mnt/ceph_rbd
```
```
[root@client-01 ~]# mkdir /mnt/ceph_rbd
[root@client-01 ~]# 
```
Смонтируем файловую систему:
```bash
mount -t xfs /dev/rbd/myrbd/disk3 /mnt/ceph_rbd/
```
```
[root@client-01 ~]# mount -t xfs /dev/rbd/myrbd/disk3 /mnt/ceph_rbd/
[root@client-01 ~]# df -h | grep rbd
/dev/rbd0        15G  140M   15G   1% /mnt/ceph_rbd
[root@client-01 ~]# 
```

Автоматизируем данный процесс, но предварительно отмонтируем устройство:
```bash
umount /mnt/ceph_rbd/
rbd unmap /dev/rbd0
rbd showmapped
```
```
[root@client-01 ~]# umount /mnt/ceph_rbd/
[root@client-01 ~]# rbd unmap /dev/rbd0
[root@client-01 ~]# rbd showmapped
[root@client-01 ~]# 
```

Для автоматического подключения RBD устройств воспользуемся службой rbdmap, которая использует файл /etc/ceph/rbdmap и подключает все устройства, прописанные в данном файле.

Отредактируем файл /etc/ceph/rbdmap:
```
# RbdDevice             Parameters
#poolname/imagename     id=client,keyring=/etc/ceph/ceph.client.keyring
myrbd/disk3             id=admin,keyring=/etc/ceph/ceph.client.admin.keyring    #<--- добавлена строка
```

Добавим службу rbdmap в автозагрузку и сразу же запустим:
```bash
systemctl enable --now rbdmap
```
```
[root@client-01 ~]# systemctl enable --now rbdmap
Created symlink /etc/systemd/system/multi-user.target.wants/rbdmap.service → /usr/lib/systemd/system/rbdmap.service.
[root@client-01 ~]# rbd showmapped
id  pool   namespace  image  snap  device   
0   myrbd             disk3  -     /dev/rbd0
[root@client-01 ~]# 
```

Подправим fstab, для автоматического монтирования после перезагрузки ОС:
```bash
echo "/dev/rbd/myrbd/disk3                      /mnt/ceph_rbd           xfs     _netdev         0 0" >> /etc/fstab
```
```
[root@client-01 ~]# echo "/dev/rbd/myrbd/disk3                      /mnt/ceph_rbd           xfs     _netdev         0 0" >> /etc/fstab
[root@client-01 ~]# cat /etc/fstab
#
# /etc/fstab
# Created by anaconda on Wed Nov  9 10:15:27 2022
#
# Accessible filesystems, by reference, are maintained under '/dev/disk/'.
# See man pages fstab(5), findfs(8), mount(8) and/or blkid(8) for more info.
#
# After editing this file, run 'systemctl daemon-reload' to update systemd
# units generated from this file.
#
UUID=ceb11787-f80b-4377-859f-a83f14385537 /                       xfs     defaults        0 0
/dev/rbd/myrbd/disk3                      /mnt/ceph_rbd           xfs     _netdev         0 0  #<--- добавлена строка
```



#### Cephfs

Создаем cephfs:
```bash
ceph fs new cephfs cephfs_meta cephfs_data
```
```
[root@mon-01 ~]# ceph fs new cephfs cephfs_meta cephfs_data
  Pool 'cephfs_data' (id '3') has pg autoscale mode 'on' but is not marked as bulk.
  Consider setting the flag by running
    # ceph osd pool set cephfs_data bulk true
new fs with metadata pool 4 and data pool 3
[root@mon-01 ~]# 
```
```
[root@mon-01 ~]# ceph fs ls
name: cephfs, metadata pool: cephfs_meta, data pools: [cephfs_data ]
[root@mon-01 ~]# 
```

Создадим директорий для монтирования:
```bash
mkdir /mnt/cephfs
```
```
[root@client-01 ~]# mkdir /mnt/cephfs
[root@client-01 ~]# 
```

Получим fsid ceph кластера:
```bash
ceph fsid
```
```
[root@client-01 ~]# ceph fsid
0941ec88-bdfb-11ee-8c1c-d00dd111fe9b
[root@client-01 ~]# 
```

Смонтируем файловую систему:
```bash
mount.ceph admin@0941ec88-bdfb-11ee-8c1c-d00dd111fe9b.cephfs=/ /mnt/cephfs/
```
```
[root@client-01 ~]# mount.ceph admin@0941ec88-bdfb-11ee-8c1c-d00dd111fe9b.cephfs=/ /mnt/cephfs/
[root@client-01 ~]# df -h | grep cephfs
admin@0941ec88-bdfb-11ee-8c1c-d00dd111fe9b.cephfs=/   19G     0   19G   0% /mnt/cephfs
[root@client-01 ~]# 
```



---
Create two pools with default settings for use with a file system, you might run the following commands:
```bash
ceph osd pool create cephfs_data
ceph osd pool create cephfs_meta
```

Once the pools are created, you may enable the file system using the fs new command:
```bash
ceph fs new cephfs cephfs_meta cephfs_data
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
mount.ceph admin@df544aea-bd4d-11ee-8e82-d00d13a36aec.cephfs=/ /mnt/cephfs/
```
or
```bash
mount.ceph admin@.cephfs=/ /mnt/cephfs/
```
---