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
├── Justfile                      # 常用操作界面 (just apply, just dotfiles, just reload...)
├── README.md                     # 說明文件
├── .gitignore                    # 忽略 local.yml 與暫存檔
│
├── scripts/
│   ├── bootstrap.sh              # 全新 Fedora 一鍵還原腳本
│   └── build-caelestia.sh        # （可選）手動編譯 Niri-Caelestia Shell QML 模組
│
├── ansible/
│   ├── playbook.yml              # 主 Playbook（分 System 與 User 兩大 Play）
│   ├── inventory.ini             # 本機連線設定
│   ├── vars/
│   │   ├── default.yml           # 全域套件清單 (DNF, COPR, Flatpak, Stow 模組)
│   │   └── local.yml.example     # 單機專屬變數覆蓋範本（不進 Git）
│   └── tasks/
│       ├── system/               # Root 權限任務 (COPR, DNF, Repos, Flathub repo, 系統服務)
│       │   ├── repos.yml         # 第三方 RPM 來源 (VS Code, Google Chrome, RPM Fusion)
│       │   ├── copr.yml          # COPR 倉庫 (yalter/niri, quickshell, starship)
│       │   ├── packages.yml      # DNF 套件安裝
│       │   ├── alternatives.yml  # vi/vim 與 nvim 系統連動
│       │   ├── flatpak_repo.yml  # Flathub 來源設定
│       │   └── services.yml      # 系統層級 systemd 服務 (bluetooth)
│       └── user/                 # 使用者任務 (Stow 軟連結, Flatpak 應用, User 服務, CLI)
│           ├── dotfiles.yml      # Stow 軟連結
│           ├── flatpak_apps.yml  # Flatpak 應用 (Discord, Firefox)
│           ├── dev_tools.yml     # 開發工具與 Agent (pi-coding-agent)
│           ├── antigravity.yml   # Google Antigravity CLI (agy)
│           ├── caelestia.yml     # Niri-Caelestia Shell 下載與配置
│           ├── desktop_theme.yml # GTK 暗色模式、游標與 JetBrainsMono Nerd Font
│           └── services.yml      # 使用者層級 systemd 服務
│
└── stow/                         # 按應用模組化的 Dotfiles
    ├── niri/                     # Niri 視窗管理器 (~/.config/niri/config.kdl)
    ├── waybar/                   # Waybar 頂部狀態列
    ├── kitty/                    # Kitty 終端機
    ├── fuzzel/                   # Fuzzel 輕量 App 啟動器
    ├── mako/                     # Mako 桌面通知
    ├── bash/                     # Shell 環境與 alias
    ├── starship/                 # Starship 跨 Shell 終端 Prompt 美化
    └── nvim/                     # Neovim (init.lua) 與 Vim (.vimrc) 雙連動配置
```

---

## 內建軟體與桌面環境

- **視窗管理器與 Shell**：
  - **Niri**：捲軸式 Wayland 合成器 (via COPR `yalter/niri`)。
  - **Quickshell + Niri-Caelestia Shell**：現代化動態桌面 Shell（狀態列、通知、OSD、Launcher）。
  - **自動鎖屏與休眠**：Swayidle (300 秒自動鎖屏、600 秒休眠關閉螢幕) + Swaylock。
  - **備用組件**：Waybar、Mako、Fuzzel。
- **中文輸入法與字體**：
  - **Fcitx5**：完整 GTK/Qt 支援、新酷音（Chewing）繁體注音輸入法。
  - **字體支援**：Google Noto Sans/Serif CJK 繁體中文、Noto Color Emoji、JetBrainsMono Nerd Font。
- **多媒體編解碼 (RPM Fusion)**：
  - 完整 FFmpeg、GStreamer 解碼器插件（H.264 / AAC / 硬體加速解碼）。
- **桌面工具與周邊管理**：
  - **檔案總管**：Nautilus (GNOME Files) + File-Roller 壓縮管理（快捷鍵 `Mod + E`）。
  - **螢幕亮度控制**：支援筆電背光 (`brightnessctl`) 與外接螢幕 (`ddcutil`)，整合 Waybar 頂部抽屜滑動條 (`backlight/slider`)、GTK3 現代化圖形滑桿彈出面板（快捷鍵 `Mod + B` 或指令 `brightness-menu`，含即時拖曳與 25%/50%/75%/100% 預設檔位）、Mako 進度條 OSD 即時反饋，並相容多媒體鍵與 `Mod + F5/F6`。
  - **藍牙連線**：Blueman 桌面托盤管理 + `bluetooth.service`。
  - **外觀風格**：GTK 暗色主題、Adwaita 游標自動統一。
- **文字編輯器（雙連動）**：
  - **Neovim** (`nvim`，現代化配置 `~/.config/nvim/init.lua`，支援 Wayland 剪貼簿)。
  - **Vim** (`vim` / `vi`，透過 alternatives 與 alias 連動至 Neovim，並附相容 `.vimrc`)。
- **終端美化與 Shell 生態（Pure Bash 極速流）**：
  - **Starship Prompt** (原生相容 Bash，極速 Prompt，Nerd Font 圖標、Git 分支、語言版本偵測，Tokyo Night 配色)。
  - **FZF 互動模糊搜尋與補全** (支援 `**<TAB>` 智慧模糊補全、`Ctrl+R` 歷史搜尋、`Ctrl+T` 檔案選取帶 `bat` 程式碼即時預覽、`Alt+C` 目錄跳轉帶 `eza --tree` 目錄樹即時預覽)。
  - **Zoxide** (`z <dir>` 智慧歷史目錄秒級跳轉)。
  - **Eza** (現代化彩色圖標 `ls` 替代品)。
  - **Neofetch / Fastfetch** (內建高速 `fastfetch`，並設定 `neofetch` 別名相容)。
- **圖形軟體**：
  - **Google Chrome** (RPM 官方來源)
  - **Visual Studio Code** (RPM 官方來源)
  - **Discord** (Flathub 沙盒隔離)
  - **Firefox** (Flathub)
- **AI 輔助與開發工具**：
  - **Google Antigravity CLI (`agy`)**：官方安裝腳本配置於 `~/.local/bin`。
  - **pi-coding-agent**：Earendil Works 終端 AI Agent，由 npm 全域管理 (`~/.npm-global/bin`)。
  - Node.js, Python3, Git, Just, Stow, Ripgrep, Fd-find, Bat 等。

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
3. 執行 `just apply` 完整部署系統、桌面、套件與 CLI 工具

---

## 日常使用指南（The Just Workflow）

日常維護全部透過 `just` 執行（就像 NixOS 的 `nixos-rebuild`）：

```bash
# 套用全部設定（系統套件 + Dotfiles + 服務 + 開發工具 + 連動）
just apply

# 僅重新建立/更新 Dotfiles 軟連結（日常改動 stow 模組時）
just dotfiles

# 僅安裝/更新系統層級套件（DNF / COPR / 系統服務）
just system

# 僅更新使用者層級（Flatpak / Dotfiles / Dev Tools）
just user

# 直接用 GNU Stow 重新建立所有連結（不透過 Ansible，極速）
just stow

# 重啟桌面環境組件（Waybar, Mako, Niri 配置熱重載）
just reload

# 同步遠端儲存庫更新並自動重新連結與重載
just pull

# 檢查系統、CLI 與桌面工具依賴是否齊全
just check

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
- 加 COPR 來源：加入 `system_copr_repos` 陣列。
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
