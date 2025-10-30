#!/bin/bash
# ===========================================================
#  Wazuh Agent Local Auto Installer (Step-by-Step Verified)
#  Version: 3.0 (Hanel SOC Edition)
#  Author : SOC Hanel
# ===========================================================
set -e

LOCAL_REPO_PATH="/WAZUH-AGENT/*"
CONF_PATH="/var/ossec/etc/ossec.conf"
AGENT_SERVICE="wazuh-agent"

echo "-----------------------------------------------------"
echo "[ Hanel SOC | Wazuh Agent Local Auto Installer v3.0 ]"
echo "-----------------------------------------------------"

# ==== STEP 1: INPUT MANAGER IP ====
while true; do
    read -rp "Nhập địa chỉ IP hoặc hostname của Wazuh Manager: " WAZUH_MANAGER
    if [[ -z "$WAZUH_MANAGER" ]]; then
        echo "[!] Không được để trống IP Manager."
        continue
    fi
    echo "[i] Kiểm tra kết nối tới $WAZUH_MANAGER ..."
    
    if ping -c 1 -W 2 "$WAZUH_MANAGER" >/dev/null 2>&1; then
        echo "[✓] Ping tới $WAZUH_MANAGER thành công."
    else
        echo "[!] Không ping được $WAZUH_MANAGER. Kiểm tra mạng hoặc firewall."
        read -rp "Tiếp tục dù không ping được? (y/N): " ans
        [[ "$ans" =~ ^[Yy]$ ]] || continue
    fi

    # --- kiểm tra port 1514 & 1515 ---
    for port in 1514 1515; do
        echo -n "[i] Kiểm tra TCP port $port ... "
        if timeout 2 bash -c "echo > /dev/tcp/$WAZUH_MANAGER/$port" 2>/dev/null; then
            echo "OK"
        else
            echo "FAIL"
        fi
    done

    read -rp "Xác nhận sử dụng IP Manager này ($WAZUH_MANAGER)? (y/n): " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] && break
done

# ==== STEP 2: INPUT GROUP ====
while true; do
    read -rp "Nhập tên nhóm Agent (Group) [mặc định: default]: " WAZUH_GROUP
    WAZUH_GROUP=${WAZUH_GROUP:-default}

    if [[ ! "$WAZUH_GROUP" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        echo "[!] Tên group không hợp lệ (chỉ được chứa chữ, số, ., _, -)."
        continue
    fi

    echo "[✓] Group hợp lệ: $WAZUH_GROUP"
    break
done

# ==== STEP 3: INPUT AGENT NAME ====
DEFAULT_HOSTNAME=$(hostname)
read -rp "Nhập tên Agent (mặc định: $DEFAULT_HOSTNAME): " WAZUH_NAME
WAZUH_NAME=${WAZUH_NAME:-$DEFAULT_HOSTNAME}
echo "[✓] Agent name: $WAZUH_NAME"

# ==== STEP 4: DETECT OS ====
if [ -f /etc/debian_version ]; then
  OS_FAMILY="debian"
  PKG_EXT="deb"
elif [ -f /etc/redhat-release ]; then
  OS_FAMILY="rhel"
  PKG_EXT="rpm"
else
  echo "[!] Unsupported OS. Only Debian/Ubuntu/RHEL/Rocky supported."
  exit 1
fi

ARCH=$(uname -m)
case "$ARCH" in
  x86_64) ARCH_TYPE="amd64" ;;
  aarch64) ARCH_TYPE="arm64" ;;
  *) ARCH_TYPE="$ARCH" ;;
esac

echo "[i] Phát hiện hệ điều hành: $OS_FAMILY ($ARCH_TYPE)"

# ==== STEP 5: INSTALL PACKAGE LOCALLY ====
if [ "$OS_FAMILY" = "debian" ]; then
  PKG_FILE=$(ls ${LOCAL_REPO_PATH}/wazuh-agent_*_${ARCH_TYPE}.deb 2>/dev/null | head -1)
  if [ -z "$PKG_FILE" ]; then
    echo "[!] Không tìm thấy file .deb trong $LOCAL_REPO_PATH"
    exit 1
  fi
  echo "[→] Cài đặt từ: $PKG_FILE"
  dpkg -i "$PKG_FILE" || apt-get install -f -y
elif [ "$OS_FAMILY" = "rhel" ]; then
  PKG_FILE=$(ls ${LOCAL_REPO_PATH}/wazuh-agent-*.$ARCH_TYPE.rpm 2>/dev/null | head -1)
  if [ -z "$PKG_FILE" ]; then
    echo "[!] Không tìm thấy file .rpm trong $LOCAL_REPO_PATH"
    exit 1
  fi
  echo "[→] Cài đặt từ: $PKG_FILE"
  yum localinstall -y "$PKG_FILE"
fi

# ==== STEP 6: CONFIGURE ====
echo "[i] Cấu hình Wazuh agent..."
sed -i "s|<address>.*</address>|<address>${WAZUH_MANAGER}</address>|" "$CONF_PATH"
sed -i "s|<group>.*</group>|<group>${WAZUH_GROUP}</group>|" "$CONF_PATH"
sed -i "s|<name>.*</name>|<name>${WAZUH_NAME}</name>|" "$CONF_PATH"

# ==== STEP 7: START SERVICE ====
echo "[i] Khởi động dịch vụ agent..."
systemctl daemon-reload
systemctl enable $AGENT_SERVICE
systemctl restart $AGENT_SERVICE
sleep 5

# ==== STEP 8: VERIFY ====
if systemctl is-active --quiet $AGENT_SERVICE; then
  echo "[✓] Dịch vụ agent đang chạy."
else
  echo "[!] Dịch vụ agent KHÔNG chạy. Kiểm tra lỗi với: systemctl status wazuh-agent"
fi

if grep -q "Connected" /var/ossec/logs/ossec.log 2>/dev/null; then
  echo "[✓] Agent đã kết nối thành công tới Manager $WAZUH_MANAGER"
else
  echo "[!] Chưa thấy trạng thái Connected trong log. Kiểm tra lại firewall hoặc key agent."
fi

echo "-----------------------------------------------------"
echo "[✓] Cài đặt hoàn tất cho Agent: $WAZUH_NAME"
echo "-----------------------------------------------------"
