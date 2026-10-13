# 02 — Cài VMware Workstation 16.2.4

File cài: `E:\QuanTriServer\vmware\VMware-workstation-full-16.2.4-20089737.exe`
Serial: xem [../KEYS.md](../KEYS.md).

## Cách 1 — Cài thủ công (GUI)
1. Nhấp đôi file `.exe` → **Next**.
2. Chấp nhận EULA → **Next**.
3. Chọn **"Install Windows Hypervisor Platform (WHP)"** — *có thể bỏ*, vì ta sẽ **tắt** Hyper-V ở bước 03 (bật WHP lại gây chậm). Nếu chưa chắc, cứ để mặc định.
4. Đường dẫn cài mặc định: `C:\Program Files (x86)\VMware\VMware Workstation` → **Next**.
5. Bỏ tick **"Check for product updates"** và **"Help improve..."** → **Next** → **Install**.
6. Sau khi cài: mở VMware → **Help → Enter Serial Number** → nhập 1 key trong `KEYS.md`.

## Cách 2 — Cài im lặng (silent)
Mở PowerShell **quyền Admin**, chạy:

```powershell
$exe = "E:\QuanTriServer\vmware\VMware-workstation-full-16.2.4-20089737.exe"
$serial = "ZF3R0-FHED2-M80TY-8QYGC-NPKYF"   # đổi nếu key này không hợp lệ
Start-Process -FilePath $exe -Verb RunAs -Wait -ArgumentList @(
  "/s",
  "/v`"/qn EULAS_AGREED=1 SERIALNUMBER=$serial AUTOSOFTWAREUPDATE=0 DATACOLLECTION=0`""
)
```

> Sẽ hiện hộp thoại **UAC → bấm Yes**. Cài xong không cần mở GUI.
> Kiểm tra: `Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\* | Where DisplayName -like '*VMware Workstation*'`

## Cách 3 — Dùng script
```powershell
.\scripts\02-install-vmware.ps1
```

## Kiểm tra
```powershell
& "C:\Program Files (x86)\VMware\VMware Workstation\vmrun.exe" -T ws list
```
Kỳ vọng: in ra `Total running VMs: 0` (không lỗi).

> **Cập nhật license:** vào **Help → Enter Serial Number**, dán từng key trong `KEYS.md` cho đến khi chấp nhận.

## Bước tiếp theo
➡️ Sang [03-tat-hyperv-vbs.md](03-tat-hyperv-vbs.md) — **bắt buộc**, đây là bước chống lag.
