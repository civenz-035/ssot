# OpenCode + AWS Bedrock Mantle Integration (SSOT Module)

Module: `~/ssot/modules/dev/`

โมดูลสำหรับตั้งค่าและรัน Local OpenAI-compatible SigV4 Proxy เพื่อให้ **OpenCode** (ทั้ง CLI และ Desktop GUI) สามารถเรียกใช้โมเดลใน **AWS Bedrock Mantle** (Region: `ap-southeast-2`) ได้ทันทีโดยไม่ติดขัดปัญหา Auth หรือ Provider Scheme

## รองรับโมเดล
- `moonshotai.kimi-k2.5`
- `deepseek.v3.1`
- `openai.gpt-oss-120b`
- `qwen.qwen3-coder-480b-a35b-instruct`

---

## วิธีติดตั้งบนเครื่องใหม่

เมื่อ clone `~/ssot` ลงเครื่องใหม่แล้ว:

### สำหรับ Windows (PowerShell)
```powershell
pwsh -ExecutionPolicy Bypass -File ~/ssot/modules/dev/install.ps1
```

### สำหรับ Linux / WSL / macOS (Bash)
```bash
bash ~/ssot/modules/dev/install.sh
```

---

## คำสั่งควบคุมผ่าน Shell (เมื่อโหลดโมดูลแล้ว)

```bash
# โหลดโมดูล
source ~/ssot/modules/dev/opencode.sh

# ตรวจสอบสถานะ proxy
oc status

# เริ่มรัน proxy ใน background
oc start

# หยุด proxy
oc stop

# เริ่มรัน proxy แล้วเปิด opencode ทันที
oc run
```
