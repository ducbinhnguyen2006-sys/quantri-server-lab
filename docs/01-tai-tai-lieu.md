# 01 — Tải bộ tài liệu (~13.5 GB)

## Nguồn
📁 Google Drive: https://drive.google.com/drive/folders/1khCYAzXvKSkpeot1Rg7PG4A5wyjWqLGK?usp=sharing

Folder ID: `1khCYAzXvKSkpeot1Rg7PG4A5wyjWqLGK`

## Nội dung cần có
| Mục | File / thư mục | Dung lượng |
|---|---|---|
| Phần mềm | `VMware-workstation-full-16.2.4-20089737.exe` | ~650 MB |
| ISO Server | `Win SV 2019/Win SV 2019.iso` | ~4.9 GB |
| ISO Client | `Windows10_full.iso` | ~5.6 GB |
| Bài giảng | `video/` — 7 file .mp4 | ~2 GB |
| Tài liệu | 2 file PDF | — |

## Cách 1 — Tải bằng gdown (khuyến nghị, đã test)

Máy cần **Python 3**. Mở PowerShell:

```powershell
# 1) Cài gdown
python -m pip install --upgrade gdown

# 2) BẮT BUỘC: tránh lỗi 'charmap' codec cannot encode khi tên có tiếng Việt
$env:PYTHONUTF8 = "1"
$env:PYTHONIOENCODING = "utf-8"

# 3) Tải cả folder vào ổ E:
$LAB = "E:\QuanTriServer"
New-Item -ItemType Directory -Force -Path $LAB | Out-Null
Set-Location $LAB
python -m gdown --folder 1khCYAzXvKSkpeot1Rg7PG4A5wyjWqLGK
```

> Nếu tiến trình dừng giữa chừng, chạy lại lệnh trên — gdown sẽ tiếp tục phần còn lại.

## ⚠️ Gotcha: 2 file bị lỗi khi tải folder
Thực tế khi tải, **video đầu tiên** và **PDF phần 2** có thể lỗi. Tải lại riêng bằng file ID:

```powershell
# Thay <FILE_ID> bằng ID lấy từ link Google Drive của file đó
python -m gdown <FILE_ID> -O "ten-file.mp4"
```

Cách lấy FILE_ID: mở file trên Drive → link dạng
`https://drive.google.com/file/d/<FILE_ID>/view`.

## Cách 2 — Tải thủ công qua trình duyệt
1. Mở link Drive ở trên bằng trình duyệt.
2. Với mỗi thư mục con: chuột phải → **Download** (Drive tự nén .zip nếu nhiều file).
3. Giải nén vào `E:\QuanTriServer`, giữ nguyên cấu trúc tên thư mục.

## Cách 3 — Dùng script
```powershell
.\scripts\01-download-drive.ps1 -Lab "E:\QuanTriServer"
```

## Kiểm tra sau khi tải
Cây thư mục kỳ vọng:
```
E:\QuanTriServer\
├── vmware\VMware-workstation-full-16.2.4-20089737.exe
├── Windows10_full.iso
├── Win SV 2019\Win SV 2019.iso
├── video\*.mp4
└── *.pdf
```

Đảm bảo ổ đĩa còn **trống ≥ 40 GB** để chứa VM sau này.
