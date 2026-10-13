# AGENTS.md — Hướng dẫn cho opencode / AI agent

File này dành cho **AI coding agent (opencode, Claude, Cursor...)** trên máy của người cài đặt.
Đọc kỹ trước khi làm bất cứ điều gì.

## Mục tiêu của repo
Giúp dựng **lab quản trị Windows Server** trên VMware Workstation 16.2.4:
- 1 VM **Windows 10** (máy client) — thao tác nhanh, không lag.
- 1 VM **Windows Server 2019** (máy chủ Domain/DC).
- Tài nguyên: 2 ISO, VMware WS 16.2.4, 7 video bài giảng, 2 PDF (tổng ~13.5 GB).

Người dùng muốn **kết quả cuối là 2 VM chạy mượt** và làm được bài lab
Domain / Join domain / DHCP / User-Group / Shadow Copies / GPO.

## Khi nào agent nên làm gì
1. Nếu người dùng nói: *"cài lab này giúp tôi"* / *"làm theo repo này"* →
   chạy lần lượt các script trong `scripts/` **theo đúng thứ tự**.
2. Nếu người dùng muốn **làm thủ công** → hướng dẫn họ theo `docs/` (từng bước GUI).

## Trình tự thực thi (quan trọng — đúng thứ tự)
| Bước | File | Việc | Cần UAC / Reboot? |
|---|---|---|---|
| 0 | `scripts/99-verify.ps1` | Kiểm tra máy có đủ điều kiện không | Không |
| 1 | `scripts/01-download-drive.ps1` | Tải bộ tài liệu từ Google Drive | Không |
| 2 | `scripts/02-install-vmware.ps1` | Cài VMware Workstation 16.2.4 + key | **UAC (Yes)** |
| 3 | `scripts/03-disable-hyperv-vbs.ps1` | **Tắt Hyper-V/VBS — mấu chốt chống lag** | **UAC + REBOOT** |
| 4 | `scripts/04-create-vms.ps1` | Tạo 2 VM từ ISO | Không |
| 5 | *người dùng* | Cài Windows trong từng VM (GUI) | — |
| 6 | `scripts/05-optimize-vmx.ps1` | 3D accel, RAM, ngắt CD-ROM | Không |
| 7 | *người dùng* | Cài VMware Tools trong từng VM | — |
| 8 | `docs/08-lab-domain-dhcp-gpo.md` | Làm bài lab theo video | — |

## Quy tắc bắt buộc
- **Trước khi chạy `03-disable-hyperv-vbs.ps1`:** phải hỏi và cảnh báo người dùng rằng:
  - Thao tác này **cần reboot** và sẽ **tắt WSL2 / Docker Desktop / Windows Sandbox** (nếu có).
  - Đây là cách để VMware chạy hiệu năng gốc (không qua lớp Hyper-V), **giảm lag mạnh**.
- Các script cần quyền Admin phải chạy qua:
  `Start-Process powershell -Verb RunAs -ArgumentList "-File '<đường dẫn>'"`
- **Không tự ý xóa** dữ liệu người dùng. Chỉ thao tác trong `$LAB`.
- Sau khi tắt Hyper-V/VBS và reboot, **kiểm tra lại** bằng `scripts/99-verify.ps1`
  (kỳ vọng `HypervisorPresent = False`, `VirtualizationBasedSecurity = 0`).
- **Không mở GUI VMware bằng `Start-Process`** trong tool shell — tiến trình sẽ treo timeout.
  Hãy bảo người dùng **tự mở VMware bằng tay**.
- Khi tạo VM: **BẮT BUỘC** NIC dùng `ethernet0.virtualDev = "e1000"`, **KHÔNG dùng `e1000e`**
  (gây lỗi power-on: `E1000PCI: failed to register e1000e device`).

## Biến môi trường quy ước
- `$LAB` = thư mục chứa tài liệu lab. Mặc định `E:\QuanTriServer` (đổi nếu ổ khác).
- Google Drive folder ID: `1khCYAzXvKSkpeot1Rg7PG4A5wyjWqLGK`

## Gotcha đã đúc kết (đọc `troubleshooting.md` để biết chi tiết)
1. Hyper-V/VBS đang bật = **nguyên nhân lag số 1** → phải tắt.
2. Chưa cài VMware Tools = chuột lag, màn hình đơ ("Just a moment" cảm giác treo).
3. NIC `e1000e` = VM không bật lên được → đổi `e1000`.
4. `gdown` trên Windows lỗi `'charmap' codec can't encode` với tên tiếng Việt →
   set `$env:PYTHONUTF8=1`.
5. VMware ghi đè lại `.vmx` khi VM tắt máy → sửa `.vmx` **khi VM đã tắt hẳn**.

## Cách trả lời người dùng
- Ngắn gọn, tiếng Việt.
- Mỗi bước nói rõ: đang làm gì, sẽ mất bao lâu, có cần bấm gì không.
- Sau mỗi script, tóm tắt kết quả 1–2 dòng.
