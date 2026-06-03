#!/usr/bin/bash
# See 'man 8 iptables-extensions'


#-----------------------------------------------------------------------------
# Удаляем все правила
iptables -t filter -F && iptables -t nat -F
# Удаляем все цепочки
iptables -t filter -X && iptables -t nat -X
# Сбрасываем счетчики
iptables -t filter -Z && iptables -t nat -Z


#-----------------------------------------------------------------------------
# Обрабатываем ICMP пакеты
iptables -N icmp_process
# Блокируем фрагментированные ICMP пакеты
iptables -A icmp_process -p icmp -f -j DROP
# Блокируем чрезмерно большие ICMP пакеты
iptables -A icmp_process -p icmp -m length --length 1500: -j DROP
# Пропускаем ICMP Echo Reply
iptables -A icmp_process -p icmp --icmp-type  0 -j RETURN
# Пропускаем ICMP Destination Unreachable
iptables -A icmp_process -p icmp --icmp-type  3 -j RETURN
# Пропускаем ICMP Echo Request
iptables -A icmp_process -p icmp --icmp-type  8 -j RETURN
# Пропускаем ICMP Time Exceeded
iptables -A icmp_process -p icmp --icmp-type 11 -j RETURN
# Блокируем остальные ICMP пакеты
iptables -A icmp_process -j DROP

#-----------------------------------------------------------------------------
# Обрабатываем TCP пакеты
iptables -N tcp_process
# Блокируем попытки открыть TCP соединение TCP пакетом с некорректными флагами
iptables -A tcp_process -m conntrack --ctstate NEW,RELATED -p tcp ! --syn -j DROP
# Блокируем попытки открыть TCP соединение фрагментированным TCP пакетом
iptables -A tcp_process -m conntrack --ctstate NEW,RELATED -p tcp -f -j DROP
# Пропускаем остальные TCP пакеты
iptables -A tcp_process -j RETURN


#-----------------------------------------------------------------------------
# Обрабатываем обнаруженную атаку
iptables -N dos_drop
# Добавляем адрес в черный список
iptables -A dos_drop -m recent --set --name dos_detain_zone
# Блокируем пакеты
iptables -A dos_drop -j DROP

# Производим частотный анализ входящих соединений
iptables -N dos_process
# Блокируем, если выполнено хотя бы одно из следующих условий:
# - за последние  50 секунд с одного адреса было 10 или более новых соединений (0.2);
iptables -A dos_process -m recent --name dos --update --seconds  50 --hitcount 10 -j dos_drop
# - за последние 100 секунд с одного адреса было 15 или более новых соединений (0.15);
iptables -A dos_process -m recent --name dos --update --seconds 100 --hitcount 15 -j dos_drop
# - за последние 200 секунд с одного адреса было 20 или более новых соединений (0.1);
iptables -A dos_process -m recent --name dos --update --seconds 200 --hitcount 20 -j dos_drop
# - за последние 500 секунд с одного адреса было 25 или более новых соединений (0.05).
iptables -A dos_process -m recent --name dos --update --seconds 500 --hitcount 25 -j dos_drop
# Блокируем, если за последние 24 часа были превышены ограничения
iptables -A dos_process -m recent --name dos_detain_zone --rcheck --seconds 86400 -j dos_drop
# Регистрируем для анализа и пропускаем остальные пакеты
iptables -A dos_process -m recent --set --name dos -j RETURN


#-----------------------------------------------------------------------------
# Блокируем пакеты без привязки к какому-либо соединению
iptables -A INPUT -m conntrack --ctstate INVALID -j DROP

#-----------------------------------------------------------------------------
# Разрешаем все пакеты через интерфейс lo
iptables -A INPUT -i lo -j ACCEPT

#-----------------------------------------------------------------------------
# Обрабатываем пакеты на основе протокола
iptables -A INPUT -p icmp -j icmp_process
iptables -A INPUT -p tcp -j tcp_process

#-----------------------------------------------------------------------------
# Разрешаем все пакеты через существующие соединения
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

#-----------------------------------------------------------------------------
# Блокируем все multicast пакеты
iptables -A INPUT -m addrtype --src-type MULTICAST -j DROP
iptables -A INPUT -m addrtype --dst-type MULTICAST -j DROP

#-----------------------------------------------------------------------------
# Производим анализ попыток атак
iptables -A INPUT -p tcp -j dos_process


#-----------------------------------------------------------------------------
# Заменяем в исходящих пакетах адрес источника на адрес интерфейса
if [ "$(sysctl -n net.ipv4.ip_forward)" -eq 1 ]; then
    while read -r addr name; do
        iptables -t nat -A POSTROUTING -o "${name}" -j SNAT --to-source "${addr%/*}"
    done < <(
        ip -br -4 a|awk '/UP/&&!/ (10|172.(1[6-9]|2[0-9]|3[01])|192.168)\./{print$NF,$1}'
    )
fi
