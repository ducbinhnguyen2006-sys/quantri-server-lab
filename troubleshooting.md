# Troubleshooting — Xử lý sự cố

## 1. VM cực kỳ lag / giật / "Just a moment" rất lâu
**Nguyên nhân số 1:** Hyper-V/VBS đang bật trên host → VMware chạy chế độ ULM.
- Kiểm tra: `Get-ComputerInfo -Property HyperVisorPresent` → nếu `True` là bị.
- Khắc phục: làm [docs/03-tat-hyperv-vbs.md](docs/03-tat-hyperv-vbs.md) rồi **reboot**.
- Kiểm tra log VM: `%VM dir%\vmware.log` — tìm dòng `Monitor Mode: ULM` / `Hyper-V detected by CPUID`.

**Nguyên nhân phụ:**
- Chưa cài **VMware Tools** → cài ngay ([docs/06](docs/06-vmware-tools.md)).
- Ổ cứng host sắp đầy (< 10 GB) → dọn bớt.
- Power plan = Balanced → đổi sang **High Performance**: `powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c`.
- CD-ROM đang "Connected" gây polling → ngắt ([docs/07](docs/07-toi-uu-hieu-nang.md)).

## 2. Lỗi power-on: `E1000PCI: failed to register e1000e device`
VM không bật lên được / DevicePowerOn fail.
- **Nguyên nhân:** NIC ảo dùng `e1000e` không tương thích (virtualHW 19).
- **Khắc phục:** tắt VM → mở `.vmx` → sửa:
  ```ini
  ethernet0.virtualDev = "e1000"
  ```
  (bỏ chữ `e` cuối). Lưu → bật lại.

## 3. `gdown` báo `'charmap' codec can't encode character ...`
Xảy ra khi tên file/thư mục có dấu tiếng Việt trên console Windows.
- **Khắc phục:** đặt biến môi trường trước khi chạy:
  ```powershell
  $env:PYTHONUTF8 = "1"
  $env:PYTHONIOENCODING = "utf-8"
  ```
- Nếu 1–2 file vẫn lỗi → tải riêng bằng file ID: `python -m gdown <FILE_ID> -O "ten.mp4"`.

## 4. Sửa `.vmx` xong nhưng bị ghi đè / mất thay đổi
VMware **ghi lại `.vmx` khi VM tắt máy**.
- **Khắc phục:** chỉ sửa `.vmx` khi VM đã **tắt hẳn** và **đóng** VMware, hoặc sửa qua **VM → Settings** (GUI) để VMware tự ghi đúng.

## 5. Mở VMware GUI từ script/agent bị treo
`Start-Process vmware.exe` trong tool shell làm tiến trình treo tới timeout.
- **Khắc phục:** **tự mở VMware bằng tay** (Start menu). Đừng launch GUI từ script.

## 6. `vmrun` báo `The virtual machine is not powered on`
- Chưa bật VM, hoặc đường dẫn `.vmx` sai. Kiểm tra lại path, dùng `vmrun -T ws list`.

## 7. `& "đường dẫn có dấu cách\vmrun.exe" -T ws ...` lỗi parser
Trong PowerShell, khi đường dẫn có dấu cách phải dùng **call operator** đúng cách:
```powershell
$vmrun = "C:\Program Files (x86)\VMware\VMware Workstation\vmrun.exe"
& $vmrun -T ws list
```
Không nhồi cả chuỗi lệnh vào `Invoke-Expression`.

## 8. Chuột bị "kẹt" ở cạnh màn hình / không tích hợp
Chưa cài **VMware Tools** hoặc Tools chưa chạy. Cài lại Tools ([docs/06](docs/06-vmware-tools.md)).
Đảm bảo **VM → Settings → Options → Client ... / Input** để mặc định.

## 9. Không join domain được
- Client **DNS phải trỏ về IP của DC** (ví dụ `192.168.10.10`), không phải DNS của VMware.
- Kiểm tra `ping lab.local`, `nslookup lab.local`.
- Đảm bảo client là **Windows 10 Pro** (Home không join domain được).
- Tài khoản dùng để join phải có quyền (Administrator của domain).

## 10. Client không nhận IP từ DHCP
- Scope đã **Activate** chưa? DHCP đã **Authorize** trong AD chưa?
- Client để IPv4 ở chế độ **Obtain automatically**.
- `ipconfig /release` → `ipconfig /renew`.
- Kiểm tra 2 máy cùng dải mạng ảo (NAT/Host-only) và cùng VMnet.

## 11. GPO không áp dụng
- GPO đã **Link** đúng OU chứa user/máy chưa? (Security Filtering).
- Client chạy `gpupdate /force`, đăng xuất/đăng nhập lại.
- Kiểm tra `gpresult /r` xem GPO có trong danh sách áp dụng không.

## 12. Hết dung lượng ổ đĩa
- Đĩa ảo đặt ở ổ còn trống (E:). Dọn file tạm, xoá snapshot cũ.
- Trong guest có thể bị đầy → `cleanmgr`, xoá `%temp%`.

## 13. Cần BẬT LẠI Hyper-V sau khi làm lab
```powershell
bcdedit /set hypervisorlaunchtype auto
dism /online /enable-feature /featurename:Microsoft-Hyper-V-All /all /norestart
# reboot
```

---
Nếu gặp lỗi khác, copy dòng log/thông báo lỗi và hỏi opencode:
> *"Đọc troubleshooting.md trong repo quantri-server-lab, giúp tôi sửa lỗi: <dán lỗi>"*
