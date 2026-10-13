# 07 — Tối ưu hiệu năng

Sau khi đã cài OS + Tools, tinh chỉnh để VM mượt. **Sửa `.vmx` khi VM đã tắt hẳn**
(VMware ghi đè file này lúc tắt máy).

## Cách 1 — Script
```powershell
.\scripts\05-optimize-vmx.ps1 -Lab "E:\QuanTriServer"
```

## Cách 2 — GUI (VM → Settings)
Với mỗi VM, chọn **VM → Settings**:

| Mục | Giá trị |
|---|---|
| Memory | Win10 = **6144 MB**, WinSV2019 = **4096 MB** |
| Processors | **2** |
| Display → **Accelerate 3D graphics** | **Bật** (tick) |
| Display → **Graphics memory** | kéo lên tối đa (256 MB – 8 GB tuỳ bản) |
| **CD/DVD** | **Bỏ tick "Connect at power on"** (ngắt để hết giật) |
| Sound Card | **Remove** (không cần cho lab) |
| USB | giữ nguyên |

## Cách 3 — Sửa trực tiếp `.vmx`
Mở `E:\QuanTriServer\VMs\Win10\Win10.vmx` bằng Notepad (**sau khi tắt VM**), thêm/đổi:

```ini
mks.enable3d = "TRUE"
svga.vramSize = "268435456"
svga.guestBackedPrimaryAware = "TRUE"
ide1:0.startConnected = "FALSE"
sound.present = "FALSE"
```

Giải thích:
- `mks.enable3d = TRUE` — bật tăng tốc đồ hoạ 3D.
- `svga.vramSize = 268435456` — bộ nhớ đồ hoạ **256 MB** (đơn vị byte). Có thể tăng trong GUI.
- `svga.guestBackedPrimaryAware = TRUE` — cải thiện hiển thị sau khi có Tools.
- `ide1:0.startConnected = FALSE` — **không** tự nối CD-ROM khi bật máy (giảm giật).
- `sound.present = FALSE` — tắt card âm thanh không dùng.

## Tối ưu trên HOST (Windows thật)
```powershell
# Power plan: High Performance
powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c

# (Tuỳ chọn) tắt các hiệu ứng/khởi động thừa, dọn dung lượng ổ
```

## Kiểm tra tổng thể
```powershell
.\scripts\99-verify.ps1
```

## Bước tiếp theo
➡️ [08-lab-domain-dhcp-gpo.md](08-lab-domain-dhcp-gpo.md) — bắt đầu làm bài lab.
