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

Ceph кластер будем разворачивать с помощью Terraform, а все установки и настройки необходимых приложений будем реализовывать с помощью Ansible.

Для того чтобы развернуть ceph кластер, нужно выполнить следующую команду:
```bash
terraform init && terraform apply -auto-approve && \
sleep 60 && ansible-playbook ./provision.yml
```

По завершению команды получим данные outputs:
```
Outputs:

client-info = {
  "client-01" = {
    "ip_address" = tolist([
      "10.10.10.19",
    ])
    "nat_ip_address" = tolist([
      "",
    ])
  }
}
mds-info = {
  "mds-01" = {
    "ip_address" = tolist([
      "10.10.10.8",
    ])
    "nat_ip_address" = tolist([
      "",
    ])
  }
}
mon-info = {
  "mon-01" = {
    "ip_address" = tolist([
      "10.10.10.21",
    ])
    "nat_ip_address" = tolist([
      "51.250.99.58",
    ])
  }
  "mon-02" = {
    "ip_address" = tolist([
      "10.10.10.15",
    ])
    "nat_ip_address" = tolist([
      "",
    ])
  }
  "mon-03" = {
    "ip_address" = tolist([
      "10.10.10.35",
    ])
    "nat_ip_address" = tolist([
      "",
    ])
  }
}
osd-info = {
  "osd-01" = {
    "ip_address" = tolist([
      "10.10.10.13",
    ])
    "nat_ip_address" = tolist([
      "",
    ])
  }
  "osd-02" = {
    "ip_address" = tolist([
      "10.10.10.28",
    ])
    "nat_ip_address" = tolist([
      "",
    ])
  }
  "osd-03" = {
    "ip_address" = tolist([
      "10.10.10.7",
    ])
    "nat_ip_address" = tolist([
      "",
    ])
  }
  "osd-04" = {
    "ip_address" = tolist([
      "10.10.10.36",
    ])
    "nat_ip_address" = tolist([
      "",
    ])
  }
}
```

На всех серверах будут установлены ОС Almalinux 9, настроены синхронизация времени Chrony, система принудительного контроля доступа SELinux, в качестве firewall будет использоваться NFTables.

Список виртуальных машин после запуска стенда:

<img src="pics/screen-001.png" alt="screen-001.png" />

Ceph кластер будет состоять из следующих серверов:
- мониторы (тут же и менеджеры): mon-01, mon-02, mon-03;
- сервер метаданных: mds-01;
- OSD: osd-01, osd-02, osd-03.

Также будут подготовлены:
- клиентский сервер client-01 для подключения к ceph кластеру;
- сервер osd-04 для замены одного из osd серверов.

Все osd сервера имеют по три дополнительных диска по 10 ГБ:
- vdb, vdc - которые будут включены в кластер во время разворачивания;
- vdd - для дополнительного включения в кластер при выполнении лабораторной работы.

Если в строке браузера введём следующую строку:
```
https://51.250.99.58:8443
```

то получим страницу Ceph Dashbooard:

<img src="pics/screen-002.png" alt="screen-002.png" />

В дальнейшем все команды будем выполнять на сервере mon-01, поэтому подключимся к этому серверу с помощью ssh, имея публичный адрес, полученный во время разворачивания инфраструктуры ceph кластера:
```bash
ssh almalinux@51.250.99.58
```
```
(.venv) [user@redos lab-14]$ ssh almalinux@51.250.99.58
Last login: Tue Jan 30 15:03:13 2024 from 10.10.10.21
[almalinux@mon-01 ~]$ sudo -i
[root@mon-01 ~]# 
```

Просчитать pg для pool'ов:
rbd - 5/10 объема дисков 
cephfs - 3/10 объема дисков 
объяснить логику расчёта, создать пулы.

Формула для расчета: 
```
Total PGs = (Total_number_of_OSD * %_data * Target_PGs_per_OSD) / max_replication_count

Total_number_of_OSD - количество OSDs, в которых этот пул будет иметь PGS. Обычно это количество OSDs всего кластера, но может быть меньше в зависимости от правил CRUSH. (например, отдельные наборы дисков SSD и SATA)

%_data - это значение представляет приблизительный процент данных, которые будут содержаться в этом пуле для данного конкретного OSDs. 

Target PGs per OSD - это значение должно быть заполнено на основе следующего указания:
    100 - если количество OSDs кластера, как ожидается, не увеличится в обозримом будущем.
    200 - если ожидается, что количество OSDs кластера увеличится (до удвоения размера) в обозримом будущем.
    300 - если ожидается, что количество OSDs кластера увеличится в 2-3 раза в обозримом будущем.

max_replication_count - количество реплик, которые будут находиться в пуле. Значение, по умолчанию, равно 3.
```

Для 6 osd (с дисками по 10 Гб) получаем:

Для RBD: 
```
total PGs = (6 * 5/10 * 100) / 3 = 100 => 128 pg
```

Создаем пул myrbd: 
```bash
ceph osd pool create myrbd 128
ceph osd pool set myrbd size 3
ceph osd pool application enable myrbd rbd
```
```
[root@mon-01 ~]# ceph osd pool create myrbd 128
pool 'myrbd' created
[root@mon-01 ~]# ceph osd pool set myrbd size 3
set pool 2 size to 3
[root@mon-01 ~]# ceph osd pool application enable myrbd rbd
enabled application 'rbd' on pool 'myrbd'
[root@mon-01 ~]# 
```

Для cephfs: 
```
total PGs = (6 * 3/10 * 100) / 3 = 60 => 64 pg
```

Создаем пул для данных cephfs_data: 
```bash
ceph osd pool create cephfs_data 64
ceph osd pool set cephfs_data size 3
```
```
[root@mon-01 ~]# ceph osd pool create cephfs_data 64
pool 'cephfs_data' created
[root@mon-01 ~]# ceph osd pool set cephfs_data size 3
set pool 3 size to 3
[root@mon-01 ~]# 
```

и для метаданных cephfs_meta: 
```bash
ceph osd pool create cephfs_meta 64
ceph osd pool set cephfs_meta size 3
```
```
[root@mon-01 ~]# ceph osd pool create cephfs_meta 64
pool 'cephfs_meta' created
[root@mon-01 ~]# ceph osd pool set cephfs_meta size 3
set pool 4 size to 3
[root@mon-01 ~]# 
```

#### RBD
Создать и пробросить на клиентские машины 3 rbd 

Создадим 3 rbd диска:
```bash
rbd create disk1 --size 1G --pool myrbd
rbd create disk2 --size 2G --pool myrbd
rbd create disk3 --size 3G --pool myrbd
```
```
[root@mon-01 ~]# rbd create disk1 --size 1G --pool myrbd
[root@mon-01 ~]# rbd create disk2 --size 2G --pool myrbd
[root@mon-01 ~]# rbd create disk3 --size 3G --pool myrbd
[root@mon-01 ~]# rbd ls --pool myrbd
disk1
disk2
disk3
[root@mon-01 ~]# 
```

С клиентской машины client-01 осуществим подключение к ceph кластеру.

Скопируем ceph конфиг файл ceph.conf и ключ ceph.client.admin.keyring на клиентскую машину client-01:
```
[root@mon-01 ~]# scp /etc/ceph/{ceph.client.admin.keyring,ceph.conf} almalinux@client-01:/tmp/
ceph.client.admin.keyring                     100%  151   419.8KB/s   00:00    
ceph.conf                                     100%  265   894.2KB/s   00:00    
[root@mon-01 ~]# 
```

Подключимся к клиентской машине client-01 с помощью ssh и из директории /tmp перенесём ceph.conf и ключ ceph.client.admin.keyring в /etc/ceph/:
```
[root@mon-01 ~]# ssh almalinux@client-01
Last login: Tue Jan 30 14:59:13 2024 from 10.10.10.21
[almalinux@client-01 ~]$ sudo -i
[root@client-01 ~]# mv /tmp/{ceph.client.admin.keyring,ceph.conf} /etc/ceph/
[root@client-01 ~]# 
```
Ceph конфиг файл ceph.conf выглядит следующим образом:
```
[root@client-01 ~]# cat /etc/ceph/ceph.conf 
# minimal ceph.conf for 0120dc54-bf67-11ee-9c79-d00d151775b8
[global]
	fsid = 0120dc54-bf67-11ee-9c79-d00d151775b8
	mon_host = [v2:10.10.10.21:3300/0,v1:10.10.10.21:6789/0] [v2:10.10.10.15:3300/0,v1:10.10.10.15:6789/0] [v2:10.10.10.35:3300/0,v1:10.10.10.35:6789/0]
```

Ключ клиента ceph.client.admin.keyring выглядит подобным образом:
```
[root@client-01 ~]# cat /etc/ceph/ceph.client.admin.keyring 
[client.admin]
	key = AQAp5bhleqo9NxAANNApd9s5vGDN7e1ShFoIew==
	caps mds = "allow *"
	caps mgr = "allow *"
	caps mon = "allow *"
	caps osd = "allow *"
```

Подключим блочное устройство, например, disk3 к клиенту:
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
meta-data=/dev/rbd/myrbd/disk3   isize=512    agcount=8, agsize=98304 blks
         =                       sectsz=512   attr=2, projid32bit=1
         =                       crc=1        finobt=1, sparse=1, rmapbt=0
         =                       reflink=1    bigtime=1 inobtcount=1 nrext64=0
data     =                       bsize=4096   blocks=786432, imaxpct=25
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
/dev/rbd0       3.0G   54M  2.9G   2% /mnt/ceph_rbd
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
```bash
echo "myrbd/disk3             id=admin,keyring=/etc/ceph/ceph.client.admin.keyring" >> /etc/ceph/rbdmap
```
```
[root@client-01 ~]# echo "myrbd/disk3             id=admin,keyring=/etc/ceph/ceph.client.admin.keyring" >> /etc/ceph/rbdmap 
[root@client-01 ~]# cat /etc/ceph/rbdmap
# RbdDevice		Parameters
#poolname/imagename	id=client,keyring=/etc/ceph/ceph.client.keyring
myrbd/disk3          id=admin,keyring=/etc/ceph/ceph.client.admin.keyring  #<--- добавлена строка
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
Создать и пробросить на клиентские машины cephfs (общий раздел на каждую машину)

Создадим файловую систему cephfs, для этого на сервере mon-01 выполним следующую команду:
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

На клиентской машине client-01 cоздадим директорий для монтирования файловой системы cephfs:
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
0120dc54-bf67-11ee-9c79-d00d151775b8
[root@client-01 ~]# 
```

Смонтируем файловую систему cephfs:
```bash
mount.ceph admin@0120dc54-bf67-11ee-9c79-d00d151775b8.cephfs=/ /mnt/cephfs/
```
```
[root@client-01 ~]# mount.ceph admin@0120dc54-bf67-11ee-9c79-d00d151775b8.cephfs=/ /mnt/cephfs/
[root@client-01 ~]# df -h | grep cephfs
admin@0120dc54-bf67-11ee-9c79-d00d151775b8.cephfs=/   19G     0   19G   0% /mnt/cephfs
[root@client-01 ~]# 
```

Для наглядности на каждом из монтированных файловых систем ceph создадим по текстовому файлу:
```bash
echo "Hello RBD" > /mnt/ceph_rbd/rbd.txt
echo "Hello CephFS" > /mnt/cephfs/cephfs.txt
```
```
[root@client-01 ~]# echo "Hello RBD" > /mnt/ceph_rbd/rbd.txt
[root@client-01 ~]# cat /mnt/ceph_rbd/rbd.txt 
Hello RBD
[root@client-01 ~]# echo "Hello CephFS" > /mnt/cephfs/cephfs.txt
[root@client-01 ~]# cat /mnt/cephfs/cephfs.txt 
Hello CephFS
[root@client-01 ~]# 
```

#### Сгенерировать сбой ноды с osd, вывести из кластера, добавить новую

Сначала посмотрим состояние ceph кластера:
```bash
ceph -s
```
```
[root@mon-01 ~]# ceph -s
  cluster:
    id:     0120dc54-bf67-11ee-9c79-d00d151775b8
    health: HEALTH_OK
 
  services:
    mon: 3 daemons, quorum mon-01,mon-03,mon-02 (age 102m)
    mgr: mon-01.duszzi(active, since 105m), standbys: mon-03.rrskxv, mon-02.cjmoqm
    mds: 1/1 daemons up
    osd: 6 osds: 6 up (since 101m), 6 in (since 102m)
 
  data:
    volumes: 1/1 healthy
    pools:   4 pools, 113 pgs
    objects: 45 objects, 6.8 MiB
    usage:   475 MiB used, 60 GiB / 60 GiB avail
    pgs:     113 active+clean
 
[root@mon-01 ~]# 
```

Для отслеживания изменения состояния ceph кластера в другом терминале запустим команду:
```bash
ceph -w
```
```
[root@mon-01 ~]# ceph -w
  cluster:
    id:     0120dc54-bf67-11ee-9c79-d00d151775b8
    health: HEALTH_OK
 
  services:
    mon: 3 daemons, quorum mon-01,mon-03,mon-02 (age 106m)
    mgr: mon-01.duszzi(active, since 110m), standbys: mon-03.rrskxv, mon-02.cjmoqm
    mds: 1/1 daemons up
    osd: 6 osds: 6 up (since 105m), 6 in (since 106m)
 
  data:
    volumes: 1/1 healthy
    pools:   4 pools, 113 pgs
    objects: 45 objects, 6.8 MiB
    usage:   475 MiB used, 60 GiB / 60 GiB avail
    pgs:     113 active+clean
 


```

Отключим один из серверов osd, например, osd-01:

<img src="pics/screen-003.png" alt="screen-003.png" />

<img src="pics/screen-004.png" alt="screen-004.png" />

Отображение Ceph Dashboard:

<img src="pics/screen-005.png" alt="screen-005.png" />

В текущем окне терминала проверим промежуточное состояние ceph кластера:
```
[root@mon-01 ~]# ceph -s
  cluster:
    id:     0120dc54-bf67-11ee-9c79-d00d151775b8
    health: HEALTH_WARN
            1 hosts fail cephadm check
            2 osds down
            1 host (2 osds) down
            Degraded data redundancy: 45/135 objects degraded (33.333%), 32 pgs degraded, 113 pgs undersized
 
  services:
    mon: 3 daemons, quorum mon-01,mon-03,mon-02 (age 114m)
    mgr: mon-01.duszzi(active, since 117m), standbys: mon-03.rrskxv, mon-02.cjmoqm
    mds: 1/1 daemons up
    osd: 6 osds: 4 up (since 4m), 6 in (since 113m)
 
  data:
    volumes: 1/1 healthy
    pools:   4 pools, 113 pgs
    objects: 45 objects, 6.8 MiB
    usage:   475 MiB used, 60 GiB / 60 GiB avail
    pgs:     45/135 objects degraded (33.333%)
             81 active+undersized
             32 active+undersized+degraded
 
[root@mon-01 ~]# 
```

```
[root@mon-01 ~]# ceph osd df
ID  CLASS  WEIGHT   REWEIGHT  SIZE    RAW USE  DATA     OMAP  META     AVAIL    %USE  VAR   PGS  STATUS
 1    hdd  0.00980         0     0 B      0 B      0 B   0 B      0 B      0 B     0     0    0    down
 3    hdd  0.00980         0     0 B      0 B      0 B   0 B      0 B      0 B     0     0    0    down
 0    hdd  0.00980   1.00000  10 GiB   78 MiB  8.6 MiB   0 B   69 MiB  9.9 GiB  0.76  0.98   54      up
 4    hdd  0.00980   1.00000  10 GiB   80 MiB   11 MiB   0 B   69 MiB  9.9 GiB  0.79  1.02   59      up
 2    hdd  0.00980   1.00000  10 GiB   79 MiB  9.2 MiB   0 B   69 MiB  9.9 GiB  0.77  0.99   59      up
 5    hdd  0.00980   1.00000  10 GiB   80 MiB   11 MiB   0 B   69 MiB  9.9 GiB  0.78  1.01   54      up
                       TOTAL  40 GiB  317 MiB   39 MiB   0 B  278 MiB   40 GiB  0.77                   
MIN/MAX VAR: 0.98/1.02  STDDEV: 0.01
[root@mon-01 ~]# 
```

```
[root@mon-01 ~]# ceph orch host ls
HOST                ADDR         LABELS  STATUS   
mds-01.example.com  10.10.10.8                    
mon-01.example.com  10.10.10.21  _admin           
mon-02.example.com  10.10.10.15                   
mon-03.example.com  10.10.10.35                   
osd-01.example.com  10.10.10.13          Offline  
osd-02.example.com  10.10.10.28                   
osd-03.example.com  10.10.10.7                    
7 hosts in cluster
[root@mon-01 ~]# 
```

Так как хост osd-01 отключен, исключим его из ceph кластера:
```bash
ceph orch host rm osd-01 --force
```
```
[root@mon-01 ~]# ceph orch host rm osd-01 --force
Removed  host 'osd-01'
[root@mon-01 ~]# 
```

```
[root@mon-01 ~]# ceph orch host ls
HOST                ADDR         LABELS  STATUS  
mds-01.example.com  10.10.10.8                   
mon-01.example.com  10.10.10.21  _admin          
mon-02.example.com  10.10.10.15                  
mon-03.example.com  10.10.10.35                  
osd-02.example.com  10.10.10.28                  
osd-03.example.com  10.10.10.7                   
6 hosts in cluster
[root@mon-01 ~]# 
```

```
[root@mon-01 ~]# ceph osd df
ID  CLASS  WEIGHT   REWEIGHT  SIZE    RAW USE  DATA     OMAP  META     AVAIL    %USE  VAR   PGS  STATUS
 1    hdd  0.00980         0     0 B      0 B      0 B   0 B      0 B      0 B     0     0    0    down
 3    hdd  0.00980         0     0 B      0 B      0 B   0 B      0 B      0 B     0     0    0    down
 0    hdd  0.00980   1.00000  10 GiB   78 MiB  8.6 MiB   0 B   69 MiB  9.9 GiB  0.76  0.98   54      up
 4    hdd  0.00980   1.00000  10 GiB   80 MiB   11 MiB   0 B   69 MiB  9.9 GiB  0.79  1.02   59      up
 2    hdd  0.00980   1.00000  10 GiB   79 MiB  9.2 MiB   0 B   69 MiB  9.9 GiB  0.77  0.99   59      up
 5    hdd  0.00980   1.00000  10 GiB   80 MiB   11 MiB   0 B   69 MiB  9.9 GiB  0.78  1.01   54      up
                       TOTAL  40 GiB  317 MiB   39 MiB   0 B  278 MiB   40 GiB  0.77                   
MIN/MAX VAR: 0.98/1.02  STDDEV: 0.01
[root@mon-01 ~]# 
```

```
[root@mon-01 ~]# ceph df
--- RAW STORAGE ---
CLASS    SIZE   AVAIL     USED  RAW USED  %RAW USED
hdd    40 GiB  40 GiB  317 MiB   317 MiB       0.77
TOTAL  40 GiB  40 GiB  317 MiB   317 MiB       0.77
 
--- POOLS ---
POOL         ID  PGS   STORED  OBJECTS     USED  %USED  MAX AVAIL
.mgr          1    1  673 KiB        2  1.3 MiB      0     28 GiB
myrbd         2   32  3.7 MiB       20  7.5 MiB   0.01     28 GiB
cephfs_data   3   64     19 B        1   12 KiB      0     28 GiB
cephfs_meta   4   16  9.3 KiB       22  108 KiB      0     28 GiB
[root@mon-01 ~]# 
```

```
[root@mon-01 ~]# ceph orch device ls
HOST                PATH      TYPE  DEVICE ID              SIZE  AVAILABLE  REFRESHED  REJECT REASONS                                                           
osd-01.example.com  /dev/vdb  hdd   epd9n7a3q1bfnkgehkvs  10.0G  No         59m ago    Has a FileSystem, Insufficient space (<10 extents) on vgs, LVM detected  
osd-01.example.com  /dev/vdc  hdd   epda6uu9fqmphgqd2h6v  10.0G  No         59m ago    Has a FileSystem, Insufficient space (<10 extents) on vgs, LVM detected  
osd-01.example.com  /dev/vdd  hdd   epdqhj553mmlu8el7shh  10.0G  Yes        59m ago                                                                             
osd-02.example.com  /dev/vdb  hdd   epduda84dd22iemrntq9  10.0G  No         27m ago    Has a FileSystem, Insufficient space (<10 extents) on vgs, LVM detected  
osd-02.example.com  /dev/vdc  hdd   epdullidt0hkd8u82h0j  10.0G  No         27m ago    Has a FileSystem, Insufficient space (<10 extents) on vgs, LVM detected  
osd-02.example.com  /dev/vdd  hdd   epdeuuvg7s050kogpkp0  10.0G  Yes        27m ago                                                                             
osd-03.example.com  /dev/vdb  hdd   epdkce6tict29bchgvov  10.0G  No         27m ago    Has a FileSystem, Insufficient space (<10 extents) on vgs, LVM detected  
osd-03.example.com  /dev/vdc  hdd   epdubtv3k7v6guk38i9h  10.0G  No         27m ago    Has a FileSystem, Insufficient space (<10 extents) on vgs, LVM detected  
osd-03.example.com  /dev/vdd  hdd   epdi14atfqeemsjbjf5t  10.0G  Yes        27m ago                                                                             
[root@mon-01 ~]# 
```




ceph orch host add osd-04.example.com
ceph orch daemon add osd osd-04.example.com:/dev/vdb


```
[root@mon-01 ~]# ceph orch host add osd-04.example.com
Added host 'osd-04.example.com' with addr '10.10.10.36'
[root@mon-01 ~]# 
```

```
[root@mon-01 ~]# ceph orch host ls
HOST                ADDR         LABELS  STATUS  
mds-01.example.com  10.10.10.8                   
mon-01.example.com  10.10.10.21  _admin          
mon-02.example.com  10.10.10.15                  
mon-03.example.com  10.10.10.35                  
osd-02.example.com  10.10.10.28                  
osd-03.example.com  10.10.10.7                   
osd-04.example.com  10.10.10.36                  
7 hosts in cluster
[root@mon-01 ~]# 
```

```
[root@mon-01 ~]# ceph orch daemon add osd osd-04.example.com:/dev/vdb
[root@mon-01 ~]# ceph orch daemon add osd osd-04.example.com:/dev/vdc
[root@mon-01 ~]# 
```















```
[root@mon-01 ~]# ceph -w
  cluster:
    id:     0120dc54-bf67-11ee-9c79-d00d151775b8
    health: HEALTH_OK
 
  services:
    mon: 3 daemons, quorum mon-01,mon-03,mon-02 (age 106m)
    mgr: mon-01.duszzi(active, since 110m), standbys: mon-03.rrskxv, mon-02.cjmoqm
    mds: 1/1 daemons up
    osd: 6 osds: 6 up (since 105m), 6 in (since 106m)
 
  data:
    volumes: 1/1 healthy
    pools:   4 pools, 113 pgs
    objects: 45 objects, 6.8 MiB
    usage:   475 MiB used, 60 GiB / 60 GiB avail
    pgs:     113 active+clean
 

2024-01-30T16:58:16.631680+0300 mon.mon-01 [INF] osd.1 marked itself down and dead
2024-01-30T16:58:16.729649+0300 mon.mon-01 [INF] osd.3 marked itself down and dead
2024-01-30T16:58:17.615535+0300 mon.mon-01 [WRN] Health check failed: 2 osds down (OSD_DOWN)
2024-01-30T16:58:17.615567+0300 mon.mon-01 [WRN] Health check failed: 1 host (2 osds) down (OSD_HOST_DOWN)
2024-01-30T16:58:20.037842+0300 mon.mon-01 [WRN] Health check failed: Reduced data availability: 11 pgs inactive, 12 pgs peering (PG_AVAILABILITY)
2024-01-30T16:58:20.037884+0300 mon.mon-01 [WRN] Health check failed: Degraded data redundancy: 30/135 objects degraded (22.222%), 17 pgs degraded (PG_DEGRADED)
2024-01-30T16:58:25.800947+0300 mon.mon-01 [WRN] Health check update: Degraded data redundancy: 45/135 objects degraded (33.333%), 32 pgs degraded (PG_DEGRADED)
2024-01-30T16:58:25.800977+0300 mon.mon-01 [INF] Health check cleared: PG_AVAILABILITY (was: Reduced data availability: 9 pgs inactive)
2024-01-30T16:59:16.554889+0300 mon.mon-01 [WRN] Health check failed: failed to probe daemons or devices (CEPHADM_REFRESH_FAILED)
2024-01-30T16:59:20.432228+0300 mon.mon-01 [WRN] Health check update: Degraded data redundancy: 45/135 objects degraded (33.333%), 32 pgs degraded, 113 pgs undersized (PG_DEGRADED)
2024-01-30T17:00:00.000177+0300 mon.mon-01 [WRN] Health detail: HEALTH_WARN failed to probe daemons or devices; 2 osds down; 1 host (2 osds) down; Degraded data redundancy: 45/135 objects degraded (33.333%), 32 pgs degraded, 113 pgs undersized
2024-01-30T17:00:00.000204+0300 mon.mon-01 [WRN] [WRN] CEPHADM_REFRESH_FAILED: failed to probe daemons or devices
2024-01-30T17:00:00.000209+0300 mon.mon-01 [WRN]     host osd-01.example.com `cephadm gather-facts` failed: Unable to reach remote host osd-01.example.com. SSH connection closed
2024-01-30T17:00:00.000213+0300 mon.mon-01 [WRN] [WRN] OSD_DOWN: 2 osds down
2024-01-30T17:00:00.000217+0300 mon.mon-01 [WRN]     osd.1 (root=default,host=osd-01) is down
2024-01-30T17:00:00.000221+0300 mon.mon-01 [WRN]     osd.3 (root=default,host=osd-01) is down
2024-01-30T17:00:00.000225+0300 mon.mon-01 [WRN] [WRN] OSD_HOST_DOWN: 1 host (2 osds) down
2024-01-30T17:00:00.000229+0300 mon.mon-01 [WRN]     host osd-01 (root=default) (2 osds) is down
2024-01-30T17:00:00.000235+0300 mon.mon-01 [WRN] [WRN] PG_DEGRADED: Degraded data redundancy: 45/135 objects degraded (33.333%), 32 pgs degraded, 113 pgs undersized
2024-01-30T17:00:00.000240+0300 mon.mon-01 [WRN]     pg 2.8 is stuck undersized for 98s, current state active+undersized, last acting [0,2]
2024-01-30T17:00:00.000253+0300 mon.mon-01 [WRN]     pg 2.9 is stuck undersized for 98s, current state active+undersized+degraded, last acting [5,0]
2024-01-30T17:00:00.000315+0300 mon.mon-01 [WRN]     pg 2.a is stuck undersized for 98s, current state active+undersized, last acting [5,0]
2024-01-30T17:00:00.000323+0300 mon.mon-01 [WRN]     pg 2.b is stuck undersized for 98s, current state active+undersized, last acting [4,2]
2024-01-30T17:00:00.000332+0300 mon.mon-01 [WRN]     pg 2.c is stuck undersized for 98s, current state active+undersized+degraded, last acting [5,0]
2024-01-30T17:00:00.000338+0300 mon.mon-01 [WRN]     pg 2.d is stuck undersized for 98s, current state active+undersized, last acting [0,5]
2024-01-30T17:00:00.000345+0300 mon.mon-01 [WRN]     pg 2.e is stuck undersized for 98s, current state active+undersized, last acting [2,0]
2024-01-30T17:00:00.000350+0300 mon.mon-01 [WRN]     pg 3.8 is stuck undersized for 98s, current state active+undersized, last acting [5,0]
2024-01-30T17:00:00.000391+0300 mon.mon-01 [WRN]     pg 3.9 is stuck undersized for 98s, current state active+undersized, last acting [0,2]
2024-01-30T17:00:00.000397+0300 mon.mon-01 [WRN]     pg 3.a is stuck undersized for 98s, current state active+undersized, last acting [0,5]
2024-01-30T17:00:00.000403+0300 mon.mon-01 [WRN]     pg 3.b is stuck undersized for 98s, current state active+undersized, last acting [2,4]
2024-01-30T17:00:00.000408+0300 mon.mon-01 [WRN]     pg 3.c is stuck undersized for 98s, current state active+undersized, last acting [0,5]
2024-01-30T17:00:00.000414+0300 mon.mon-01 [WRN]     pg 3.d is stuck undersized for 98s, current state active+undersized, last acting [0,2]
2024-01-30T17:00:00.000420+0300 mon.mon-01 [WRN]     pg 3.f is stuck undersized for 98s, current state active+undersized, last acting [0,2]
2024-01-30T17:00:00.000426+0300 mon.mon-01 [WRN]     pg 3.22 is stuck undersized for 98s, current state active+undersized, last acting [5,4]
2024-01-30T17:00:00.000431+0300 mon.mon-01 [WRN]     pg 3.24 is stuck undersized for 98s, current state active+undersized, last acting [2,0]
2024-01-30T17:00:00.000437+0300 mon.mon-01 [WRN]     pg 3.25 is stuck undersized for 98s, current state active+undersized, last acting [5,0]
2024-01-30T17:00:00.000443+0300 mon.mon-01 [WRN]     pg 3.26 is stuck undersized for 98s, current state active+undersized, last acting [4,5]
2024-01-30T17:00:00.000448+0300 mon.mon-01 [WRN]     pg 3.27 is stuck undersized for 98s, current state active+undersized, last acting [5,4]
2024-01-30T17:00:00.000453+0300 mon.mon-01 [WRN]     pg 3.28 is stuck undersized for 98s, current state active+undersized, last acting [5,0]
2024-01-30T17:00:00.000460+0300 mon.mon-01 [WRN]     pg 3.29 is stuck undersized for 98s, current state active+undersized, last acting [5,0]
2024-01-30T17:00:00.000466+0300 mon.mon-01 [WRN]     pg 3.2a is stuck undersized for 98s, current state active+undersized, last acting [4,2]
2024-01-30T17:00:00.000471+0300 mon.mon-01 [WRN]     pg 3.2b is stuck undersized for 98s, current state active+undersized, last acting [2,0]
2024-01-30T17:00:00.000476+0300 mon.mon-01 [WRN]     pg 3.2c is stuck undersized for 98s, current state active+undersized, last acting [4,5]
2024-01-30T17:00:00.000667+0300 mon.mon-01 [WRN]     pg 3.2d is stuck undersized for 98s, current state active+undersized, last acting [5,4]
2024-01-30T17:00:00.000674+0300 mon.mon-01 [WRN]     pg 3.2e is stuck undersized for 98s, current state active+undersized, last acting [2,0]
2024-01-30T17:00:00.000680+0300 mon.mon-01 [WRN]     pg 3.2f is stuck undersized for 98s, current state active+undersized, last acting [0,5]
2024-01-30T17:00:00.000686+0300 mon.mon-01 [WRN]     pg 3.30 is stuck undersized for 98s, current state active+undersized+degraded, last acting [4,2]
2024-01-30T17:00:00.000691+0300 mon.mon-01 [WRN]     pg 3.31 is stuck undersized for 98s, current state active+undersized, last acting [5,0]
2024-01-30T17:00:00.000697+0300 mon.mon-01 [WRN]     pg 3.32 is stuck undersized for 98s, current state active+undersized, last acting [5,0]
2024-01-30T17:00:00.000703+0300 mon.mon-01 [WRN]     pg 3.33 is stuck undersized for 98s, current state active+undersized, last acting [5,0]
2024-01-30T17:00:00.000709+0300 mon.mon-01 [WRN]     pg 3.34 is stuck undersized for 98s, current state active+undersized, last acting [4,2]
2024-01-30T17:00:00.000714+0300 mon.mon-01 [WRN]     pg 3.35 is stuck undersized for 98s, current state active+undersized, last acting [0,2]
2024-01-30T17:00:00.000719+0300 mon.mon-01 [WRN]     pg 3.36 is stuck undersized for 98s, current state active+undersized, last acting [0,5]
2024-01-30T17:00:00.000726+0300 mon.mon-01 [WRN]     pg 3.37 is stuck undersized for 98s, current state active+undersized, last acting [0,5]
2024-01-30T17:00:00.000732+0300 mon.mon-01 [WRN]     pg 3.38 is stuck undersized for 98s, current state active+undersized, last acting [5,0]
2024-01-30T17:00:00.000741+0300 mon.mon-01 [WRN]     pg 3.39 is stuck undersized for 98s, current state active+undersized, last acting [0,5]
2024-01-30T17:00:00.000747+0300 mon.mon-01 [WRN]     pg 3.3a is stuck undersized for 98s, current state active+undersized, last acting [0,2]
2024-01-30T17:00:00.000753+0300 mon.mon-01 [WRN]     pg 3.3b is stuck undersized for 98s, current state active+undersized, last acting [2,0]
2024-01-30T17:00:00.000759+0300 mon.mon-01 [WRN]     pg 3.3c is stuck undersized for 98s, current state active+undersized, last acting [4,2]
2024-01-30T17:00:00.000768+0300 mon.mon-01 [WRN]     pg 3.3d is stuck undersized for 98s, current state active+undersized, last acting [5,4]
2024-01-30T17:00:00.000774+0300 mon.mon-01 [WRN]     pg 3.3e is stuck undersized for 98s, current state active+undersized, last acting [5,0]
2024-01-30T17:00:00.000779+0300 mon.mon-01 [WRN]     pg 3.3f is stuck undersized for 98s, current state active+undersized, last acting [4,2]
2024-01-30T17:00:00.000784+0300 mon.mon-01 [WRN]     pg 4.1 is stuck undersized for 98s, current state active+undersized, last acting [4,2]
2024-01-30T17:00:00.000791+0300 mon.mon-01 [WRN]     pg 4.8 is stuck undersized for 98s, current state active+undersized, last acting [0,5]
2024-01-30T17:00:00.001076+0300 mon.mon-01 [WRN]     pg 4.a is stuck undersized for 98s, current state active+undersized, last acting [4,5]
2024-01-30T17:00:00.001082+0300 mon.mon-01 [WRN]     pg 4.b is stuck undersized for 98s, current state active+undersized+degraded, last acting [2,4]
2024-01-30T17:00:00.001086+0300 mon.mon-01 [WRN]     pg 4.c is stuck undersized for 98s, current state active+undersized+degraded, last acting [4,5]
2024-01-30T17:00:00.001091+0300 mon.mon-01 [WRN]     pg 4.d is stuck undersized for 98s, current state active+undersized+degraded, last acting [4,5]
2024-01-30T17:00:00.001095+0300 mon.mon-01 [WRN]     pg 4.e is stuck undersized for 98s, current state active+undersized+degraded, last acting [4,2]
2024-01-30T17:00:00.001099+0300 mon.mon-01 [WRN]     pg 4.f is stuck undersized for 98s, current state active+undersized+degraded, last acting [2,4]
2024-01-30T17:02:27.917412+0300 mon.mon-01 [WRN] Health check failed: 1 hosts fail cephadm check (CEPHADM_HOST_CHECK_FAILED)
2024-01-30T17:02:27.917440+0300 mon.mon-01 [INF] Health check cleared: CEPHADM_REFRESH_FAILED (was: failed to probe daemons or devices)
2024-01-30T17:08:19.655100+0300 mon.mon-01 [INF] Marking osd.1 out (has been down for 601 seconds)
2024-01-30T17:08:19.655127+0300 mon.mon-01 [INF] Marking osd.3 out (has been down for 601 seconds)
2024-01-30T17:08:19.655361+0300 mon.mon-01 [INF] Health check cleared: OSD_DOWN (was: 2 osds down)
2024-01-30T17:08:19.655370+0300 mon.mon-01 [INF] Health check cleared: OSD_HOST_DOWN (was: 1 host (2 osds) down)
2024-01-30T17:10:00.000183+0300 mon.mon-01 [WRN] Health detail: HEALTH_WARN 1 hosts fail cephadm check; Degraded data redundancy: 45/135 objects degraded (33.333%), 32 pgs degraded, 113 pgs undersized
2024-01-30T17:10:00.000212+0300 mon.mon-01 [WRN] [WRN] CEPHADM_HOST_CHECK_FAILED: 1 hosts fail cephadm check
2024-01-30T17:10:00.000218+0300 mon.mon-01 [WRN]     host osd-01.example.com (10.10.10.13) failed check: Can't communicate with remote host `10.10.10.13`, possibly because the host is not reachable or python3 is not installed on the host. [Errno 110] Connect call failed ('10.10.10.13', 22)
2024-01-30T17:10:00.000223+0300 mon.mon-01 [WRN] [WRN] PG_DEGRADED: Degraded data redundancy: 45/135 objects degraded (33.333%), 32 pgs degraded, 113 pgs undersized
2024-01-30T17:10:00.000229+0300 mon.mon-01 [WRN]     pg 2.8 is stuck undersized for 11m, current state active+undersized, last acting [0,2]
2024-01-30T17:10:00.000233+0300 mon.mon-01 [WRN]     pg 2.9 is stuck undersized for 11m, current state active+undersized+degraded, last acting [5,0]
2024-01-30T17:10:00.000238+0300 mon.mon-01 [WRN]     pg 2.a is stuck undersized for 11m, current state active+undersized, last acting [5,0]
2024-01-30T17:10:00.000290+0300 mon.mon-01 [WRN]     pg 2.b is stuck undersized for 11m, current state active+undersized, last acting [4,2]
2024-01-30T17:10:00.000308+0300 mon.mon-01 [WRN]     pg 2.c is stuck undersized for 11m, current state active+undersized+degraded, last acting [5,0]
2024-01-30T17:10:00.000314+0300 mon.mon-01 [WRN]     pg 2.d is stuck undersized for 11m, current state active+undersized, last acting [0,5]
2024-01-30T17:10:00.000318+0300 mon.mon-01 [WRN]     pg 2.e is stuck undersized for 11m, current state active+undersized, last acting [2,0]
2024-01-30T17:10:00.000323+0300 mon.mon-01 [WRN]     pg 3.8 is stuck undersized for 11m, current state active+undersized, last acting [5,0]
2024-01-30T17:10:00.000329+0300 mon.mon-01 [WRN]     pg 3.9 is stuck undersized for 11m, current state active+undersized, last acting [0,2]
2024-01-30T17:10:00.000333+0300 mon.mon-01 [WRN]     pg 3.a is stuck undersized for 11m, current state active+undersized, last acting [0,5]
2024-01-30T17:10:00.000338+0300 mon.mon-01 [WRN]     pg 3.b is stuck undersized for 11m, current state active+undersized, last acting [2,4]
2024-01-30T17:10:00.000342+0300 mon.mon-01 [WRN]     pg 3.c is stuck undersized for 11m, current state active+undersized, last acting [0,5]
2024-01-30T17:10:00.000346+0300 mon.mon-01 [WRN]     pg 3.d is stuck undersized for 11m, current state active+undersized, last acting [0,2]
2024-01-30T17:10:00.000350+0300 mon.mon-01 [WRN]     pg 3.f is stuck undersized for 11m, current state active+undersized, last acting [0,2]
2024-01-30T17:10:00.000354+0300 mon.mon-01 [WRN]     pg 3.22 is stuck undersized for 11m, current state active+undersized, last acting [5,4]
2024-01-30T17:10:00.000358+0300 mon.mon-01 [WRN]     pg 3.24 is stuck undersized for 11m, current state active+undersized, last acting [2,0]
2024-01-30T17:10:00.000362+0300 mon.mon-01 [WRN]     pg 3.25 is stuck undersized for 11m, current state active+undersized, last acting [5,0]
2024-01-30T17:10:00.000367+0300 mon.mon-01 [WRN]     pg 3.26 is stuck undersized for 11m, current state active+undersized, last acting [4,5]
2024-01-30T17:10:00.000371+0300 mon.mon-01 [WRN]     pg 3.27 is stuck undersized for 11m, current state active+undersized, last acting [5,4]
2024-01-30T17:10:00.000376+0300 mon.mon-01 [WRN]     pg 3.28 is stuck undersized for 11m, current state active+undersized, last acting [5,0]
2024-01-30T17:10:00.000380+0300 mon.mon-01 [WRN]     pg 3.29 is stuck undersized for 11m, current state active+undersized, last acting [5,0]
2024-01-30T17:10:00.000384+0300 mon.mon-01 [WRN]     pg 3.2a is stuck undersized for 11m, current state active+undersized, last acting [4,2]
2024-01-30T17:10:00.000388+0300 mon.mon-01 [WRN]     pg 3.2b is stuck undersized for 11m, current state active+undersized, last acting [2,0]
2024-01-30T17:10:00.000392+0300 mon.mon-01 [WRN]     pg 3.2c is stuck undersized for 11m, current state active+undersized, last acting [4,5]
2024-01-30T17:10:00.000396+0300 mon.mon-01 [WRN]     pg 3.2d is stuck undersized for 11m, current state active+undersized, last acting [5,4]
2024-01-30T17:10:00.000400+0300 mon.mon-01 [WRN]     pg 3.2e is stuck undersized for 11m, current state active+undersized, last acting [2,0]
2024-01-30T17:10:00.000405+0300 mon.mon-01 [WRN]     pg 3.2f is stuck undersized for 11m, current state active+undersized, last acting [0,5]
2024-01-30T17:10:00.000409+0300 mon.mon-01 [WRN]     pg 3.30 is stuck undersized for 11m, current state active+undersized+degraded, last acting [4,2]
2024-01-30T17:10:00.000414+0300 mon.mon-01 [WRN]     pg 3.31 is stuck undersized for 11m, current state active+undersized, last acting [5,0]
2024-01-30T17:10:00.000419+0300 mon.mon-01 [WRN]     pg 3.32 is stuck undersized for 11m, current state active+undersized, last acting [5,0]
2024-01-30T17:10:00.000423+0300 mon.mon-01 [WRN]     pg 3.33 is stuck undersized for 11m, current state active+undersized, last acting [5,0]
2024-01-30T17:10:00.000427+0300 mon.mon-01 [WRN]     pg 3.34 is stuck undersized for 11m, current state active+undersized, last acting [4,2]
2024-01-30T17:10:00.000432+0300 mon.mon-01 [WRN]     pg 3.35 is stuck undersized for 11m, current state active+undersized, last acting [0,2]
2024-01-30T17:10:00.000450+0300 mon.mon-01 [WRN]     pg 3.36 is stuck undersized for 11m, current state active+undersized, last acting [0,5]
2024-01-30T17:10:00.000454+0300 mon.mon-01 [WRN]     pg 3.37 is stuck undersized for 11m, current state active+undersized, last acting [0,5]
2024-01-30T17:10:00.000458+0300 mon.mon-01 [WRN]     pg 3.38 is stuck undersized for 11m, current state active+undersized, last acting [5,0]
2024-01-30T17:10:00.000462+0300 mon.mon-01 [WRN]     pg 3.39 is stuck undersized for 11m, current state active+undersized, last acting [0,5]
2024-01-30T17:10:00.000466+0300 mon.mon-01 [WRN]     pg 3.3a is stuck undersized for 11m, current state active+undersized, last acting [0,2]
2024-01-30T17:10:00.000471+0300 mon.mon-01 [WRN]     pg 3.3b is stuck undersized for 11m, current state active+undersized, last acting [2,0]
2024-01-30T17:10:00.000475+0300 mon.mon-01 [WRN]     pg 3.3c is stuck undersized for 11m, current state active+undersized, last acting [4,2]
2024-01-30T17:10:00.000479+0300 mon.mon-01 [WRN]     pg 3.3d is stuck undersized for 11m, current state active+undersized, last acting [5,4]
2024-01-30T17:10:00.000483+0300 mon.mon-01 [WRN]     pg 3.3e is stuck undersized for 11m, current state active+undersized, last acting [5,0]
2024-01-30T17:10:00.000487+0300 mon.mon-01 [WRN]     pg 3.3f is stuck undersized for 11m, current state active+undersized, last acting [4,2]
2024-01-30T17:10:00.000491+0300 mon.mon-01 [WRN]     pg 4.1 is stuck undersized for 11m, current state active+undersized, last acting [4,2]
2024-01-30T17:10:00.000495+0300 mon.mon-01 [WRN]     pg 4.8 is stuck undersized for 11m, current state active+undersized, last acting [0,5]
2024-01-30T17:10:00.000500+0300 mon.mon-01 [WRN]     pg 4.a is stuck undersized for 11m, current state active+undersized, last acting [4,5]
2024-01-30T17:10:00.000504+0300 mon.mon-01 [WRN]     pg 4.b is stuck undersized for 11m, current state active+undersized+degraded, last acting [2,4]
2024-01-30T17:10:00.000509+0300 mon.mon-01 [WRN]     pg 4.c is stuck undersized for 11m, current state active+undersized+degraded, last acting [4,5]
2024-01-30T17:10:00.000513+0300 mon.mon-01 [WRN]     pg 4.d is stuck undersized for 11m, current state active+undersized+degraded, last acting [4,5]
2024-01-30T17:10:00.000517+0300 mon.mon-01 [WRN]     pg 4.e is stuck undersized for 11m, current state active+undersized+degraded, last acting [4,2]
2024-01-30T17:10:00.000521+0300 mon.mon-01 [WRN]     pg 4.f is stuck undersized for 11m, current state active+undersized+degraded, last acting [2,4]
2024-01-30T17:18:31.081356+0300 mon.mon-01 [WRN] Health check failed: Failed to apply 3 service(s): ceph-exporter,crash,node-exporter (CEPHADM_APPLY_SPEC_FAIL)
2024-01-30T17:18:31.081378+0300 mon.mon-01 [WRN] Health check failed: 1 stray host(s) with 2 daemon(s) not managed by cephadm (CEPHADM_STRAY_HOST)
2024-01-30T17:18:34.315653+0300 mgr.mon-01.duszzi [ERR] Unhandled exception from module 'cephadm' while running on mgr.mon-01.duszzi: 'osd-01.example.com'
2024-01-30T17:18:36.859558+0300 mon.mon-01 [ERR] Health check failed: Module 'cephadm' has failed: 'osd-01.example.com' (MGR_MODULE_ERROR)
2024-01-30T17:20:00.000147+0300 mon.mon-01 [ERR] Health detail: HEALTH_ERR Failed to apply 3 service(s): ceph-exporter,crash,node-exporter; 1 hosts fail cephadm check; 1 stray host(s) with 2 daemon(s) not managed by cephadm; Module 'cephadm' has failed: 'osd-01.example.com'; Degraded data redundancy: 45/135 objects degraded (33.333%), 32 pgs degraded, 113 pgs undersized
2024-01-30T17:20:00.000185+0300 mon.mon-01 [ERR] [WRN] CEPHADM_APPLY_SPEC_FAIL: Failed to apply 3 service(s): ceph-exporter,crash,node-exporter
2024-01-30T17:20:00.000190+0300 mon.mon-01 [ERR]     ceph-exporter: 'osd-01.example.com'
2024-01-30T17:20:00.000195+0300 mon.mon-01 [ERR]     crash: 'osd-01.example.com'
2024-01-30T17:20:00.000199+0300 mon.mon-01 [ERR]     node-exporter: 'osd-01.example.com'
2024-01-30T17:20:00.000204+0300 mon.mon-01 [ERR] [WRN] CEPHADM_HOST_CHECK_FAILED: 1 hosts fail cephadm check
2024-01-30T17:20:00.000210+0300 mon.mon-01 [ERR]     host osd-01.example.com (10.10.10.13) failed check: Can't communicate with remote host `10.10.10.13`, possibly because the host is not reachable or python3 is not installed on the host. [Errno 110] Connect call failed ('10.10.10.13', 22)
2024-01-30T17:20:00.000215+0300 mon.mon-01 [ERR] [WRN] CEPHADM_STRAY_HOST: 1 stray host(s) with 2 daemon(s) not managed by cephadm
2024-01-30T17:20:00.000223+0300 mon.mon-01 [ERR]     stray host osd-01.example.com has 2 stray daemons: ['osd.1', 'osd.3']
2024-01-30T17:20:00.000229+0300 mon.mon-01 [ERR] [ERR] MGR_MODULE_ERROR: Module 'cephadm' has failed: 'osd-01.example.com'
2024-01-30T17:20:00.000235+0300 mon.mon-01 [ERR]     Module 'cephadm' has failed: 'osd-01.example.com'
2024-01-30T17:20:00.000241+0300 mon.mon-01 [ERR] [WRN] PG_DEGRADED: Degraded data redundancy: 45/135 objects degraded (33.333%), 32 pgs degraded, 113 pgs undersized
2024-01-30T17:20:00.000246+0300 mon.mon-01 [ERR]     pg 2.8 is stuck undersized for 21m, current state active+undersized, last acting [0,2]
2024-01-30T17:20:00.000251+0300 mon.mon-01 [ERR]     pg 2.9 is stuck undersized for 21m, current state active+undersized+degraded, last acting [5,0]
2024-01-30T17:20:00.000256+0300 mon.mon-01 [ERR]     pg 2.a is stuck undersized for 21m, current state active+undersized, last acting [5,0]
2024-01-30T17:20:00.000266+0300 mon.mon-01 [ERR]     pg 2.b is stuck undersized for 21m, current state active+undersized, last acting [4,2]
2024-01-30T17:20:00.000272+0300 mon.mon-01 [ERR]     pg 2.c is stuck undersized for 21m, current state active+undersized+degraded, last acting [5,0]
2024-01-30T17:20:00.000321+0300 mon.mon-01 [ERR]     pg 2.d is stuck undersized for 21m, current state active+undersized, last acting [0,5]
2024-01-30T17:20:00.000327+0300 mon.mon-01 [ERR]     pg 2.e is stuck undersized for 21m, current state active+undersized, last acting [2,0]
2024-01-30T17:20:00.000332+0300 mon.mon-01 [ERR]     pg 3.8 is stuck undersized for 21m, current state active+undersized, last acting [5,0]
2024-01-30T17:20:00.000338+0300 mon.mon-01 [ERR]     pg 3.9 is stuck undersized for 21m, current state active+undersized, last acting [0,2]
2024-01-30T17:20:00.000344+0300 mon.mon-01 [ERR]     pg 3.a is stuck undersized for 21m, current state active+undersized, last acting [0,5]
2024-01-30T17:20:00.000349+0300 mon.mon-01 [ERR]     pg 3.b is stuck undersized for 21m, current state active+undersized, last acting [2,4]
2024-01-30T17:20:00.000354+0300 mon.mon-01 [ERR]     pg 3.c is stuck undersized for 21m, current state active+undersized, last acting [0,5]
2024-01-30T17:20:00.000360+0300 mon.mon-01 [ERR]     pg 3.d is stuck undersized for 21m, current state active+undersized, last acting [0,2]
2024-01-30T17:20:00.000365+0300 mon.mon-01 [ERR]     pg 3.f is stuck undersized for 21m, current state active+undersized, last acting [0,2]
2024-01-30T17:20:00.000371+0300 mon.mon-01 [ERR]     pg 3.22 is stuck undersized for 21m, current state active+undersized, last acting [5,4]
2024-01-30T17:20:00.000377+0300 mon.mon-01 [ERR]     pg 3.24 is stuck undersized for 21m, current state active+undersized, last acting [2,0]
2024-01-30T17:20:00.000383+0300 mon.mon-01 [ERR]     pg 3.25 is stuck undersized for 21m, current state active+undersized, last acting [5,0]
2024-01-30T17:20:00.000388+0300 mon.mon-01 [ERR]     pg 3.26 is stuck undersized for 21m, current state active+undersized, last acting [4,5]
2024-01-30T17:20:00.000394+0300 mon.mon-01 [ERR]     pg 3.27 is stuck undersized for 21m, current state active+undersized, last acting [5,4]
2024-01-30T17:20:00.000400+0300 mon.mon-01 [ERR]     pg 3.28 is stuck undersized for 21m, current state active+undersized, last acting [5,0]
2024-01-30T17:20:00.000406+0300 mon.mon-01 [ERR]     pg 3.29 is stuck undersized for 21m, current state active+undersized, last acting [5,0]
2024-01-30T17:20:00.000471+0300 mon.mon-01 [ERR]     pg 3.2a is stuck undersized for 21m, current state active+undersized, last acting [4,2]
2024-01-30T17:20:00.000476+0300 mon.mon-01 [ERR]     pg 3.2b is stuck undersized for 21m, current state active+undersized, last acting [2,0]
2024-01-30T17:20:00.000482+0300 mon.mon-01 [ERR]     pg 3.2c is stuck undersized for 21m, current state active+undersized, last acting [4,5]
2024-01-30T17:20:00.000490+0300 mon.mon-01 [ERR]     pg 3.2d is stuck undersized for 21m, current state active+undersized, last acting [5,4]
2024-01-30T17:20:00.000495+0300 mon.mon-01 [ERR]     pg 3.2e is stuck undersized for 21m, current state active+undersized, last acting [2,0]
2024-01-30T17:20:00.000501+0300 mon.mon-01 [ERR]     pg 3.2f is stuck undersized for 21m, current state active+undersized, last acting [0,5]
2024-01-30T17:20:00.000507+0300 mon.mon-01 [ERR]     pg 3.30 is stuck undersized for 21m, current state active+undersized+degraded, last acting [4,2]
2024-01-30T17:20:00.000512+0300 mon.mon-01 [ERR]     pg 3.31 is stuck undersized for 21m, current state active+undersized, last acting [5,0]
2024-01-30T17:20:00.000517+0300 mon.mon-01 [ERR]     pg 3.32 is stuck undersized for 21m, current state active+undersized, last acting [5,0]
2024-01-30T17:20:00.000523+0300 mon.mon-01 [ERR]     pg 3.33 is stuck undersized for 21m, current state active+undersized, last acting [5,0]
2024-01-30T17:20:00.000529+0300 mon.mon-01 [ERR]     pg 3.34 is stuck undersized for 21m, current state active+undersized, last acting [4,2]
2024-01-30T17:20:00.000535+0300 mon.mon-01 [ERR]     pg 3.35 is stuck undersized for 21m, current state active+undersized, last acting [0,2]
2024-01-30T17:20:00.000540+0300 mon.mon-01 [ERR]     pg 3.36 is stuck undersized for 21m, current state active+undersized, last acting [0,5]
2024-01-30T17:20:00.000546+0300 mon.mon-01 [ERR]     pg 3.37 is stuck undersized for 21m, current state active+undersized, last acting [0,5]
2024-01-30T17:20:00.000552+0300 mon.mon-01 [ERR]     pg 3.38 is stuck undersized for 21m, current state active+undersized, last acting [5,0]
2024-01-30T17:20:00.000558+0300 mon.mon-01 [ERR]     pg 3.39 is stuck undersized for 21m, current state active+undersized, last acting [0,5]
2024-01-30T17:20:00.000563+0300 mon.mon-01 [ERR]     pg 3.3a is stuck undersized for 21m, current state active+undersized, last acting [0,2]
2024-01-30T17:20:00.000568+0300 mon.mon-01 [ERR]     pg 3.3b is stuck undersized for 21m, current state active+undersized, last acting [2,0]
2024-01-30T17:20:00.000575+0300 mon.mon-01 [ERR]     pg 3.3c is stuck undersized for 21m, current state active+undersized, last acting [4,2]
2024-01-30T17:20:00.000582+0300 mon.mon-01 [ERR]     pg 3.3d is stuck undersized for 21m, current state active+undersized, last acting [5,4]
2024-01-30T17:20:00.000587+0300 mon.mon-01 [ERR]     pg 3.3e is stuck undersized for 21m, current state active+undersized, last acting [5,0]
2024-01-30T17:20:00.000592+0300 mon.mon-01 [ERR]     pg 3.3f is stuck undersized for 21m, current state active+undersized, last acting [4,2]
2024-01-30T17:20:00.000598+0300 mon.mon-01 [ERR]     pg 4.1 is stuck undersized for 21m, current state active+undersized, last acting [4,2]
2024-01-30T17:20:00.000603+0300 mon.mon-01 [ERR]     pg 4.8 is stuck undersized for 21m, current state active+undersized, last acting [0,5]
2024-01-30T17:20:00.000608+0300 mon.mon-01 [ERR]     pg 4.a is stuck undersized for 21m, current state active+undersized, last acting [4,5]
2024-01-30T17:20:00.000613+0300 mon.mon-01 [ERR]     pg 4.b is stuck undersized for 21m, current state active+undersized+degraded, last acting [2,4]
2024-01-30T17:20:00.000619+0300 mon.mon-01 [ERR]     pg 4.c is stuck undersized for 21m, current state active+undersized+degraded, last acting [4,5]
2024-01-30T17:20:00.000625+0300 mon.mon-01 [ERR]     pg 4.d is stuck undersized for 21m, current state active+undersized+degraded, last acting [4,5]
2024-01-30T17:20:00.000631+0300 mon.mon-01 [ERR]     pg 4.e is stuck undersized for 21m, current state active+undersized+degraded, last acting [4,2]
2024-01-30T17:20:00.000636+0300 mon.mon-01 [ERR]     pg 4.f is stuck undersized for 21m, current state active+undersized+degraded, last acting [2,4]
2024-01-30T17:30:00.000132+0300 mon.mon-01 [ERR] overall HEALTH_ERR Failed to apply 3 service(s): ceph-exporter,crash,node-exporter; 1 hosts fail cephadm check; 1 stray host(s) with 2 daemon(s) not managed by cephadm; Module 'cephadm' has failed: 'osd-01.example.com'; Degraded data redundancy: 45/135 objects degraded (33.333%), 32 pgs degraded, 113 pgs undersized
2024-01-30T17:31:40.164414+0300 mon.mon-01 [WRN] Health check failed: 1 osds exist in the crush map but not in the osdmap (OSD_ORPHAN)
2024-01-30T17:40:00.000187+0300 mon.mon-01 [ERR] Health detail: HEALTH_ERR Failed to apply 3 service(s): ceph-exporter,crash,node-exporter; 1 hosts fail cephadm check; 1 stray host(s) with 2 daemon(s) not managed by cephadm; Module 'cephadm' has failed: 'osd-01.example.com'; 1 osds exist in the crush map but not in the osdmap; Degraded data redundancy: 45/135 objects degraded (33.333%), 32 pgs degraded, 113 pgs undersized
2024-01-30T17:40:00.000214+0300 mon.mon-01 [ERR] [WRN] CEPHADM_APPLY_SPEC_FAIL: Failed to apply 3 service(s): ceph-exporter,crash,node-exporter
2024-01-30T17:40:00.000219+0300 mon.mon-01 [ERR]     ceph-exporter: 'osd-01.example.com'
2024-01-30T17:40:00.000223+0300 mon.mon-01 [ERR]     crash: 'osd-01.example.com'
2024-01-30T17:40:00.000227+0300 mon.mon-01 [ERR]     node-exporter: 'osd-01.example.com'
2024-01-30T17:40:00.000231+0300 mon.mon-01 [ERR] [WRN] CEPHADM_HOST_CHECK_FAILED: 1 hosts fail cephadm check
2024-01-30T17:40:00.000235+0300 mon.mon-01 [ERR]     host osd-01.example.com (10.10.10.13) failed check: Can't communicate with remote host `10.10.10.13`, possibly because the host is not reachable or python3 is not installed on the host. [Errno 110] Connect call failed ('10.10.10.13', 22)
2024-01-30T17:40:00.000240+0300 mon.mon-01 [ERR] [WRN] CEPHADM_STRAY_HOST: 1 stray host(s) with 2 daemon(s) not managed by cephadm
2024-01-30T17:40:00.000244+0300 mon.mon-01 [ERR]     stray host osd-01.example.com has 2 stray daemons: ['osd.1', 'osd.3']
2024-01-30T17:40:00.000249+0300 mon.mon-01 [ERR] [ERR] MGR_MODULE_ERROR: Module 'cephadm' has failed: 'osd-01.example.com'
2024-01-30T17:40:00.000253+0300 mon.mon-01 [ERR]     Module 'cephadm' has failed: 'osd-01.example.com'
2024-01-30T17:40:00.000257+0300 mon.mon-01 [ERR] [WRN] OSD_ORPHAN: 1 osds exist in the crush map but not in the osdmap
2024-01-30T17:40:00.000261+0300 mon.mon-01 [ERR]     osd.1 exists in crush map but not in osdmap
2024-01-30T17:40:00.000265+0300 mon.mon-01 [ERR] [WRN] PG_DEGRADED: Degraded data redundancy: 45/135 objects degraded (33.333%), 32 pgs degraded, 113 pgs undersized
2024-01-30T17:40:00.000272+0300 mon.mon-01 [ERR]     pg 2.8 is stuck undersized for 41m, current state active+undersized, last acting [0,2]
2024-01-30T17:40:00.000276+0300 mon.mon-01 [ERR]     pg 2.9 is stuck undersized for 41m, current state active+undersized+degraded, last acting [5,0]
2024-01-30T17:40:00.000280+0300 mon.mon-01 [ERR]     pg 2.a is stuck undersized for 41m, current state active+undersized, last acting [5,0]
2024-01-30T17:40:00.000284+0300 mon.mon-01 [ERR]     pg 2.b is stuck undersized for 41m, current state active+undersized, last acting [4,2]
2024-01-30T17:40:00.000289+0300 mon.mon-01 [ERR]     pg 2.c is stuck undersized for 41m, current state active+undersized+degraded, last acting [5,0]
2024-01-30T17:40:00.000292+0300 mon.mon-01 [ERR]     pg 2.d is stuck undersized for 41m, current state active+undersized, last acting [0,5]
2024-01-30T17:40:00.000297+0300 mon.mon-01 [ERR]     pg 2.e is stuck undersized for 41m, current state active+undersized, last acting [2,0]
2024-01-30T17:40:00.000301+0300 mon.mon-01 [ERR]     pg 3.8 is stuck undersized for 41m, current state active+undersized, last acting [5,0]
2024-01-30T17:40:00.000304+0300 mon.mon-01 [ERR]     pg 3.9 is stuck undersized for 41m, current state active+undersized, last acting [0,2]
2024-01-30T17:40:00.000308+0300 mon.mon-01 [ERR]     pg 3.a is stuck undersized for 41m, current state active+undersized, last acting [0,5]
2024-01-30T17:40:00.000312+0300 mon.mon-01 [ERR]     pg 3.b is stuck undersized for 41m, current state active+undersized, last acting [2,4]
2024-01-30T17:40:00.000316+0300 mon.mon-01 [ERR]     pg 3.c is stuck undersized for 41m, current state active+undersized, last acting [0,5]
2024-01-30T17:40:00.000320+0300 mon.mon-01 [ERR]     pg 3.d is stuck undersized for 41m, current state active+undersized, last acting [0,2]
2024-01-30T17:40:00.000324+0300 mon.mon-01 [ERR]     pg 3.f is stuck undersized for 41m, current state active+undersized, last acting [0,2]
2024-01-30T17:40:00.000328+0300 mon.mon-01 [ERR]     pg 3.22 is stuck undersized for 41m, current state active+undersized, last acting [5,4]
2024-01-30T17:40:00.000332+0300 mon.mon-01 [ERR]     pg 3.24 is stuck undersized for 41m, current state active+undersized, last acting [2,0]
2024-01-30T17:40:00.000336+0300 mon.mon-01 [ERR]     pg 3.25 is stuck undersized for 41m, current state active+undersized, last acting [5,0]
2024-01-30T17:40:00.000339+0300 mon.mon-01 [ERR]     pg 3.26 is stuck undersized for 41m, current state active+undersized, last acting [4,5]
2024-01-30T17:40:00.000343+0300 mon.mon-01 [ERR]     pg 3.27 is stuck undersized for 41m, current state active+undersized, last acting [5,4]
2024-01-30T17:40:00.000348+0300 mon.mon-01 [ERR]     pg 3.28 is stuck undersized for 41m, current state active+undersized, last acting [5,0]
2024-01-30T17:40:00.000352+0300 mon.mon-01 [ERR]     pg 3.29 is stuck undersized for 41m, current state active+undersized, last acting [5,0]
2024-01-30T17:40:00.000355+0300 mon.mon-01 [ERR]     pg 3.2a is stuck undersized for 41m, current state active+undersized, last acting [4,2]
2024-01-30T17:40:00.000359+0300 mon.mon-01 [ERR]     pg 3.2b is stuck undersized for 41m, current state active+undersized, last acting [2,0]
2024-01-30T17:40:00.000363+0300 mon.mon-01 [ERR]     pg 3.2c is stuck undersized for 41m, current state active+undersized, last acting [4,5]
2024-01-30T17:40:00.000367+0300 mon.mon-01 [ERR]     pg 3.2d is stuck undersized for 41m, current state active+undersized, last acting [5,4]
2024-01-30T17:40:00.000371+0300 mon.mon-01 [ERR]     pg 3.2e is stuck undersized for 41m, current state active+undersized, last acting [2,0]
2024-01-30T17:40:00.000374+0300 mon.mon-01 [ERR]     pg 3.2f is stuck undersized for 41m, current state active+undersized, last acting [0,5]
2024-01-30T17:40:00.000378+0300 mon.mon-01 [ERR]     pg 3.30 is stuck undersized for 41m, current state active+undersized+degraded, last acting [4,2]
2024-01-30T17:40:00.000382+0300 mon.mon-01 [ERR]     pg 3.31 is stuck undersized for 41m, current state active+undersized, last acting [5,0]
2024-01-30T17:40:00.000386+0300 mon.mon-01 [ERR]     pg 3.32 is stuck undersized for 41m, current state active+undersized, last acting [5,0]
2024-01-30T17:40:00.000390+0300 mon.mon-01 [ERR]     pg 3.33 is stuck undersized for 41m, current state active+undersized, last acting [5,0]
2024-01-30T17:40:00.000394+0300 mon.mon-01 [ERR]     pg 3.34 is stuck undersized for 41m, current state active+undersized, last acting [4,2]
2024-01-30T17:40:00.000398+0300 mon.mon-01 [ERR]     pg 3.35 is stuck undersized for 41m, current state active+undersized, last acting [0,2]
2024-01-30T17:40:00.000401+0300 mon.mon-01 [ERR]     pg 3.36 is stuck undersized for 41m, current state active+undersized, last acting [0,5]
2024-01-30T17:40:00.000405+0300 mon.mon-01 [ERR]     pg 3.37 is stuck undersized for 41m, current state active+undersized, last acting [0,5]
2024-01-30T17:40:00.000410+0300 mon.mon-01 [ERR]     pg 3.38 is stuck undersized for 41m, current state active+undersized, last acting [5,0]
2024-01-30T17:40:00.000413+0300 mon.mon-01 [ERR]     pg 3.39 is stuck undersized for 41m, current state active+undersized, last acting [0,5]
2024-01-30T17:40:00.000417+0300 mon.mon-01 [ERR]     pg 3.3a is stuck undersized for 41m, current state active+undersized, last acting [0,2]
2024-01-30T17:40:00.000421+0300 mon.mon-01 [ERR]     pg 3.3b is stuck undersized for 41m, current state active+undersized, last acting [2,0]
2024-01-30T17:40:00.000425+0300 mon.mon-01 [ERR]     pg 3.3c is stuck undersized for 41m, current state active+undersized, last acting [4,2]
2024-01-30T17:40:00.000429+0300 mon.mon-01 [ERR]     pg 3.3d is stuck undersized for 41m, current state active+undersized, last acting [5,4]
2024-01-30T17:40:00.000435+0300 mon.mon-01 [ERR]     pg 3.3e is stuck undersized for 41m, current state active+undersized, last acting [5,0]
2024-01-30T17:40:00.000440+0300 mon.mon-01 [ERR]     pg 3.3f is stuck undersized for 41m, current state active+undersized, last acting [4,2]
2024-01-30T17:40:00.000446+0300 mon.mon-01 [ERR]     pg 4.1 is stuck undersized for 41m, current state active+undersized, last acting [4,2]
2024-01-30T17:40:00.000452+0300 mon.mon-01 [ERR]     pg 4.8 is stuck undersized for 41m, current state active+undersized, last acting [0,5]
2024-01-30T17:40:00.000457+0300 mon.mon-01 [ERR]     pg 4.a is stuck undersized for 41m, current state active+undersized, last acting [4,5]
2024-01-30T17:40:00.000464+0300 mon.mon-01 [ERR]     pg 4.b is stuck undersized for 41m, current state active+undersized+degraded, last acting [2,4]
2024-01-30T17:40:00.000470+0300 mon.mon-01 [ERR]     pg 4.c is stuck undersized for 41m, current state active+undersized+degraded, last acting [4,5]
2024-01-30T17:40:00.000475+0300 mon.mon-01 [ERR]     pg 4.d is stuck undersized for 41m, current state active+undersized+degraded, last acting [4,5]
2024-01-30T17:40:00.000481+0300 mon.mon-01 [ERR]     pg 4.e is stuck undersized for 41m, current state active+undersized+degraded, last acting [4,2]
2024-01-30T17:40:00.000486+0300 mon.mon-01 [ERR]     pg 4.f is stuck undersized for 41m, current state active+undersized+degraded, last acting [2,4]
2024-01-30T17:50:00.000153+0300 mon.mon-01 [ERR] overall HEALTH_ERR Failed to apply 3 service(s): ceph-exporter,crash,node-exporter; 1 hosts fail cephadm check; 1 stray host(s) with 2 daemon(s) not managed by cephadm; Module 'cephadm' has failed: 'osd-01.example.com'; 1 osds exist in the crush map but not in the osdmap; Degraded data redundancy: 45/135 objects degraded (33.333%), 32 pgs degraded, 113 pgs undersized
2024-01-30T18:00:00.000114+0300 mon.mon-01 [ERR] overall HEALTH_ERR Failed to apply 3 service(s): ceph-exporter,crash,node-exporter; 1 hosts fail cephadm check; 1 stray host(s) with 2 daemon(s) not managed by cephadm; Module 'cephadm' has failed: 'osd-01.example.com'; 1 osds exist in the crush map but not in the osdmap; Degraded data redundancy: 45/135 objects degraded (33.333%), 32 pgs degraded, 113 pgs undersized
2024-01-30T18:10:00.000134+0300 mon.mon-01 [ERR] overall HEALTH_ERR Failed to apply 3 service(s): ceph-exporter,crash,node-exporter; 1 hosts fail cephadm check; 1 stray host(s) with 2 daemon(s) not managed by cephadm; Module 'cephadm' has failed: 'osd-01.example.com'; 1 osds exist in the crush map but not in the osdmap; Degraded data redundancy: 45/135 objects degraded (33.333%), 32 pgs degraded, 113 pgs undersized
2024-01-30T18:13:02.721512+0300 mon.mon-01 [INF] Health check cleared: OSD_ORPHAN (was: 1 osds exist in the crush map but not in the osdmap)
2024-01-30T18:14:58.470989+0300 mon.mon-01 [WRN] Health check failed: 1 osds exist in the crush map but not in the osdmap (OSD_ORPHAN)
2024-01-30T18:15:32.855011+0300 mon.mon-01 [WRN] Health check update: 2 osds exist in the crush map but not in the osdmap (OSD_ORPHAN)
2024-01-30T18:16:05.115630+0300 mon.mon-01 [WRN] Health check update: 1 osds exist in the crush map but not in the osdmap (OSD_ORPHAN)
2024-01-30T18:16:19.481256+0300 mon.mon-01 [WRN] Health check update: 2 osds exist in the crush map but not in the osdmap (OSD_ORPHAN)
2024-01-30T18:20:00.000160+0300 mon.mon-01 [ERR] Health detail: HEALTH_ERR Failed to apply 3 service(s): ceph-exporter,crash,node-exporter; 1 hosts fail cephadm check; 1 stray host(s) with 2 daemon(s) not managed by cephadm; Module 'cephadm' has failed: 'osd-01.example.com'; 2 osds exist in the crush map but not in the osdmap; Degraded data redundancy: 45/135 objects degraded (33.333%), 32 pgs degraded, 113 pgs undersized
2024-01-30T18:20:00.000190+0300 mon.mon-01 [ERR] [WRN] CEPHADM_APPLY_SPEC_FAIL: Failed to apply 3 service(s): ceph-exporter,crash,node-exporter
2024-01-30T18:20:00.000194+0300 mon.mon-01 [ERR]     ceph-exporter: 'osd-01.example.com'
2024-01-30T18:20:00.000198+0300 mon.mon-01 [ERR]     crash: 'osd-01.example.com'
2024-01-30T18:20:00.000203+0300 mon.mon-01 [ERR]     node-exporter: 'osd-01.example.com'
2024-01-30T18:20:00.000207+0300 mon.mon-01 [ERR] [WRN] CEPHADM_HOST_CHECK_FAILED: 1 hosts fail cephadm check
2024-01-30T18:20:00.000212+0300 mon.mon-01 [ERR]     host osd-01.example.com (10.10.10.13) failed check: Can't communicate with remote host `10.10.10.13`, possibly because the host is not reachable or python3 is not installed on the host. [Errno 110] Connect call failed ('10.10.10.13', 22)
2024-01-30T18:20:00.000216+0300 mon.mon-01 [ERR] [WRN] CEPHADM_STRAY_HOST: 1 stray host(s) with 2 daemon(s) not managed by cephadm
2024-01-30T18:20:00.000219+0300 mon.mon-01 [ERR]     stray host osd-01.example.com has 2 stray daemons: ['osd.1', 'osd.3']
2024-01-30T18:20:00.000224+0300 mon.mon-01 [ERR] [ERR] MGR_MODULE_ERROR: Module 'cephadm' has failed: 'osd-01.example.com'
2024-01-30T18:20:00.000228+0300 mon.mon-01 [ERR]     Module 'cephadm' has failed: 'osd-01.example.com'
2024-01-30T18:20:00.000232+0300 mon.mon-01 [ERR] [WRN] OSD_ORPHAN: 2 osds exist in the crush map but not in the osdmap
2024-01-30T18:20:00.000236+0300 mon.mon-01 [ERR]     osd.1 exists in crush map but not in osdmap
2024-01-30T18:20:00.000240+0300 mon.mon-01 [ERR]     osd.3 exists in crush map but not in osdmap
2024-01-30T18:20:00.000244+0300 mon.mon-01 [ERR] [WRN] PG_DEGRADED: Degraded data redundancy: 45/135 objects degraded (33.333%), 32 pgs degraded, 113 pgs undersized
2024-01-30T18:20:00.000248+0300 mon.mon-01 [ERR]     pg 2.8 is stuck undersized for 81m, current state active+undersized, last acting [0,2]
2024-01-30T18:20:00.000252+0300 mon.mon-01 [ERR]     pg 2.9 is stuck undersized for 81m, current state active+undersized+degraded, last acting [5,0]
2024-01-30T18:20:00.000256+0300 mon.mon-01 [ERR]     pg 2.a is stuck undersized for 81m, current state active+undersized, last acting [5,0]
2024-01-30T18:20:00.000260+0300 mon.mon-01 [ERR]     pg 2.b is stuck undersized for 81m, current state active+undersized, last acting [4,2]
2024-01-30T18:20:00.000264+0300 mon.mon-01 [ERR]     pg 2.c is stuck undersized for 81m, current state active+undersized+degraded, last acting [5,0]
2024-01-30T18:20:00.000268+0300 mon.mon-01 [ERR]     pg 2.d is stuck undersized for 81m, current state active+undersized, last acting [0,5]
2024-01-30T18:20:00.000271+0300 mon.mon-01 [ERR]     pg 2.e is stuck undersized for 81m, current state active+undersized, last acting [2,0]
2024-01-30T18:20:00.000275+0300 mon.mon-01 [ERR]     pg 3.8 is stuck undersized for 81m, current state active+undersized, last acting [5,0]
2024-01-30T18:20:00.000279+0300 mon.mon-01 [ERR]     pg 3.9 is stuck undersized for 81m, current state active+undersized, last acting [0,2]
2024-01-30T18:20:00.000283+0300 mon.mon-01 [ERR]     pg 3.a is stuck undersized for 81m, current state active+undersized, last acting [0,5]
2024-01-30T18:20:00.000287+0300 mon.mon-01 [ERR]     pg 3.b is stuck undersized for 81m, current state active+undersized, last acting [2,4]
2024-01-30T18:20:00.000291+0300 mon.mon-01 [ERR]     pg 3.c is stuck undersized for 81m, current state active+undersized, last acting [0,5]
2024-01-30T18:20:00.000295+0300 mon.mon-01 [ERR]     pg 3.d is stuck undersized for 81m, current state active+undersized, last acting [0,2]
2024-01-30T18:20:00.000299+0300 mon.mon-01 [ERR]     pg 3.f is stuck undersized for 81m, current state active+undersized, last acting [0,2]
2024-01-30T18:20:00.000302+0300 mon.mon-01 [ERR]     pg 3.22 is stuck undersized for 81m, current state active+undersized, last acting [5,4]
2024-01-30T18:20:00.000307+0300 mon.mon-01 [ERR]     pg 3.24 is stuck undersized for 81m, current state active+undersized, last acting [2,0]
2024-01-30T18:20:00.000311+0300 mon.mon-01 [ERR]     pg 3.25 is stuck undersized for 81m, current state active+undersized, last acting [5,0]
2024-01-30T18:20:00.000315+0300 mon.mon-01 [ERR]     pg 3.26 is stuck undersized for 81m, current state active+undersized, last acting [4,5]
2024-01-30T18:20:00.000319+0300 mon.mon-01 [ERR]     pg 3.27 is stuck undersized for 81m, current state active+undersized, last acting [5,4]
2024-01-30T18:20:00.000322+0300 mon.mon-01 [ERR]     pg 3.28 is stuck undersized for 81m, current state active+undersized, last acting [5,0]
2024-01-30T18:20:00.000326+0300 mon.mon-01 [ERR]     pg 3.29 is stuck undersized for 81m, current state active+undersized, last acting [5,0]
2024-01-30T18:20:00.000330+0300 mon.mon-01 [ERR]     pg 3.2a is stuck undersized for 81m, current state active+undersized, last acting [4,2]
2024-01-30T18:20:00.000335+0300 mon.mon-01 [ERR]     pg 3.2b is stuck undersized for 81m, current state active+undersized, last acting [2,0]
2024-01-30T18:20:00.000338+0300 mon.mon-01 [ERR]     pg 3.2c is stuck undersized for 81m, current state active+undersized, last acting [4,5]
2024-01-30T18:20:00.000342+0300 mon.mon-01 [ERR]     pg 3.2d is stuck undersized for 81m, current state active+undersized, last acting [5,4]
2024-01-30T18:20:00.000346+0300 mon.mon-01 [ERR]     pg 3.2e is stuck undersized for 81m, current state active+undersized, last acting [2,0]
2024-01-30T18:20:00.000349+0300 mon.mon-01 [ERR]     pg 3.2f is stuck undersized for 81m, current state active+undersized, last acting [0,5]
2024-01-30T18:20:00.000353+0300 mon.mon-01 [ERR]     pg 3.30 is stuck undersized for 81m, current state active+undersized+degraded, last acting [4,2]
2024-01-30T18:20:00.000360+0300 mon.mon-01 [ERR]     pg 3.31 is stuck undersized for 81m, current state active+undersized, last acting [5,0]
2024-01-30T18:20:00.000363+0300 mon.mon-01 [ERR]     pg 3.32 is stuck undersized for 81m, current state active+undersized, last acting [5,0]
2024-01-30T18:20:00.000367+0300 mon.mon-01 [ERR]     pg 3.33 is stuck undersized for 81m, current state active+undersized, last acting [5,0]
2024-01-30T18:20:00.000371+0300 mon.mon-01 [ERR]     pg 3.34 is stuck undersized for 81m, current state active+undersized, last acting [4,2]
2024-01-30T18:20:00.000375+0300 mon.mon-01 [ERR]     pg 3.35 is stuck undersized for 81m, current state active+undersized, last acting [0,2]
2024-01-30T18:20:00.000378+0300 mon.mon-01 [ERR]     pg 3.36 is stuck undersized for 81m, current state active+undersized, last acting [0,5]
2024-01-30T18:20:00.000382+0300 mon.mon-01 [ERR]     pg 3.37 is stuck undersized for 81m, current state active+undersized, last acting [0,5]
2024-01-30T18:20:00.000393+0300 mon.mon-01 [ERR]     pg 3.38 is stuck undersized for 81m, current state active+undersized, last acting [5,0]
2024-01-30T18:20:00.000397+0300 mon.mon-01 [ERR]     pg 3.39 is stuck undersized for 81m, current state active+undersized, last acting [0,5]
2024-01-30T18:20:00.000401+0300 mon.mon-01 [ERR]     pg 3.3a is stuck undersized for 81m, current state active+undersized, last acting [0,2]
2024-01-30T18:20:00.000404+0300 mon.mon-01 [ERR]     pg 3.3b is stuck undersized for 81m, current state active+undersized, last acting [2,0]
2024-01-30T18:20:00.000408+0300 mon.mon-01 [ERR]     pg 3.3c is stuck undersized for 81m, current state active+undersized, last acting [4,2]
2024-01-30T18:20:00.000412+0300 mon.mon-01 [ERR]     pg 3.3d is stuck undersized for 81m, current state active+undersized, last acting [5,4]
2024-01-30T18:20:00.000416+0300 mon.mon-01 [ERR]     pg 3.3e is stuck undersized for 81m, current state active+undersized, last acting [5,0]
2024-01-30T18:20:00.000420+0300 mon.mon-01 [ERR]     pg 3.3f is stuck undersized for 81m, current state active+undersized, last acting [4,2]
2024-01-30T18:20:00.000424+0300 mon.mon-01 [ERR]     pg 4.1 is stuck undersized for 81m, current state active+undersized, last acting [4,2]
2024-01-30T18:20:00.000428+0300 mon.mon-01 [ERR]     pg 4.8 is stuck undersized for 81m, current state active+undersized, last acting [0,5]
2024-01-30T18:20:00.000432+0300 mon.mon-01 [ERR]     pg 4.a is stuck undersized for 81m, current state active+undersized, last acting [4,5]
2024-01-30T18:20:00.000436+0300 mon.mon-01 [ERR]     pg 4.b is stuck undersized for 81m, current state active+undersized+degraded, last acting [2,4]
2024-01-30T18:20:00.000439+0300 mon.mon-01 [ERR]     pg 4.c is stuck undersized for 81m, current state active+undersized+degraded, last acting [4,5]
2024-01-30T18:20:00.000444+0300 mon.mon-01 [ERR]     pg 4.d is stuck undersized for 81m, current state active+undersized+degraded, last acting [4,5]
2024-01-30T18:20:00.000447+0300 mon.mon-01 [ERR]     pg 4.e is stuck undersized for 81m, current state active+undersized+degraded, last acting [4,2]
2024-01-30T18:20:00.000567+0300 mon.mon-01 [ERR]     pg 4.f is stuck undersized for 81m, current state active+undersized+degraded, last acting [2,4]
2024-01-30T18:30:00.000128+0300 mon.mon-01 [ERR] overall HEALTH_ERR Failed to apply 3 service(s): ceph-exporter,crash,node-exporter; 1 hosts fail cephadm check; 1 stray host(s) with 2 daemon(s) not managed by cephadm; Module 'cephadm' has failed: 'osd-01.example.com'; 2 osds exist in the crush map but not in the osdmap; Degraded data redundancy: 45/135 objects degraded (33.333%), 32 pgs degraded, 113 pgs undersized

```