# OpenCode + AWS Bedrock Mantle Integration (SSOT Module)

Module: `~/ssot/modules/opencode/`

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
pwsh -ExecutionPolicy Bypass -File ~/ssot/modules/opencode/install.ps1
```

### สำหรับ Linux / WSL / macOS (Bash)
```bash
bash ~/ssot/modules/opencode/install.sh
```

---

## คำสั่งควบคุมผ่าน Shell (เมื่อโหลดโมดูลแล้ว)

```bash
# โหลดโมดูล
source ~/ssot/modules/opencode/opencode.sh

# ตรวจสอบสถานะ proxy
oc status

# เริ่มรัน proxy ใน background
oc start

# หยุด proxy
oc stop

# เริ่มรัน proxy แล้วเปิด opencode ทันที
oc run
```

---

## CLI Wrapper — ใช้ AI จาก Terminal โดยตรง

เมื่อโหลดโมดูลแล้ว สามารถใช้ `oc cli` หรือ `bedrock-cli` เพื่อส่ง prompt ไปยังโมเดลได้ทันที:

```bash
# โหลดโมดูล
source ~/ssot/modules/opencode/opencode.sh

# ใช้งาน CLI
oc cli "Hello, how are you?"                  # ใช้ default model (deepseek.v3.1)
oc cli deepseek "Explain quantum computing"   # ระบุ model
oc cli kimi-thinking "Solve this: ..."        # ใช้ model ที่ต้องการ

# Pipe input
cat code.py | oc cli qwen "Review this code"
git diff | oc cli deepseek "Summarize changes"
echo "Hello" | oc cli kimi

# ดู models ที่มี
oc cli models
```

### Model Aliases

| Alias | Full Model ID |
|-------|---------------|
| `deepseek`, `deepseek-v3` | `deepseek.v3.1` |
| `qwen`, `qwen-coder` | `qwen.qwen3-coder-480b-a35b-instruct` |
| `kimi`, `kimi-k2.5` | `moonshotai.kimi-k2.5` |
| `kimi-thinking` | `moonshotai.kimi-k2-thinking` |
| `gpt-oss` | `openai.gpt-oss-120b` |
| `mistral` | `mistral.mistral-large-3-675b-instruct` |
| `devstral` | `mistral.devstral-2-123b` |
| `gemma` | `google.gemma-3-27b-it` |
| `glm`, `glm-5` | `zai.glm-5` |

---

## ใช้กับ Script อื่น (OpenAI-compatible)

เมื่อ proxy รันแล้ว สามารถใช้ endpoint นี้ได้ทุกที่ที่รองรับ OpenAI API:

```bash
# Environment variables
export OPENAI_API_KEY="sigv4-local"
export OPENAI_BASE_URL="http://127.0.0.1:4098/v1"

# ใช้กับ Python (openai SDK)
pip install openai
python -c "
import openai
client = openai.OpenAI()
response = client.chat.completions.create(
    model='deepseek.v3.1',
    messages=[{'role': 'user', 'content': 'Hello!'}]
)
print(response.choices[0].message.content)
"

# ใช้กับ curl
curl http://127.0.0.1:4098/v1/chat/completions \
  -H "Authorization: Bearer sigv4-local" \
  -H "Content-Type: application/json" \
  -d '{"model": "deepseek.v3.1", "messages": [{"role": "user", "content": "Hello"}]}'
```

---

## ใช้กับ AI Agent อื่นๆ (Hermes, Claude Code, ฯลฯ)

### วิธีที่ 1: Export Environment Variables

```bash
# โหลด environment variables สำหรับ AI agent
source ~/ssot/modules/opencode/opencode.sh
eval "$(oc env)"

# ตอนนี้ AI agent สามารถใช้ OPENAI_BASE_URL ได้ทันที
# เช่น Hermes, LangChain, AutoGen, CrewAI, etc.
```

### วิธีที่ 2: Hermes Plugin (Auto-start proxy)

Hermes plugin ถูกติดตั้งที่:
```
~/.hermes/plugins/bedrock_mantle/
├── plugin.json      # Provider config
└── ensure_proxy.sh  # Auto-start hook
```

เมื่อ Hermes start ขึ้น มันจะ:
1. ตรวจสอบว่า proxy รันอยู่ไหม
2. ถ้าไม่ จะ auto-start ให้
3. Export env vars ให้ agent ใช้

### วิธีที่ 3: Model Catalog (JSON)

```bash
# ดู model catalog สำหรับ integration
oc catalog

# Output:
# {
#   "provider": "bedrock-mantle",
#   "base_url": "http://127.0.0.1:4098/v1",
#   "api_key": "sigv4-local",
#   "models": [...],
#   "default_model": "deepseek.v3.1"
# }
```

---

## Integration Examples

### Python (any framework)

```python
import os
os.environ["OPENAI_API_KEY"] = "sigv4-local"
os.environ["OPENAI_BASE_URL"] = "http://127.0.0.1:4098/v1"

# ใช้ได้กับทุก framework ที่รองรับ OpenAI SDK
from openai import OpenAI
client = OpenAI()

# หรือ LangChain
from langchain_openai import ChatOpenAI
llm = ChatOpenAI(model="deepseek.v3.1")

# หรือ AutoGen
from autogen import AssistantAgent
agent = AssistantAgent("assistant", llm_config={
    "config_list": [{
        "model": "deepseek.v3.1",
        "api_key": "sigv4-local",
        "base_url": "http://127.0.0.1:4098/v1"
    }]
})
```

### Shell Script

```bash
#!/bin/bash
source ~/ssot/modules/opencode/opencode.sh
eval "$(oc env)"

# Simple chat function
ask_ai() {
    curl -s "$OPENAI_BASE_URL/chat/completions" \
        -H "Authorization: Bearer $OPENAI_API_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"model\": \"deepseek.v3.1\", \"messages\": [{\"role\": \"user\", \"content\": \"$1\"}]}" \
        | jq -r '.choices[0].message.content'
}

ask_ai "What is 2+2?"
```
