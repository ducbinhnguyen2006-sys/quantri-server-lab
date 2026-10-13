# 06 — Cài VMware Tools (hết lag chuột / màn hình)

**Dấu hiệu chưa có Tools:** chuột bị "kẹt" ở mép màn hình, độ phân giải kém, kéo thả file không được, màn hình giật.

## Thực hiện (cho MỖI VM, làm lần lượt)

### Win10
1. Bật VM Win10, đăng nhập.
2. Trên thanh menu VMware: **VM → Install VMware Tools...**
   - VMware sẽ gắn đĩa Tools vào ổ CD của guest.
   - (Ở máy host, VMware tự dùng `C:\Program Files (x86)\VMware\VMware Workstation\windows.iso`.)
3. Trong guest: mở **This PC** → thấy ổ **D: VMware Tools** → nhấp đôi `setup.exe` (hoặc `setup64.exe`).
4. Bấm **Next** liên tục → **Install** → **Finish** → **Restart**.
5. Sau khi reboot: chuột mượt, độ phân giải tự động, copy-paste giữa host↔guest chạy.

### WinSV2019
Làm y hệt các bước trên.

---

## Cách không dùng menu (gắn ISO thủ công)
Nếu menu **Install VMware Tools** không hiện, sửa `.vmx` (khi VM đã tắt) để trỏ CD-ROM tới file ISO của VMware:
```
ide1:0.fileName = "C:\Program Files (x86)\VMware\VMware Workstation\windows.iso"
ide1:0.deviceType = "cdrom-image"
ide1:0.startConnected = "TRUE"
```
Rồi bật VM và chạy `setup.exe` trong ổ D:.

## Kiểm tra
```powershell
# Trong guest, PowerShell:
& "C:\Program Files\VMware\VMware Tools\VMwareToolboxCmd.exe" -v
```
Nếu in ra phiên bản (vd `12.x.x`) là đã cài đúng.

> Sau khi cài Tools xong cả 2 VM, **ngắt CD-ROM** (bước 07) để tránh VMware polling gây giật.

## Bước tiếp theo
➡️ [07-toi-uu-hieu-nang.md](07-toi-uu-hieu-nang.md)
