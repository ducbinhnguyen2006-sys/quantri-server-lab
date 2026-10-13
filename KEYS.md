# 🔑 Keys bản quyền (VMware & Windows Server 2019)

> ⚠️ **CẢNH BÁO:** Repo này đang ở chế độ **public**. Các key dưới đây ai cũng đọc được.
> Chỉ dùng cho mục đích **học tập / lab cá nhân**. Việc dùng key không có bản quyền là vi phạm
> điều khoản của nhà sản xuất và repo có thể bị GitHub gỡ. Nếu không muốn lộ key, hãy:
> - Chuyển repo sang **private**, hoặc
> - Xóa file này khỏi repo và lưu key ở nơi riêng.

## 1. VMware Workstation 16.2.4 — Serial

Nhập khi cài đặt, hoặc vào **Help → Enter Serial Number**.

```
ZF3R0-FHED2-M80TY-8QYGC-NPKYF
YF390-0HF8P-M81RQ-2DXQE-M2UT6
ZF71R-DMX85-08DQY-8YMNC-PPHV8
FC11K-00DE0-0800Z-04Z5E-MC8T6
```

> Chỉ cần **1 key** hoạt động là đủ. Thử lần lượt từ trên xuống.

## 2. Windows Server 2019 — Product Key

| Edition | Key |
|---|---|
| Datacenter | `WMDGN-G9PQG-XVVXX-R3X43-63DFG` |
| Standard | `N69G4-B89J2-4G8F4-WWYCC-J464C` |
| Essentials | `WVDHN-86M7X-466P6-VHXV7-YY726` |

### Kích hoạt qua KMS (cần mạng, CMD quyền Administrator)

**Datacenter:**
```cmd
slmgr /ipk WMDGN-G9PQG-XVVXX-R3X43-63DFG
slmgr /skms kms.digiboy.ir
slmgr /ato
```

**Standard:**
```cmd
slmgr /ipk N69G4-B89J2-4G8F4-WWYCC-J464C
slmgr /skms kms.digiboy.ir
slmgr /ato
```

## 3. Windows 10

Bản `Windows10_full.iso` trong bộ tài liệu tự kích hoạt / không yêu cầu key khi cài.
Nếu được hỏi key, chọn **"I don't have a product key"** để cài tiếp.
