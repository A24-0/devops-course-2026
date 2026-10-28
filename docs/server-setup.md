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

## 8. Веб-сервер
- Пакет: nginx (Ubuntu 24.04, из репозитория дистрибутива); служба nginx включена в автозапуск
- Конфигурация ресурса: /etc/nginx/sites-available/devops-site, активирована ссылкой в /etc/nginx/sites-enabled/; стандартный ресурс default отключён (ссылка удалена)
- Блок 1: порт 80, server_name devops.local, return 301 на https://$host$request_uri
- Блок 2: порт 443 ssl (IPv4 и IPv6), TLSv1.2 и TLSv1.3, root /var/www/devops-site, index index.html, error_page 404 /404.html
- Журналы: /var/log/nginx/devops-site.access.log и /var/log/nginx/devops-site.error.log
- Каталог ресурса: /var/www/devops-site, владелец devops:devops, права 755 для каталога и 644 для файлов (модель «владелец пишет, веб-сервер читает»); содержимое доставляется сценарием scripts/deploy.sh (rsync -avz --delete, права D755/F644 задаются в промежуточной копии: rsync macOS не поддерживает --chmod)
- Сертификат: /etc/ssl/certs/devops.crt, права 644; закрытый ключ: /etc/ssl/private/devops.key, права 600, владелец root
- Команда формирования сертификата (срок действия 365 дней, поле SAN):
  sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/devops.key -out /etc/ssl/certs/devops.crt -subj "/CN=devops.local" -addext "subjectAltName=DNS:devops.local"
- Правила ufw: порты 80/tcp и 443/tcp разрешены ещё в ПР № 5, новых правил не добавлялось
- Заголовок HSTS не применяется (самоподписанный сертификат)
- Применение конфигурации: sudo nginx -t && sudo systemctl reload nginx
- Доверие клиента: сертификат копируется на хост (scp devops:/etc/ssl/certs/devops.crt ~/devops.crt), проверка curl --cacert ~/devops.crt
- Снимок состояния: 04-nginx-https
