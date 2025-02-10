#!/bin/bash
 
BASEFILE="basesystem.txt"
 
if [ ! -f "$BASEFILE" ]; then
    echo "❌ Fehler: Die Datei '$BASEFILE' wurde nicht gefunden!"
    exit 1
fi
 
echo "\n========================================"
echo " 🔍 System-Überprüfung auf Abweichungen "
echo "========================================"
 
# 1️⃣ Installierte Pakete überprüfen
echo "\n========================================"
echo " 1️⃣ Installierte Pakete außerhalb der Standardinstallation "
echo "========================================"
if [ -f /var/lib/dpkg/status ]; then
    CURRENT_PACKAGES=$(mktemp)
    dpkg --get-selections | awk '{print $1}' | sort > "$CURRENT_PACKAGES"
    comm -23 "$CURRENT_PACKAGES" <(grep -v '.service' "$BASEFILE" | sort)
    rm "$CURRENT_PACKAGES"
elif command -v rpm &> /dev/null; then
    CURRENT_PACKAGES=$(mktemp)
    rpm -qa --qf '%{NAME}\n' | sort > "$CURRENT_PACKAGES"
    comm -23 "$CURRENT_PACKAGES" <(grep -v '.service' "$BASEFILE" | sort)
    rm "$CURRENT_PACKAGES"
fi
 
# 2️⃣ Benutzerdefinierte Cronjobs prüfen
echo "\n========================================"
echo " 2️⃣ Benutzerdefinierte Cronjobs "
echo "========================================"
for user in $(cut -f1 -d: /etc/passwd); do
    crontab -u "$user" -l 2>/dev/null | grep -v '^#' && echo " -> Benutzer: $user"
done
 
# 3️⃣ Laufende benutzerdefinierte Prozesse
echo "\n========================================"
echo " 3️⃣ Laufende benutzerdefinierte Prozesse "
echo "========================================"
ps aux | awk '$1 !~ /^(root|systemd|nobody)$/' | awk '{print $1, $11}' | sort -u
 
# 4️⃣ Docker-Container auflisten (falls installiert)
echo "\n========================================"
echo " 4️⃣ Laufende Docker-Container "
echo "========================================"
if command -v docker &> /dev/null; then
    docker ps --format "{{.Names}} - {{.Image}}"
else
    echo "Docker ist nicht installiert oder läuft nicht."
fi
 
# 5️⃣ Nicht-Standard Systemd-Dienste überprüfen
echo "\n========================================"
echo " 5️⃣ Nicht-Standard Systemd-Dienste "
echo "========================================"
 
CURRENT_SERVICES=$(mktemp)
systemctl list-units --type=service --all --no-pager --no-legend | awk '{print $1}' | grep '\.service' | sort > "$CURRENT_SERVICES"
 
BASE_SERVICES=$(grep '\.service' "$BASEFILE")
 
while read -r service; do
    [[ -z "$service" ]] && continue
    matched=0
    for base_service in $BASE_SERVICES; do
        if [[ "${service:0:10}" == "${base_service:0:10}" ]]; then
            matched=1
            break
        fi
    done
    if [[ $matched -eq 0 ]]; then
        echo "$service"
    fi
done < "$CURRENT_SERVICES"
 
rm "$CURRENT_SERVICES"
 
# 6️⃣ Nicht-Standard Benutzer auflisten
echo "\n========================================"
echo " 6️⃣ Nicht-Standard Benutzer "
echo "========================================"
STANDARD_USERS=(
    root daemon bin sys sync games man lp mail news uucp proxy www-data backup list irc _apt nobody
    systemd-network systemd-timesync dhcpcd messagebus systemd-resolve pollinate polkitd syslog uuidd
    tcpdump tss landscape fwupd-refresh usbmux sshd
)
 
CURRENT_USERS=$(cut -d: -f1 /etc/passwd)
 
echo "$CURRENT_USERS" | while read user; do
    if [[ ! " ${STANDARD_USERS[@]} " =~ " $user " ]]; then
        echo "$user"
    fi
done
 
echo "\n========================================"
echo " ✅ Überprüfung abgeschlossen! "
echo "========================================"
