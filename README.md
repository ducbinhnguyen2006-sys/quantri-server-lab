# Lab Quản Trị Windows Server trên VMware

Hướng dẫn dựng trọn bộ **lab quản trị mạng** trên máy cá nhân: VMware Workstation 16.2.4 +
1 VM **Windows Server 2019** (Domain Controller) + 1 VM **Windows 10** (client).

Repo này có **2 cách làm**:
- 🤖 **Cách A — giao cho opencode/AI agent** (tự động, nhanh).
- 🖐️ **Cách B — làm thủ công** từng bước (nếu bạn muốn tự tay).

> Kết quả cuối: 2 VM chạy **mượt, không lag**, sẵn sàng làm bài lab
> **Domain / Join domain / DHCP / User-Group / Shadow Copies / GPO**.

---

## 1. Bạn cần gì

| Hạng mục | Yêu cầu tối thiểu | Khuyến nghị |
|---|---|---|
| CPU | 4 nhân, có ảo hoá (VT-x/AMD-V) | 8 nhân trở lên |
| RAM | 12 GB | **16–32 GB** |
| Ổ trống | 40 GB | **60 GB+ (SSD/NVMe)** |
| Hệ điều hành | Windows 10/11 64-bit | Windows 11 |
| Phần mềm | opencode (nếu dùng Cách A) | — |

**Tài nguyên cần tải** (~13.5 GB) — xem [docs/01-tai-tai-lieu.md](docs/01-tai-tai-lieu.md):
- VMware Workstation 16.2.4 (`vmware/`)
- Windows10_full.iso, Win SV 2019.iso
- 7 video bài giảng + 2 PDF (`video/`, PDF)

📁 Nguồn tài liệu (Google Drive):
**https://drive.google.com/drive/folders/1khCYAzXvKSkpeot1Rg7PG4A5wyjWqLGK?usp=sharing**

---

## 2. Cách A — Giao cho opencode làm (khuyến nghị)

1. Cài **opencode** trên máy: https://opencode.ai
2. Mở terminal tại thư mục bạn muốn chứa lab, rồi chạy `opencode`.
3. Dán câu lệnh này vào opencode:

   > *"Đọc file AGENTS.md trong repo quantri-server-lab này và giúp tôi cài đặt lab Windows Server theo đúng quy trình. Hỏi tôi khi cần UAC hoặc reboot."*

4. opencode sẽ tự đọc `AGENTS.md` và chạy lần lượt các script trong `scripts/`.
   Bạn chỉ cần **bấm Yes khi Windows hỏi quyền Admin (UAC)** và **khởi động lại máy** khi được yêu cầu.

Nếu ổ đĩa của bạn không phải `E:`, hãy nói với opencode:
> *"Dùng ổ D:\QuanTriServer thay vì E:\QuanTriServer."*

### Hoặc chạy script bằng tay (không cần AI)
```powershell
# Mở PowerShell (không cần Admin cho bước 1)
$LAB = "E:\QuanTriServer"
Set-Location .\scripts
.\01-download-drive.ps1
.\02-install-vmware.ps1     # sẽ tự hỏi UAC
.\03-disable-hyperv-vbs.ps1 # sẽ tự hỏi UAC rồi yêu cầu REBOOT  <-- quan trọng nhất
# --- khởi động lại máy, sau đó ---
.\04-create-vms.ps1
.\99-verify.ps1
```

---

## 3. Cách B — Làm thủ công từng bước

Đọc theo thứ tự trong thư mục [`docs/`](docs/):

| # | Tài liệu | Nội dung |
|---|---|---|
| 00 | [Tổng quan](docs/00-tong-quan.md) | Kiến trúc lab, sơ đồ |
| 01 | [Tải tài liệu](docs/01-tai-tai-lieu.md) | Tải từ Google Drive |
| 02 | [Cài VMware](docs/02-cai-vmware.md) | Cài VMware WS 16.2.4 + key |
| 03 | [Tắt Hyper-V/VBS](docs/03-tat-hyperv-vbs.md) | **Chống lag — bắt buộc** |
| 04 | [Tạo máy ảo](docs/04-tao-vm.md) | Tạo 2 VM |
| 05 | [Cài Windows](docs/05-cai-os.md) | Cài OS trong VM |
| 06 | [VMware Tools](docs/06-vmware-tools.md) | Cài Tools (hết lag chuột) |
| 07 | [Tối ưu hiệu năng](docs/07-toi-uu-hieu-nang.md) | 3D, RAM, CD-ROM |
| 08 | [Bài lab](docs/08-lab-domain-dhcp-gpo.md) | Domain/DHCP/GPO theo video |

Gặp lỗi? Xem [troubleshooting.md](troubleshooting.md).

---

## 4. Cấu trúc repo

```
quantri-server-lab/
├── AGENTS.md                 # hướng dẫn cho AI agent (opencode)
├── README.md                 # file này
├── KEYS.md                   # serial VMware + key Windows Server
├── troubleshooting.md        # xử lý sự cố
├── docs/                     # hướng dẫn thủ công từng bước
├── scripts/                  # script PowerShell tự động hoá
└── templates/                # mẫu .vmx để tạo VM
```

---

## 5. Lưu ý pháp lý

Repo chia sẻ cho mục đích **học tập**. `KEYS.md` chứa key bản quyền — xem cảnh báo trong đó.
Windows/VMware là tài sản của Microsoft / Broadcom. Hãy cân nhắc dùng bản quyền hợp lệ.
