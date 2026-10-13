# 10 — Cơ chế thích ứng mọi máy

Repo tự dò cấu hình máy rồi **chọn hồ sơ phù hợp** — không cần máy bạn giống máy tác giả.
Chạy `.\scripts\00-preflight.ps1` để xem hồ sơ; hoặc `.\scripts\install-all.ps1` để làm hết.

## 1. Chọn ổ đĩa (1 / 2 / 3 ổ đều được)
- Preflight liệt kê **mọi ổ cố định**, chọn **ổ trống nhiều nhất**, ưu tiên **≠ C:**.
- Máy **chỉ 1 ổ** → dùng C: (kèm cảnh báo). **2–3 ổ** → ổ rộng nhất.
- Ép buộc: `.\scripts\00-preflight.ps1 -Lab "D:\QuanTriServer" -Save`
- Ổ ngoài (USB SSD): thêm `-IncludeRemovable`.

## 2. Hồ sơ theo dung lượng (ổ đã chọn)
| Trống | Hồ sơ | Tự động làm |
|---|---|---|
| ≥ 80 GB | **Đủ** | Tải đủ, đĩa ảo 60 GB, 2 VM song song |
| 60–80 GB | **Thoải mái** | Bỏ video (~2 GB) |
| 42–60 GB | **Tiết kiệm** | Bỏ video + tải staged + đĩa ảo 40 GB + xoá ISO sau cài |
| 32–42 GB | **Siêu tiết kiệm** | Như trên + cài **từng VM một** + compact |
| < 32 GB | **Không đủ** | Dừng, hướng dẫn dọn/đổi ổ |

## 3. Hồ sơ theo RAM
| RAM host | Win10 | Server 2019 | vCPU | Kiểu chạy |
|---|---:|---:|---:|---|
| ≥ 16 GB | 6 GB | 4 GB | 2 | 2 VM song song |
| 12–16 GB | 4 GB | 3 GB | 2 | 2 VM song song |
| 8–12 GB | 3 GB | 2 GB | 1 | **1 VM mỗi lần** |
| < 8 GB | — | — | — | Dừng (không đủ) |

## 4. `lab.config.json`
Preflight ghi hồ sơ vào đây (`Profile`, `VmRamWin10MB`, `VmDiskGB`, `SkipVideos`, `StagedDownload`,
`CleanupIso`, `OneVmAtATime`...). Các script 01/04/05/06 đọc lại để tự điều chỉnh.
Xem mẫu: `lab.config.example.json`.

## 5. Tải theo giai đoạn (tiết kiệm dung lượng)
- **Stage 1**: VMware + ISO Windows 10 (+ PDF; video nếu không bỏ).
- **Stage 2**: ISO Windows Server 2019 (tải sau khi cài xong Win10).
- Danh sách file ID lấy tự động bằng `gdown --json`, lưu ở `scripts/drive-files.json`.
  Nếu không dò được → tải cả folder rồi xoá video.

## 6. Offline (không có mạng)
Đã tải tài liệu ở nơi khác? Dùng:
```powershell
.\scripts\01-download-drive.ps1 -SourceDir "D:\BoTaiLieu"
# hoặc
.\scripts\install-all.ps1 -SourceDir "D:\BoTaiLieu"
```

## 7. Cảnh báo tự động
Preflight cảnh báo: ổ **HDD** (nên dùng SSD), đang dùng **pin**, **antivirus**, Windows build cũ,
**VMware đã cài** (bỏ qua bước 02), và **ước tính thời gian tải** theo tốc độ mạng.

## 8. Chạy một lệnh
```powershell
.\scripts\install-all.ps1                 # tương tác
.\scripts\install-all.ps1 -DryRun -Unattended   # chỉ kiểm tra + in kế hoạch
.\scripts\install-all.ps1 -Resume         # chạy tiếp sau reboot / sau mỗi VM
```
Trạng thái lưu ở `lab.state.json` (không commit).
