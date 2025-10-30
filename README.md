# CÁCH THIẾT LẬP WAZUH AGENT TRÊN CÁC MÁY CHỦ #
B1: Chọn gói cài đặt theo phiên bản và cấu trúc hệ điều hành:

*Linux*
- RPM amd64	
curl -o wazuh-agent-4.14.0-1.x86_64.rpm http://10.0.13.179/wazuh-agent-4.14.0-1.x86_64.rpm && sudo WAZUH_MANAGER='10.0.13.179' WAZUH_AGENT_GROUP='default' WAZUH_AGENT_NAME='Your_Device' rpm -ihv wazuh-agent-4.14.0-1.x86_64.rpm
- RPM aarch64
curl -o wazuh-agent-4.14.0-1.aarch64.rpm http://10.0.13.179/wazuh-agent-4.14.0-1.aarch64.rpm && sudo WAZUH_MANAGER='10.0.13.179' WAZUH_AGENT_GROUP='default' WAZUH_AGENT_NAME='Your_Device' rpm -ihv wazuh-agent-4.14.0-1.aarch64.rpm
- DEB amd64
wget http://10.0.13.179/wazuh-agent_4.14.0-1_amd64.deb && sudo WAZUH_MANAGER='10.0.13.179' WAZUH_AGENT_GROUP='default' WAZUH_AGENT_NAME='Your_Device' dpkg -i ./wazuh-agent_4.14.0-1_amd64.deb
- DEB aarch64
wget http://10.0.13.179/wazuh-agent_4.14.0-1_arm64.deb && sudo WAZUH_MANAGER='10.0.13.179' WAZUH_AGENT_GROUP='default' WAZUH_AGENT_NAME='Your_Device' dpkg -i ./wazuh-agent_4.14.0-1_arm64.deb

*Windows*
- Invoke-WebRequest -Uri http://10.0.13.179/wazuh-agent-4.14.0-1.msi -OutFile $env:tmp\wazuh-agent; msiexec.exe /i $env:tmp\wazuh-agent /q WAZUH_MANAGER='10.0.13.179' WAZUH_AGENT_GROUP='default' WAZUH_AGENT_NAME='Your_Device'

B2: Khởi chạy wazuh-agent

*Linux*
- sudo systemctl daemon-reload
- sudo systemctl enable wazuh-agent
- sudo systemctl start wazuh-agent

*Windows*
- NET START Wazuh
