#!/bin/sh
# Setup Bedrock Mantle provider in OpenCode v2
# Run on ACODEX after proxy is started

echo "========================================"
echo "🔧 Setup Bedrock Mantle in OpenCode v2"
echo "========================================"

# Check if proxy is running
echo "[1/3] Checking proxy..."
if ! curl -s http://127.0.0.1:4098/health >/dev/null 2>&1; then
    echo "❌ Proxy not running! Start with:"
    echo "   ~/.aws/venv/bin/python3 ~/.aws/bedrock_mantle_proxy.py"
    exit 1
fi
echo "✅ Proxy running on http://127.0.0.1:4098"

# Add provider via opencode CLI
echo "[2/3] Adding Bedrock Mantle provider..."
opencode providers add bedrock-mantle \
    --type openai-compatible \
    --base-url http://127.0.0.1:4098 \
    --name "Bedrock Mantle" \
    2>/dev/null || echo "   (Provider may already exist)"

# Set as default or add to model picker
echo "[3/3] Configuring..."

# Create instruction for manual setup
cat << 'INSTRUCTION'

✅ Setup complete!

📝 Manual steps in OpenCode v2:
   1. Open OpenCode
   2. Press Ctrl+P (or Cmd+P)
   3. Type: "/connect" or "/providers"
   4. Click "Add Provider"
   5. Choose "OpenAI Compatible"
   6. Enter: http://127.0.0.1:4098
   7. Save and select model

Or run with specific model:
   opencode run --model claude-sonnet-4-6 --provider bedrock-mantle

========================================
INSTRUCTION

# Test the proxy
echo "🧪 Testing proxy..."
curl -s http://127.0.0.1:4098/health | head -5

echo ""
echo "✅ Done! Start OpenCode and select 'Bedrock Mantle' in /model"
