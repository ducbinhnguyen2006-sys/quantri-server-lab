# 08 — Bài lab theo video

Nội dung bám sát bộ 7 video trong `E:\QuanTriServer\video\`:

| # | Video | Nội dung | Lab dưới đây |
|---|---|---|---|
| 1 | `1. Bai gioi thieu.mp4` | Giới thiệu | — |
| 2 | `2.Cài đặt VMware+win10+WinSV2019.mp4` | Cài đặt | (docs 01–07) |
| 3 | `3.Domain+join domain.mp4` | Dựng Domain + join | §1, §2 |
| 4 | `4.Cài đặt cấu hình DHCP.mp4` | DHCP | §3 |
| 5 | `5.Tạo tài khoản user+group.mp4` | User & Group | §4 |
| 7 | `7.Shadw Copies Offline Files.mp4` | Shadow Copies | §5 |
| 8 | `8.Triển khai chính sách nhóm.mp4` | GPO | §6 |

> Mở song song video khi làm để theo đúng thao tác giảng viên.

---

## §0. Chuẩn bị mạng ảo
Đặt IP tĩnh cho 2 máy trong cùng dải NAT (VMnet8 thường là `192.168.x.0/24`, kiểm tra bằng
**Edit → Virtual Network Editor** trên host).

| Máy | IP | Subnet mask | Gateway |
|---|---|---|---|
| WinSV2019 (Server) | `192.168.10.10` | `255.255.255.0` | (để trống/`192.168.10.1`) |
| Win10 (Client) | `192.168.10.20` | `255.255.255.0` | `192.168.10.10` |
| DNS (cả 2) | `192.168.10.10` | | |

Cách đặt IP: **Control Panel → Network and Internet → Network Connections → Ethernet →
Properties → IPv4 → Use the following IP address**. Đặt tên máy:
- Server: `SRV2019`
- Client: `PC01`

---

## §1. Dựng Domain Controller (video 3)
Trên **WinSV2019**:
1. **Server Manager → Add roles and features** → **Next** → Role-based → chọn **SRV2019**.
2. Tick **Active Directory Domain Services** → **Add Features** → **Next** → **Install**.
3. Sau khi cài: nhấp **cờ vàng ⚠ (Notify) → Promote this server to a domain controller**.
4. Chọn **Add a new forest** → tên miền, ví dụ: **`lab.local`**.
5. Đặt **DSRM password**.
6. DNS Options: bỏ qua cảnh báo → **Next**.
7. NetBIOS name: `LAB` → **Next** → chọn **thư mục lưu DB/Log/SYSVOL** (mặc định) → **Next**.
8. **Install** → máy **tự restart**. Đăng nhập bằng `LAB\Administrator`.

Kiểm tra: **Server Manager → Tools → Active Directory Users and Computers**.
Trên client, trỏ **DNS = 192.168.10.10** để resolve được miền.

---

## §2. Join domain (video 3)
Trên **Win10**:
1. Đảm bảo DNS = `192.168.10.10` (đã làm ở §0).
2. **Settings → System → About → Rename this PC (Advanced) → Change → Domain** →
   nhập **`lab.local`** → OK.
3. Nhập tài khoản `LAB\Administrator` + mật khẩu → **Restart**.
4. Đăng nhập bằng tài khoản domain vừa tạo (nếu đã tạo user ở §4).

Kiểm tra trên Server: **ADUC → Computers** thấy `PC01`.

---

## §3. DHCP (video 4)
Trên **WinSV2019**:
1. **Server Manager → Add roles** → **DHCP Server** → Add Features → Install → **Complete DHCP configuration**.
2. **Tools → DHCP**:
   - Chuột phải **IPv4 → New Scope**.
   - Name: `VLAN10` → Start IP `192.168.10.100`, End IP `192.168.10.200`, mask `/24`.
   - Exclusions nếu cần → Lease 8 ngày.
   - **Router (Default Gateway)**: `192.168.10.10` (hoặc để trống).
   - **DNS**: `192.168.10.10` → Finish → Activate scope.
3. **Authorize** DHCP trong AD (nếu chưa).
4. Trên **Win10**: đổi IPv4 về **Obtain automatically** → `ipconfig /release` → `ipconfig /renew` → `ipconfig /all` để thấy IP cấp từ Server.

> Lưu ý: máy DHCP server nên có IP tĩnh để không tự cấp cho chính mình.

---

## §4. Tạo User & Group (video 5)
Trên **WinSV2019** → **ADUC**:
1. Tạo OU: chuột phải tên miền `lab.local` → **New → Organizational Unit** → `NhanVien`.
2. Trong `NhanVien` → **New → User** → tạo vài user (vd `nv01`, `nv02`), đặt mật khẩu.
3. Tạo Group: chuột phải OU → **New → Group** → `PhongKinhDoanh` (Global, Security).
4. Thêm user vào group: chuột phải group → **Properties → Members → Add** → chọn user.
5. (Tuỳ chọn) **New → Group** cho các phòng ban khác, gán user tương ứng.

Kiểm tra: đăng nhập client bằng user domain, xem quyền theo group.

---

## §5. Shadow Copies / Offline Files (video 7)
Trên **WinSV2019**:
1. Tạo một ổ/thư mục chia sẻ, ví dụ `E:\Data` → chuột phải → **Properties → Sharing → Advanced Sharing** → chia sẻ.
2. **Shadow Copies**: chuột phải ổ đĩa (vd E:) → **Properties → Shadow Copies → Settings** →
   - Chọn ổ → **Enable**.
   - **Schedule**: ví dụ 2 lần/ngày.
   - **Create Now** để tạo bản sao ngay.
3. Kiểm tra **Previous Versions** trên thư mục: chuột phải → **Properties → Previous Versions**.
4. **Offline Files** (trên client Win10): **Control Panel → Sync Center → Manage offline files → Enable offline files** → chọn thư mục share → **Always available offline**.

---

## §6. Triển khai GPO (video 8)
Trên **WinSV2019** → **Server Manager → Tools → Group Policy Management**:
1. Chuột phải OU `NhanVien` → **Create a GPO in this domain, and Link it here...** → đặt tên (vd `GPO-NhanVien`).
2. Chuột phải GPO → **Edit** → thao tác chính sách. Ví dụ thường gặp trong bài:
   - **Đặt hình nền desktop:** User Configuration → Policies → Administrative Templates → Desktop → Desktop → **Desktop Wallpaper** → Enabled → nhập đường dẫn ảnh (ảnh đặt trên share).
   - **Giới hạn Control Panel:** User Configuration → ... → Control Panel → **Prohibit access to Control Panel** → Enabled.
   - **Mật khẩu:** Computer Configuration → ... → Account Policies.
3. Trên client: `gpupdate /force` → đăng xuất/đăng nhập lại → kiểm tra (`gpresult /r`).

Kiểm tra áp dụng: trên Win10 chạy `gpresult /r` xem GPO đã nhận.

---

## Checklist hoàn thành
- [ ] DC `lab.local` chạy, có ADUC.
- [ ] Win10 join domain thành công.
- [ ] Có scope DHCP cấp IP cho Win10.
- [ ] Có user + group trong OU.
- [ ] Shadow Copies đã bật + tạo bản sao.
- [ ] GPO áp dụng lên client (`gpresult /r`).
