# Declarative Fedora Dotfiles

> **「Fedora，但是用 NixOS 的宣告式思維管理」**
>
> 結合 **Ansible**（系統狀態、DNF、COPR、Flatpak）、**GNU Stow**（使用者家目錄軟連結）與 **Just**（日常操作 Task Runner），實現一鍵重建、宣告式版本控管的現代化 Niri 桌面環境。

---

## 為什麼這樣設計？

| 痛點 | 傳統 Dotfiles | 本架構解法 |
| :--- | :--- | :--- |
| **忘記裝過什麼** | 靠記憶重打 `dnf install` | **Ansible 宣告式**：Git 裡的 `vars/default.yml` 就是答案 |
| **桌面微調很麻煩** | 每次改 config 要手動 copy | **GNU Stow 軟連結**：`~/.config` 隨時改，Git 隨時追蹤 |
| **權限混亂** | 整個 script 用 sudo 跑壞 home 目錄 | **雙 Play 分離**：系統（Root）與使用者（$USER）嚴格隔離 |
| **指令難記** | 要背長串 ansible-playbook 參數 | **Justfile**：類似 `nixos-rebuild`，輸入 `just apply` 搞定一切 |

---

## 目錄架構

```text
dotfiles-fedora/
├── Justfile                      # 常用操作界面 (just apply, just dotfiles...)
├── README.md                     # 說明文件
├── .gitignore                    # 忽略 local.yml 與暫存檔
│
├── scripts/
│   └── bootstrap.sh              # 全新 Fedora 一鍵還原腳本
│
├── ansible/
│   ├── playbook.yml              # 主 Playbook（分 System 與 User 兩大 Play）
│   ├── inventory.ini             # 本機連線設定
│   ├── vars/
│   │   ├── default.yml           # 全域套件清單 (DNF, COPR, Flatpak, Stow 模組)
│   │   └── local.yml.example     # 單機專屬變數覆蓋範本（不進 Git）
│   └── tasks/
│       ├── system/               # Root 權限任務 (COPR, DNF, Flathub repo, 系統服務)
│       └── user/                 # 使用者任務 (Stow 軟連結, Flatpak 應用, User 服務)
│
└── stow/                         # 按應用模組化的 Dotfiles
    ├── niri/                     # Niri 視窗管理器 (~/.config/niri/config.kdl)
    ├── waybar/                   # Waybar 頂部狀態列
    ├── kitty/                    # Kitty 終端機
    ├── fuzzel/                   # Fuzzel 輕量 App 啟動器
    ├── mako/                     # Mako 桌面通知
    └── bash/                     # Shell 環境與 alias
```

---

## 快速開始（全新 Fedora）

在一台剛安裝好的乾淨 Fedora 上：

```bash
# 1. 複製你的儲存庫
git clone https://github.com/codingpeanut/dotfiles-fedora.git ~/dev/dotfiles-fedora
cd ~/dev/dotfiles-fedora

# 2. 一鍵執行 Bootstrap
./scripts/bootstrap.sh
```

`bootstrap.sh` 會自動：
1. 安裝基礎工具：`git`, `ansible`, `just`, `stow`
2. 自動建立 `ansible/vars/local.yml` 本機覆蓋設定
3. 執行 `just apply` 完整部署系統與桌面

---

## 日常使用指南（The Just Workflow）

日常維護全部透過 `just` 執行（就像 NixOS 的 `nixos-rebuild`）：

```bash
# 套用全部設定（系統套件 + Dotfiles + 服務）
just apply

# 僅重新建立/更新 Dotfiles 軟連結（日常改動 stow 模組時）
just dotfiles

# 僅安裝/更新系統層級套件（DNF / COPR / 系統服務）
just system

# 僅更新使用者層級（Flatpak / Dotfiles）
just user

# 直接用 GNU Stow 重新建立所有連結（不透過 Ansible，極速）
just stow

# 升級系統 DNF 套件與 Flatpak 軟體
just update

# 檢查 Git 狀態
just status
```

---

## 常見自訂操作

### 1. 新增全域套件
直接編輯 `ansible/vars/default.yml`：
- 加 DNF 套件：加入 `system_packages` 陣列。
- 加 COPR 來源：加入 `system_copr_repos` 陣列（如某個開發者倉庫）。
- 加 Flatpak 應用：加入 `flatpak_user_packages` 陣列。

儲存後執行：
```bash
just apply
```

### 2. 新增 Dotfiles 模組
假設你想新增 `neovim` 設定：
1. 在 `stow/` 下建立模組結構：
   ```bash
   mkdir -p stow/nvim/.config/nvim
   touch stow/nvim/.config/nvim/init.lua
   ```
2. 在 `ansible/vars/default.yml` 的 `stow_packages` 加上 `nvim`。
3. 執行：
   ```bash
   just dotfiles
   ```

### 3. 多主機差異（筆電 vs 桌機）
在該台主機上複製出 `local.yml`：
```bash
cp ansible/vars/local.yml.example ansible/vars/local.yml
```
在 `local.yml` 裡面加入該主機專屬套件（例如筆電專用 `tlp` 或專屬 Flatpak），此檔案已被 `.gitignore` 排除，不會污染版本庫。

### 4. 秘密與私人資料（Secrets）
- SSH Key、Git 憑證等不進版本庫。
- Bash 私人設定可放在 `~/.bashrc.local`，`stow/bash/.bashrc` 會自動載入它。
