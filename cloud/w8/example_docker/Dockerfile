# Layer nền: image Node chính thức, bản alpine cho nhẹ
FROM node:20-alpine

# Thư mục làm việc bên trong image
WORKDIR /app

# Copy riêng file khai báo dependency TRƯỚC
COPY package.json ./

# Cài dependency
RUN npm install --omit=dev

# Copy phần code còn lại SAU
COPY . .

# Cổng ứng dụng lắng nghe (mang tính tài liệu)
EXPOSE 3000

# Lệnh chạy khi container khởi động
CMD ["npm", "start"]
