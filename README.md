# 🚀 SSOT — Joe's Personal Command Center

**Single Source of Truth (SSOT)** สำหรับตั้งค่า Terminal (Bash & Zsh), เครื่องมือจัดการไฟล์, Git ข้ามโปรเจค, ระบบตู้เซฟเข้ารหัส (Vault), และเครือข่าย SSH ข้ามเครื่องทั้งหมดของพี่โจ

รองรับทุกอุปกรณ์: **Termux** · **MuMu** · **OPPO** · **WSL** · **WSL2** · **Git Bash (Windows)** · **AcodeX** · **UserLAnd**

---

## ⚡ วิธีติดตั้งบนเครื่องใหม่ (Clone ปุ๊บ พร้อมใช้ทันที!)

ใช้แค่ **2 คำสั่ง** บนเครื่องใหม่ ระบบจะลงแพ็กเกจจำเป็น, ผูก `.bashrc`/`.zshrc`, ปลดล็อกความลับจาก Vault, ลงทะเบียนโหนด และสร้างคำสั่งลัดให้ครบอัตโนมัติ:

```bash
git clone https://github.com/civenz-035/ssot.git ~/ssot
bash ~/ssot/install.sh <ชื่อเครื่อง>
```

**ตัวอย่าง `<ชื่อเครื่อง>` ที่ระบุได้:**
- `termux` — มือถือ Android หลัก
- `oppo` — มือถือเครื่องสำรอง Oppo
- `mumu` — จำลอง Android MuMu
- `wsl` / `wsl2` — Windows Subsystem for Linux
- `git-bash` — Git Bash บน Windows
- `acodex` / `userland` — แอป Linux บนมือถือ

*(หรือสั่งติดตั้งแบบบรรทัดเดียวจากเครื่องเปล่า:)*
```bash
curl -fsSL https://raw.githubusercontent.com/civenz-035/ssot/main/bootstrap/install.sh | MY_DEVICE=termux bash
```

---

## 📁 โครงสร้างโปรเจค (สะอาด แยกหมวดชัดเจน)

```text
ssot/
├── install.sh                 # 🚀 ทางลัดสั่งติดตั้งเครื่องใหม่ในคำสั่งเดียว
├── joe.sh                     # ⚡ จุดเริ่มต้นโหลดระบบ (Main Entry Point)
├── .env.example               # 📝 แม่แบบตัวแปรความลับ (ไฟล์จริงเก็บที่ ~/.env และ ~/.env.secret)
│
├── profiles/                  # 💻 ไฟล์ .bashrc / .zshrc ประจำแต่ละเครื่อง
│   ├── _common/               # โค้ดเริ่มต้นส่วนกลาง (แก้ที่เดียวมีผลครบทุกเครื่อง!)
│   └── termux | wsl | wsl2 | git-bash | mumu | oppo | acodex | userland
│
├── core/                      # ⚙️ เครื่องยนต์แกนกลาง (โหลดอัตโนมัติตามลำดับ)
│   ├── runtime/               # helper.sh, checker.sh, zsh-compat.sh
│   ├── 01-colors.sh           # ตัวโหลดระบบสี (มี fallback กันพังในตัว)
│   ├── 00-env.sh              # ตัวแปร Path และค่าตั้งต้นข้ามเครื่อง
│   ├── aliases.sh             # คำสั่งย่อมาตรฐานทั้งหมด
│   ├── loader.sh              # ระบบ Lazy-load
│   ├── profiles.sh            # สลับ AI Profile (pf mom / pf joe)
│   ├── node-mesh.sh           # เชื่อมข้อมูลโหนดเข้าตัวแปรระบบ
│   ├── ssh-config.sh          # ตั้งค่าเชื่อม SSH / PowerShell
│   ├── ssh_toolkit.sh         # เครื่องมือจัดการ SSH
│   └── 3worlds.sh             # คำสั่งเชื่อม 3 โลก (Windows ↔ WSL ↔ Android)
│
├── modules/                   # 🧩 คลังฟังก์ชันใช้งาน (เขียนสคริปต์ใหม่ วางที่นี่โหลดอัตโนมัติ!)
│   ├── system/                # pkg_manager.sh, backup.sh, clean.sh, pathx.sh, tools.sh
│   ├── dev/                   # gt.sh (Git Toolkit), git_tools.sh, project.sh, wtf.sh
│   ├── file-manager/          # 00-fm-loader.sh, bash-manager.sh (fm), files_manage.sh, tree.sh
│   └── personal/              # daily_use.sh, joe_functions.sh, joe_scripts.sh, find_stuff.sh, sound_cut.sh, superboom.sh
│
├── bin/                       # 🛠️ คำสั่ง CLI เดี่ยว (ถูกผูกเข้า ~/.local/bin อัตโนมัติ)
│   ├── dashboard.sh           # แดชบอร์ดเช็คสุขภาพระบบ (พิมพ์ db หรือ dashboard)
│   ├── env-manager.sh         # หน้าจอเมนูจัดการตัวแปร (พิมพ์ envm)
│   ├── mesh-sync.sh           # ซิงค์ Git พร้อมกันทุกเครื่อง (พิมพ์ ms หรือ mesh-sync)
│   └── dist-tui.sh            # หน้าจอสแกนและจัดการพื้นที่ดิสก์ (พิมพ์ cltui)
│
├── plugins/                   # 🎨 ปลั๊กอินเสริม
│   ├── ez_colors/             # ชุดสี V3 ฝังมาใน repo เลย (เครื่องใหม่มีสีสวยทันทีไม่ต้องลงเพิ่ม!)
│   └── joe_theme/             # ธีม Prompt สลับได้ (ta, tb, tc, td, te)
│
└── bootstrap/                 # 🔐 ระบบติดตั้ง ทะเบียนโหนด และตู้เซฟความลับ
    ├── install.sh             # ตัวติดตั้งหลัก
    ├── templates/env          # แม่แบบสร้าง ~/.local/bin/env
    ├── nodes/                 # ข้อมูลโหนด (*.node.env, node-status, node-register, pubkey-corrector)
    ├── vault/                 # ตู้เซฟ AES-256 (ssot-vault.sh, .env.enc, pubkeys.enc)
    └── scripts/               # สคริปต์ดูแล SSH/Tailscale (mesh-regen.sh, ssh_audit.sh, tailscale-separate.sh)
```

---

## 🌱 วิธีต่อยอดเขียนสคริปต์เพิ่มเองในอนาคต (ง่ายมาก!)

1. **ถ้าอยากเพิ่มฟังก์ชันหรือคำสั่งย่อไว้ใช้ใน Terminal:**
   - สร้างไฟล์นามสกุล `.sh` ในโฟลเดอร์ `modules/personal/` (หรือสร้างโฟลเดอร์หมวดใหม่ใน `modules/` ได้เลย)
   - พิมพ์ `pp` (หรือ `qpp`) เพื่อรีโหลด หน้าจอก็จะรู้จักฟังก์ชันใหม่ทันที **ไม่ต้องไปตามแก้ `joe.sh` หรือ `.bashrc` เลย!**
2. **ถ้าอยากสร้างโปรแกรม/สคริปต์ยาวๆ ที่รันแยกเป็นคำสั่งเดี่ยว:**
   - วางไฟล์ใน `bin/` แล้วสั่ง `repo fix` (หรือรัน `bash ~/ssot/install.sh`) เพื่อผูกเข้า `~/.local/bin/`
3. **ถ้ามีโปรเจคใหญ่ที่ไม่เกี่ยวกับการตั้งค่าเครื่อง (เช่น บอท, เว็บ, โปรเจค Python):**
   - แยกสร้างเป็นโฟลเดอร์โปรเจคใหม่ใน `~/projects/<ชื่อโปรเจค>` จะช่วยให้ `~/ssot` สะอาด เบา และโคลนไวเสมอครับ

---

## 🧰 คำสั่งหลักที่ใช้บ่อย

| คำสั่ง | หน้าที่ |
|---|---|
| `pp` / `qpp` | รีโหลดค่าตั้งต้น Shell ใหม่ (`qpp` = รีโหลดแบบไม่ล้างหน้าจอ) |
| `db` / `dashboard` | เปิดหน้าแดชบอร์ดดูสถานะเครื่อง โหนด และ Vault ทั้งหมด |
| `repo` / `repo fix` | เช็คสถานะ Symlink ทั้งระบบ / ซ่อมลิงก์ให้อัตโนมัติ |
| `gt status` / `gt sync all` | เช็คหรือซิงค์ Git ทุกโปรเจคพร้อมกัน |
| `ms status` / `ms fanpull` | เช็คหรือสั่ง `git pull` ข้ามทุกเครื่องในวง SSH Mesh |
| `node-status` (`ns`) | ดูสถานะเครื่องทั้งหมดในเครือข่าย |
| `vault status` / `lock` / `unlock` | เช็ค/ล็อก/ปลดล็อกความลับใน `~/.env.secret` |
| `envm` | เปิดเมนู TUI แก้ไข/ค้นหาตัวแปรใน `core/00-env.sh` |
| `fm help` | เปิดตัวช่วยจัดการไฟล์ (`bash-manager`) พร้อมโหมดสอนคำสั่ง (`fm learn on`) |
| `wtf <คำสั่ง>` | ส่องดูว่าคำสั่งหรือตัวแปรนั้นมาจากไฟล์ไหนบรรทัดไหน |

---

## 📝 License

Personal use — Joe's private command center.
