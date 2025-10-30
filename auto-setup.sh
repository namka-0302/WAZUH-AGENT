#!/bin/bash
# ===========================================================
#  Wazuh Agent Universal Auto Installer (Linux + Windows)
#  Version: 4.0 (Hanel SOC)
# ===========================================================
set -e

echo "-----------------------------------------------------"
echo "[ Hanel SOC | Universal Wazuh Agent Installer v4.0 ]"
echo "-----------------------------------------------------"

# === Detect OS ===
OS_TYPE="$(uname -s 2>/dev/null || echo Unknown)"
case "$OS_TYPE" in
  Linux*) PLATFORM="linux" ;;
  CYGWIN*|MINGW*|MSYS*|Windows*) PLATFORM="windows" ;;
  *) PLATFORM="unknown" ;;
esac

# ===========================================================
# ============ LINUX INSTALLATION ============================
# ===========================================================
if [ "$PLATFORM" = "linux" ]; then
  LOCAL_REPO_PATH="$(pwd)"
  CONF_PATH="/var/ossec/etc/ossec.conf"
  AGENT_SERVICE="wazuh-agent"

  # ==== STEP 1: INPUT MANAGER ====
  while true; do
      read -rp "Nhập địa chỉ IP hoặc hostname của Wazuh Manager: " WAZUH_MANAGER
      [ -z "$WAZUH_MANAGER" ] && { echo "[!] Không được để trống IP."; continue; }

      echo "[i] Kiểm tra kết nối tới $WAZUH_MANAGER..."
      ping -c 1 -W 2 "$WAZUH_MANAGER" >/dev/null 2>&1 && echo "[✓] Ping OK." || echo "[!] Ping thất bại (vẫn có thể tiếp tục)."
      for port in 1514 1515; do
          echo -n "[i] Kiểm tra TCP port $port ... "
          if timeout 2 bash -c "echo > /dev/tcp/$WAZUH_MANAGER/$port" 2>/dev/null; then echo "OK"; else echo "FAIL"; fi
      done
      read -rp "Xác nhận dùng IP này ($WAZUH_MANAGER)? (y/n): " confirm
      [[ "$confirm" =~ ^[Yy]$ ]] && break
  done

  # ==== STEP 2: INPUT GROUP ====
  while true; do
      read -rp "Nhập Group [default]: " WAZUH_GROUP
      WAZUH_GROUP=${WAZUH_GROUP:-default}
      [[ "$WAZUH_GROUP" =~ ^[a-zA-Z0-9._-]+$ ]] && break || echo "[!] Group không hợp lệ."
  done

  # ==== STEP 3: INPUT AGENT NAME ====
  DEFAULT_HOSTNAME=$(hostname)
  read -rp "Nhập tên Agent (mặc định: $DEFAULT_HOSTNAME): " WAZUH_NAME
  WAZUH_NAME=${WAZUH_NAME:-$DEFAULT_HOSTNAME}
  echo "[✓] Agent name: $WAZUH_NAME"

  # ==== STEP 4: OS + ARCH ====
  if [ -f /etc/debian_version ]; then OS_FAMILY="debian"; PKG_EXT="deb";
  elif [ -f /etc/redhat-release ]; then OS_FAMILY="rhel"; PKG_EXT="rpm";
  else echo "[!] OS không hỗ trợ."; exit 1; fi
  ARCH=$(uname -m); [ "$ARCH" = "x86_64" ] && ARCH_TYPE="amd64" || ARCH_TYPE="arm64"
  echo "[i] Phát hiện: $OS_FAMILY ($ARCH_TYPE)"

  # ==== STEP 5: INSTALL ====
  if [ "$OS_FAMILY" = "debian" ]; then
      PKG=$(ls ${LOCAL_REPO_PATH}/wazuh-agent_*_${ARCH_TYPE}.deb 2>/dev/null | head -1)
      [ -z "$PKG" ] && { echo "[!] Không tìm thấy .deb trong ${LOCAL_REPO_PATH}"; exit 1; }
      echo "[→] Cài từ: $PKG"
      dpkg -i "$PKG" || apt-get install -f -y
  else
      PKG=$(ls ${LOCAL_REPO_PATH}/wazuh-agent-*.$ARCH_TYPE.rpm 2>/dev/null | head -1)
      [ -z "$PKG" ] && { echo "[!] Không tìm thấy .rpm trong ${LOCAL_REPO_PATH}"; exit 1; }
      echo "[→] Cài từ: $PKG"
      yum localinstall -y "$PKG"
  fi

  # ==== STEP 6: CONFIGURE ====
  cp "$CONF_PATH" "${CONF_PATH}.bak.$(date +%F_%T)"
  echo "[i] Cấu hình Wazuh agent..."
  sed -i "/<address>/c\    <address>${WAZUH_MANAGER}</address>" "$CONF_PATH" || sed -i "/<server>/a\    <address>${WAZUH_MANAGER}</address>" "$CONF_PATH"
  grep -q "<group>" "$CONF_PATH" && sed -i "s|<group>.*</group>|<group>${WAZUH_GROUP}</group>|" "$CONF_PATH" || sed -i "/<client>/a\  <group>${WAZUH_GROUP}</group>" "$CONF_PATH"
  grep -q "<name>" "$CONF_PATH" && sed -i "s|<name>.*</name>|<name>${WAZUH_NAME}</name>|" "$CONF_PATH" || sed -i "/<client>/a\  <name>${WAZUH_NAME}</name>" "$CONF_PATH"

  # ==== STEP 7: START ====
  systemctl daemon-reload
  systemctl enable wazuh-agent
  systemctl restart wazuh-agent
  sleep 5

  # ==== STEP 8: VERIFY ====
  systemctl is-active --quiet wazuh-agent && echo "[✓] Service đang chạy." || echo "[!] Service lỗi."
  grep -q "Connected" /var/ossec/logs/ossec.log 2>/dev/null && echo "[✓] Agent đã kết nối." || echo "[!] Chưa thấy kết nối trong log."

  echo "-----------------------------------------------------"
  echo "[✓] Hoàn tất cài đặt cho Agent: $WAZUH_NAME"
  echo "-----------------------------------------------------"

# ===========================================================
# ============ WINDOWS INSTALLATION ==========================
# ===========================================================
elif [ "$PLATFORM" = "windows" ]; then
  echo "[i] Hệ điều hành: Windows"
  echo "[i] Đang tạo PowerShell script tạm..."

  TMP_PS="C:\\temp\\install-wazuh-agent.ps1"
  mkdir -p /c/temp 2>/dev/null || true

cat > /c/temp/install-wazuh-agent.ps1 << 'EOF'
param(
  [string]$Manager,
  [string]$Group = "default",
  [string]$AgentName = $env:COMPUTERNAME
)
Write-Host "-----------------------------------------------------"
Write-Host "[ Hanel SOC | Wazuh Agent Installer - Windows ]"
Write-Host "-----------------------------------------------------"
Write-Host "[+] Manager: $Manager"
Write-Host "[+] Group  : $Group"
Write-Host "[+] Name   : $AgentName"

$msi = Get-ChildItem -Path . -Filter "wazuh-agent-*.msi" | Select-Object -First 1
if (-not $msi) { Write-Host "[!] Không tìm thấy file .msi"; exit 1 }
Write-Host "[→] Cài đặt từ: $($msi.FullName)"
Start-Process msiexec.exe -Wait -ArgumentList "/i $($msi.FullName) /q WAZUH_MANAGER=$Manager WAZUH_AGENT_GROUP=$Group WAZUH_AGENT_NAME=$AgentName"
Start-Service WazuhSvc
Set-Service WazuhSvc -StartupType Automatic
Write-Host "[✓] Cài đặt hoàn tất."
EOF

  echo ""
  echo "👉 Chạy lệnh sau trong PowerShell (Admin):"
  echo "   powershell -ExecutionPolicy Bypass -File C:\\temp\\install-wazuh-agent.ps1 -Manager <IP_Manager> -Group <group> -AgentName <Tên_Agent>"
  echo "Ví dụ:"
  echo "   powershell -ExecutionPolicy Bypass -File C:\\temp\\install-wazuh-agent.ps1 -Manager 10.0.12.10 -Group soc -AgentName WinSrv01"
  echo ""
  echo "[!] Đặt file .msi của Wazuh agent cùng thư mục với script này."
else
  echo "[!] Không xác định được hệ điều hành. Thoát."
  exit 1
fi
