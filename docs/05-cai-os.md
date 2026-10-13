# 05 — Cài Windows trong máy ảo

Bước này **làm thủ công** (không tự động hoá được — cần tương tác GUI).

## A. Cài Windows Server 2019
1. Bật VM **WinSV2019** (nhấp đôi, hoặc **Power On**).
2. Bấm phím bất kỳ khi thấy *"Press any key to boot from CD..."*.
3. Chọn ngôn ngữ → **Next** → **Install now**.
4. Chọn **Windows Server 2019 Standard (Desktop Experience)** *(có giao diện — dễ dùng cho lab)*.
5. Chấp nhận EULA → chọn **Custom: Install Windows only**.
6. Chọn ổ 60 GB → **Next** → chờ cài (tự reboot vài lần).
7. Đặt mật khẩu Administrator (ví dụ `P@ssw0rd` — nhớ kỹ, cần cho lab).
8. Đăng nhập → màn hình Server Manager hiện lên là xong.
9. (Tuỳ chọn) Kích hoạt: xem `KEYS.md` phần KMS, chạy trong CMD.

## B. Cài Windows 10
1. Bật VM **Win10**.
2. *"Press any key to boot from CD..."* → bấm phím.
3. **Next** → **Install now**.
4. Nếu hỏi key → **"I don't have a product key"**.
5. Chọn **Windows 10 Pro** (Pro để join domain được).
6. **Custom install** → chọn ổ 60 GB → **Next**.
7. Khi hỏi tài khoản:
   - Ưu tiên tạo **tài khoản cục bộ**: chọn *"Offline account"* / *"Domain join instead"*
     (Win10 Pro có tuỳ chọn này). Đặt tên + mật khẩu.
8. Vào được desktop là xong.

## Sau khi cài xong cả 2
Ngay bước tiếp theo **cài VMware Tools** để hết lag:
➡️ [06-vmware-tools.md](06-vmware-tools.md)

> Mẹo: giữa lúc cài, đừng chỉnh `.vmx` — VMware sẽ ghi đè. Chỉ sửa khi VM đã tắt hẳn.
