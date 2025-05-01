
# 🔍 Subdomain Enumeration Script

## ✅ Mục tiêu

**Tự động hóa toàn bộ quá trình phát hiện và phân tích subdomain** của một hoặc nhiều domain, phục vụ cho các mục tiêu như:
- Khám phá bề mặt tấn công (Attack Surface)
- Phân tích bảo mật trong giai đoạn Recon
- Tìm subdomain ẩn, wildcard và các dịch vụ HTTP đang hoạt động

---

## 🧱 Các tính năng chính

### 1. 🎯 Passive Subdomain Enumeration
Tìm subdomain bằng cách kết hợp nhiều công cụ:
- [`subfinder`](https://github.com/projectdiscovery/subfinder)
- [`assetfinder`](https://github.com/tomnomnom/assetfinder)
- [`amass`](https://github.com/owasp-amass)

👉 Kết quả được gộp lại và lọc trùng.

---

### 2. 🧹 Subdomain Filtering
Sử dụng [`massdns`](https://github.com/blechschmidt/massdns) để:
- Xác thực subdomain có tồn tại thật sự hay không
- Lọc bỏ subdomain không phân giải được

---

### 3. 🚫 Wildcard Detection
Kiểm tra và loại bỏ các domain wildcard để giảm false positives.

---

### 4. 🌐 HTTP Service Probing
Sử dụng [`httpx`](https://github.com/projectdiscovery/httpx) để:
- Kiểm tra subdomain có dịch vụ HTTP/HTTPS chạy trên các port phổ biến (80, 443, 8080, 8443)
- Lấy thông tin tiêu đề, mã phản hồi, công nghệ (tech stack)
- Ghi lại riêng những host có từ khóa quan trọng như `200 OK`, `Login`, `Admin`, `API`.

---

### 5. 🔎 Subdomain Permutation (`dnsgen`)
Dùng [`dnsgen`](https://github.com/ProjectAnte/dnsgen) để:
- Dò tìm các biến thể subdomain chưa được liệt kê
- Kết hợp với `massdns` để kiểm tra sống/chết

---

### 6. 📄 Xuất báo cáo tổng hợp
Sau mỗi lượt scan, kết quả được tổng hợp:
- Danh sách subdomain đã tìm được
- Subdomain sống
- Subdomain có dịch vụ HTTP
- Subdomain sinh ra bởi `dnsgen`
- File tóm tắt (`summary_<domain>.txt`)

---

### 7. ⚙️ Hỗ trợ đa luồng
Script hỗ trợ quét nhiều domain đồng thời bằng cách chạy theo luồng (nền) để tăng tốc độ.

---

## 📦 Yêu cầu

- `subfinder`
- `amass`
- `assetfinder`
- `massdns` (với `resolvers.txt`)
- `httpx-toolkit`
- `dnsgen`

---

## 🖥️ Cách sử dụng

```bash
chmod u+x sub.sh
./sub.sh example.com anotherdomain.com
```
