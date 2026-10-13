# 04 — Tạo 2 máy ảo (VM)

Ta tạo VM **trước khi** cài Windows. Có 2 đường:
- **A.** Tạo qua GUI (dễ).
- **B.** Tạo qua dòng lệnh + template `.vmx` (nhanh, dùng script có sẵn).

Thông số chung:

| | WinSV2019 | Win10 |
|---|---|---|
| guestOS | `windows9srv-64` | `windows9-64` |
| RAM | 4096 MB | 6144 MB |
| CPU | 2 | 2 |
| Disk | 60 GB (SCSI lsilogic) | 60 GB (SCSI lsilogic) |
| NIC | `nat`, `e1000` | `nat`, `e1000` |
| ISO | Win SV 2019.iso | Windows10_full.iso |

> ⚠️ **NIC phải là `e1000`, TUYỆT ĐỐI không dùng `e1000e`** — sẽ lỗi
> `E1000PCI: failed to register e1000e device` và VM không bật được.

---

## Cách A — Tạo qua GUI
1. Mở VMware Workstation → **File → New Virtual Machine** → **Typical**.
2. **Installer disc image (ISO)**: trỏ tới file ISO (Win SV 2019 hoặc Win10).
   - Nếu bị hỏi chọn kiểu ở bước sau, **bỏ qua Easy Install** (chọn *"I will install the operating system later"* cũng được nếu muốn tự cài).
3. Đặt tên VM + nơi lưu: `E:\QuanTriServer\VMs\WinSV2019` (và `...\Win10`).
4. Disk: **60 GB**, *Store as a single file*.
5. **Customize Hardware** trước khi Finish:
   - Memory: **4096 MB** (Server) / **6144 MB** (Win10).
   - Processors: **2**.
   - Network Adapter: **NAT**.
   - **Display → Accelerate 3D graphics (tick).**
6. **Finish**. Lặp lại cho VM thứ hai.

---

## Cách B — Dòng lệnh + template (dùng script)
```powershell
.\scripts\04-create-vms.ps1 -Lab "E:\QuanTriServer"
```
Script sẽ:
1. Tạo thư mục `$LAB\VMs\WinSV2019` và `$LAB\VMs\Win10`.
2. Dùng `vmware-vdiskmanager` tạo đĩa ảo 60 GB.
3. Copy `.vmx` từ `templates/` và thay đường dẫn ISO.

### Làm tay (nếu thích)
```powershell
$vm = "C:\Program Files (x86)\VMware\VMware Workstation"
$LAB = "E:\QuanTriServer"

# Đĩa ảo 60GB
& "$vm\vmware-vdiskmanager.exe" -c -s 60GB -a lsilogic -t 0 "$LAB\VMs\WinSV2019\WinSV2019.vmdk"
& "$vm\vmware-vdiskmanager.exe" -c -s 60GB -a lsilogic -t 0 "$LAB\VMs\Win10\Win10.vmdk"

# Rồi copy templates\WinSV2019.vmx.template -> $LAB\VMs\WinSV2019\WinSV2019.vmx
# và sửa lại đường dẫn ISO trong file.
```

---

## Kiểm tra power-on (không mở GUI)
```powershell
$vmrun = "C:\Program Files (x86)\VMware\VMware Workstation\vmrun.exe"
& $vmrun -T ws start "E:\QuanTriServer\VMs\WinSV2019\WinSV2019.vmx" nogui
& $vmrun -T ws list
# Kỳ vọng: Total running VMs: 1
& $vmrun -T ws stop "E:\QuanTriServer\VMs\WinSV2019\WinSV2019.vmx" hard
```

> Nếu báo lỗi NIC → mở `.vmx` (khi VM đã tắt) kiểm tra dòng `ethernet0.virtualDev = "e1000"`.

## Bước tiếp theo
➡️ [05-cai-os.md](05-cai-os.md)
