# Конфигурация виртуальной машины devops-vm

## 1. Параметры машины
- Гипервизор: UTM (QEMU, виртуализация ARM64), гостевая ОС Ubuntu Server 24.04.5 LTS (arm64)
- Оперативная память: 2048 МБ
- Процессор: 2 ядра
- Диск: 25 ГБ, динамически расширяемый (Use an entire disk, LVM)
- Имя узла: devops-vm (FQDN devops-vm.devops.local)

## 2. Сетевые интерфейсы
| Адаптер | Тип | Интерфейс | Адрес | Назначение |
|---|---|---|---|---|
| 1 | NAT (Emulated VLAN) | enp0s1 | 10.0.2.15/24 | доступ в Интернет и к репозиториям пакетов, SSH с хоста через проброс порта |
| 2 | Host-only | enp0s2 | 192.168.128.2/24 | прямой доступ с хоста (веб-сервер в работе № 6) |

Для адаптера 2 создан файл /etc/netplan/60-hostonly.yaml (DHCP), права 600.

## 3. Правило проброса портов
TCP, адрес хоста 127.0.0.1, порт хоста 2222, порт гостя 2222
(изначально 22, изменён после смены порта SSH, шаг 2.4).

## 4. Учётные записи
- student: администратор, создан установщиком; после усиления защиты вход по SSH запрещён (AllowUsers devops)
- devops: группы devops, sudo, users; аутентификация по ключу ed25519 (~/.ssh/authorized_keys, права 700/600), пароль используется только для sudo

## 5. Служба SSH
- Порт: 2222 (ssh.socket отключён, запущен ssh.service)
- Файл конфигурации: /etc/ssh/sshd_config.d/99-hardening.conf, основной файл не изменён, копия /etc/ssh/sshd_config.backup
- Директивы: Port 2222, PermitRootLogin no, PasswordAuthentication no, PubkeyAuthentication yes, PermitEmptyPasswords no, MaxAuthTries 3, LoginGraceTime 30, AllowUsers devops, X11Forwarding no, ClientAliveInterval 300, ClientAliveCountMax 2
- В 50-cloud-init.conf директива PasswordAuthentication закомментирована

## 6. Правила межсетевого экрана
- Политики по умолчанию: deny (incoming), allow (outgoing)
- 2222/tcp LIMIT (SSH rate-limited), 80/tcp ALLOW (HTTP), 443/tcp ALLOW (HTTPS)
- Журналирование: ufw logging medium

## 7. Снимки состояния
2026-10-28 01:39  02-keys-configured
2026-10-28 01:41  forward guest port 22 -> 2222
2026-10-28 01:43  03-ssh-hardened
