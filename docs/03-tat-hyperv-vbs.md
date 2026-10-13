# 03 — Tắt Hyper-V / VBS (★ chống lag — BẮT BUỘC)

## Vì sao?
Khi **Hyper-V / VBS (Virtualization Based Security)** đang bật, VMware Workstation **không thể
truy cập trực tiếp** CPU ảo hoá. Nó phải chạy qua lớp Hyper-V của Windows (chế độ **ULM**),
khiến VM **chậm, giật, khó dùng**. Tắt hypervisor → VMware chạy ở chế độ gốc (native) → mượt.

## Triệu chứng khi bị ảnh hưởng
- VMware log ghi `Monitor Mode: ULM` và `Hyper-V detected by CPUID`.
- VM giật, chuột nhảy, "Just a moment" rất lâu.
- Kiểm tra nhanh trên host:
  ```powershell
  Get-ComputerInfo -Property HyperVRequirementVirtualizationFirmwareEnabled,HyperVisorPresent
  ```
  Nếu `HyperVisorPresent = True` → đang bật → cần tắt.

## ⚠️ Ảnh hưởng cần biết
Tắt Hyper-V/VBS sẽ **tắt luôn**: WSL2, Docker Desktop, Windows Sandbox, Memory Integrity.
Nếu bạn cần những thứ này, cân nhắc. Có thể bật lại sau.

---

## Cách 1 — Script (khuyến nghị)
```powershell
.\scripts\03-disable-hyperv-vbs.ps1
```
Script sẽ tự xin quyền Admin và **yêu cầu bạn REBOOT** khi xong.

## Cách 2 — Thủ công
Mở **PowerShell quyền Administrator** (chuột phải → Run as administrator). Chạy **từng nhóm**:

### 2.1. Tắt tính năng Hyper-V & nền tảng ảo hoá
```powershell
dism /online /disable-feature /featurename:Microsoft-Hyper-V-All /norestart
dism /online /disable-feature /featurename:VirtualMachinePlatform /norestart
dism /online /disable-feature /featurename:HypervisorPlatform /norestart
dism /online /disable-feature /featurename:Containers-DisposableClientVM /norestart
```

### 2.2. Tắt khởi động hypervisor trong boot
```cmd
bcdedit /set hypervisorlaunchtype off
```

### 2.3. Tắt VBS / Memory Integrity (HVCI) trong registry
```powershell
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" `
  -Name Enabled -Value 0 -PropertyType DWord -Force

New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard" `
  -Name EnableVirtualizationBasedSecurity -Value 0 -PropertyType DWord -Force
```

### 2.4. (Tuỳ chọn) Tắt trong Windows Security
**Windows Security → Device security → Core isolation → Memory integrity → Off.**

### 2.5. Khởi động lại máy
```powershell
Restart-Computer
```

---

## Xác minh sau reboot
```powershell
Get-ComputerInfo -Property HyperVisorPresent
# Kỳ vọng: HyperVisorPresent : False

Get-CimInstance -ClassName Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard |
  Select-Object VirtualizationBasedSecurityStatus
# Kỳ vọng: VirtualizationBasedSecurityStatus : 0  (Off)
```

Hoặc chạy: `.\scripts\99-verify.ps1`.

## Nếu cần BẬT LẠI Hyper-V sau này
```powershell
bcdedit /set hypervisorlaunchtype auto
dism /online /enable-feature /featurename:Microsoft-Hyper-V-All /all /norestart
dism /online /enable-feature /featurename:VirtualMachinePlatform /norestart
# reboot
```

## Bước tiếp theo
➡️ [04-tao-vm.md](04-tao-vm.md)
