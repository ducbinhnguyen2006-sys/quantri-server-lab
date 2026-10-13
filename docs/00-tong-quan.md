# 00 — Tổng quan lab

## Kiến trúc

```
┌─────────────────────────── MÁY THẬT (HOST) ───────────────────────────┐
│  Windows 10/11 + VMware Workstation 16.2.4                             │
│                                                                        │
│   ┌────────────────────────┐        ┌────────────────────────────┐    │
│   │  VM: WinSV2019         │        │  VM: Win10                 │    │
│   │  Windows Server 2019   │◄──────►│  Windows 10 Pro            │    │
│   │  = Domain Controller   │  NAT   │  = máy trạm client         │    │
│   │  IP: 192.168.x.10       │ (VMnet8)│  IP: 192.168.x.20         │    │
│   │  RAM 4GB / 2 CPU        │        │  RAM 6GB / 2 CPU           │    │
│   └────────────────────────┘        └────────────────────────────┘    │
│                     Mạng ảo NAT / Host-only của VMware                 │
└────────────────────────────────────────────────────────────────────────┘
```

## Vai trò 2 máy ảo
- **WinSV2019** — máy chủ: dựng **Active Directory (Domain Controller)**, **DHCP**, quản lý **User & Group**, **Shadow Copies**, phát **GPO**.
- **Win10** — máy client: **join domain**, nhận **DHCP**, kiểm tra **GPO** áp dụng.

## Nguyên tắc chống lag (đọc kỹ)
Đây là phần quan trọng nhất, quyết định lab chạy mượt hay giật:

1. **Tắt Hyper-V / VBS trên host** — mấu chốt. Khi Hyper-V bật, VMware phải chạy qua lớp
   Hyper-V (chế độ ULM) → **chậm rõ rệt**. Xem [03-tat-hyperv-vbs.md](03-tat-hyperv-vbs.md).
2. **Cài VMware Tools trong guest** — không có Tools thì chuột lag, màn hình đơ.
3. **Bật 3D acceleration + tăng RAM** cho VM.
4. **Ngắt CD-ROM** sau khi cài xong (VMware polling ổ CD gây giật).
5. **Power plan = High Performance** trên host.

## Thứ tự thực hiện
```
01 Tải tài liệu  →  02 Cài VMware  →  03 Tắt Hyper-V/VBS (+REBOOT)
   →  04 Tạo VM  →  05 Cài Windows  →  06 VMware Tools
   →  07 Tối ưu   →  08 Bài lab
```
