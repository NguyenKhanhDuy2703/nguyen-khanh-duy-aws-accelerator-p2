data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = [var.aws_ami_owner]
  filter {
    name   = "name"
    values = [var.aws_ami_name]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name   = "${var.vpc_name}-ssh-key"
  public_key = tls_private_key.ssh_key.public_key_openssh
}

resource "aws_instance" "ec2_instance" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.ec2_security_group_id]
  key_name               = aws_key_pair.generated_key.key_name

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = tls_private_key.ssh_key.private_key_pem
    host        = self.public_ip
    timeout     = "5m"
  }

  provisioner "file" {
    source      = "${path.module}/../../app"
    destination = "/home/ubuntu/app"
  }

  provisioner "remote-exec" {
    inline = [
      # ── Bước 1: Cài Docker thủ công cho Ubuntu focal ────────────────────
      "echo '=== 1. CAI DOCKER ==='",
      "sudo apt-get update -y",
      "sudo apt-get install -y ca-certificates curl gnupg lsb-release",
      # Thêm GPG key và repo đúng cho focal
      "sudo install -m 0755 -d /etc/apt/keyrings",
      "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg",
      "sudo chmod a+r /etc/apt/keyrings/docker.gpg",
      "echo \"deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null",
      "sudo apt-get update -y",
      # Chỉ cài các package có sẵn trên focal — bỏ docker-model-plugin
      "sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin",
      "sudo usermod -aG docker ubuntu",
      # Ép quyền socket ngay — không cần logout/login
      "sudo chmod 666 /var/run/docker.sock",
      # Verify docker hoạt động
      "docker --version",

      # ── Bước 2: Cài kubectl & minikube ──────────────────────────────────
      "echo '=== 2. CAI KUBECTL & MINIKUBE ==='",
      "curl -LO 'https://dl.k8s.io/release/v1.30.0/bin/linux/amd64/kubectl'",
      "chmod +x ./kubectl && sudo mv ./kubectl /usr/local/bin/kubectl",
      "curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64",
      "sudo install minikube-linux-amd64 /usr/local/bin/minikube",

      # ── Bước 3: Start minikube ───────────────────────────────────────────
      # SSH đã là user ubuntu — set HOME, không cần su/sudo -i
      "echo '=== 3. KHOI CHAY MINIKUBE ==='",
      "export HOME=/home/ubuntu && minikube start --driver=docker",

      # ── Bước 4: Chờ node Ready ───────────────────────────────────────────
      "echo '=== 4. CHO K8S NODE READY ==='",
      "export HOME=/home/ubuntu && timeout 180 bash -c 'until kubectl get nodes 2>/dev/null | grep -q Ready; do echo Dang doi K8s...; sleep 5; done'",

      # ── Bước 5: Build image trong minikube ──────────────────────────────
      "echo '=== 5. BUILD IMAGE ==='",
      "export HOME=/home/ubuntu && minikube image build -t kube-container /home/ubuntu/app/",

      # ── Bước 6: Deploy ───────────────────────────────────────────────────
      "echo '=== 6. DEPLOY ==='",
      "export HOME=/home/ubuntu && kubectl apply -f /home/ubuntu/app/deployment.yaml",

      # ── Bước 7: Chờ rollout ──────────────────────────────────────────────
      "echo '=== 7. CHO DEPLOYMENT READY ==='",
      "export HOME=/home/ubuntu && kubectl rollout status deployment/my-app-deployment --timeout=120s",

      # ── Bước 8: Port-forward qua systemd (persistent, tự restart) ──────
      "echo '=== 8. TAO SYSTEMD SERVICE CHO PORT-FORWARD ==='",
      "sudo bash -c \"printf '[Unit]\\nDescription=kubectl port-forward\\nAfter=network.target\\n\\n[Service]\\nType=simple\\nUser=ubuntu\\nEnvironment=HOME=/home/ubuntu\\nExecStart=/usr/local/bin/kubectl --kubeconfig=/home/ubuntu/.kube/config port-forward --address 0.0.0.0 svc/my-app-service 30080:80\\nRestart=always\\nRestartSec=5\\n\\n[Install]\\nWantedBy=multi-user.target\\n' > /etc/systemd/system/kube-port-forward.service\"",
      "sudo systemctl daemon-reload",
      "sudo systemctl enable kube-port-forward",
      "sudo systemctl start kube-port-forward",
      "sleep 5",
      "sudo systemctl is-active kube-port-forward || true",
      "ss -tlnp | grep 30080 || echo 'Port 30080 not yet bound'",
      "echo '=== HOAN THANH! ==='"
    ]
  }

  tags = {
    Name  = "${var.vpc_name}-ec2-instance"
    Owner = var.owner
  }
}
