# 09 — Dung lượng & chọn ổ đĩa

> Repo **tự thích ứng** với máy bạn (số ổ, dung lượng, RAM). Xem [10-thich-ung-may.md](10-thich-ung-may.md).
> Preflight tự chọn hồ sơ: **Đủ / Thoải mái / Tiết kiệm / Siêu tiết kiệm** tùy dung lượng trống.

Cài lab này tốn khá nhiều dung lượng. Đây là cách kiểm tra máy đủ điều kiện và cài vào **ổ nào**.

## 1. Cần bao nhiêu dung lượng?

| Hạng mục | Dung lượng |
|---|---:|
| Bộ tài liệu tải về (2 ISO + VMware + video + PDF) | **~13.5 GB** |
| Đỉnh tạm khi giải nén | ~15 GB |
| 2 đĩa ảo VM (đĩa "thin", đặt 40–60 GB mỗi cái tùy hồ sơ) | *cấp phát thực tế* |
| — sau khi cài OS + Tools (mỗi VM) | ~10–15 GB |
| — sau khi làm hết bài lab | ~15–30 GB/VM |
| **Tổng khuyến nghị trống trên ổ chứa lab** | **≥ 80 GB** |
| **Ngưỡng tối thiểu (hồ sơ Siêu tiết kiệm)** | **32 GB** |

> Chỉ **VMware Workstation** (~1 GB) cài vào ổ `C:`. Còn lại (ISO, VM, video) nằm trong `$LAB`
> trên ổ bạn chọn.

## 2. Chọn ổ đĩa thế nào?

**Tự động (khuyến nghị):** script `00-preflight.ps1` tự liệt kê các ổ cố định và **đề xuất ổ
còn trống nhiều nhất (bỏ qua C:)**. Sau đó nhớ lựa chọn vào `lab.config.json`.

Chỉ định thủ công:
```powershell
.\scripts\00-preflight.ps1 -Lab "D:\QuanTriServer" -Save
```

Quy tắc chung:
- **Không** đặt `$LAB` trên `C:` nếu ổ C: ít trống.
- Ưu tiên **SSD/NVMe** (VM chạy nhanh hơn nhiều).
- Ổ còn **≥ 80 GB trống** là thoải mái; **42–60 GB** dùng hồ sơ Tiết kiệm;
  **32–42 GB** vẫn cài được (Siêu tiết kiệm); **< 32 GB** thì không đủ.

## 3. `lab.config.json` hoạt động ra sao?

- Mọi script đọc chung file này → **không còn lệch đường dẫn** giữa các bước.
- File **không được commit** (đã có trong `.gitignore`) vì chứa đường dẫn máy bạn.
- Mẫu tham khảo: `lab.config.example.json`.

Cấu trúc:
```json
{
  "Lab": "E:\\QuanTriServer",
  "DataDrive": "E:",
  "VmwareInstallDir": "C:\\Program Files (x86)\\VMware\\VMware Workstation",
  "DriveFolderId": "1khCYAzXvKSkpeot1Rg7PG4A5wyjWqLGK",
  "Profile": "Du",
  "MinFreeGB": 80,
  "RecommendedFreeGB": 80
}
```

Nếu chưa có `lab.config.json`, script tự dùng **giá trị mặc định + tự dò ổ trống nhiều nhất**.
Muốn đổi ổ: chạy lại `00-preflight.ps1 -Lab "<ổ mới>" -Save`.

## 4. Kiểm tra máy trước khi cài

```powershell
.\scripts\00-preflight.ps1
```
Script kiểm: OS 64-bit, **CPU ảo hoá (VT-x/AMD-V)**, RAM, ổ đĩa + dung lượng, Python/gdown,
Internet, Hyper-V/VBS, quyền Admin. Kết quả `PASS` / `WARN` / `FAIL`.

- Nếu **FAIL** (vd ảo hoá tắt trong BIOS) → sửa rồi chạy lại.
- Nếu **WARN** → vẫn cài được, thêm `-Force` để bỏ qua cảnh báo.

Tự cài Python/gdown nếu thiếu:
```powershell
.\scripts\00-preflight.ps1 -InstallDeps -Save
```

## 5. Antivirus

Antivirus (Windows Defender, BKAV...) có thể làm chậm và chặn thao tác trên file VM.
**Loại trừ thư mục `$LAB`** khỏi danh sách quét:

- **Windows Defender:** `Add-MpPreference -ExclusionPath "E:\QuanTriServer"` *(cần Admin)*
- **BKAV / AV khác:** vào Settings → Exclusions → thêm `E:\QuanTriServer`.

## 6. Dọn dung lượng khi ổ gần đầy

- Windows: `cleanmgr` (Disk Cleanup), `Storage Sense`.
- Xoá cache trình duyệt, file tạm, Recycle Bin.
- Với đĩa ảo VM: **VM → Settings → Hard Disk → Compact** (thu hồi khoảng trống).

Gặp vấn đề? Xem [../troubleshooting.md](../troubleshooting.md).
