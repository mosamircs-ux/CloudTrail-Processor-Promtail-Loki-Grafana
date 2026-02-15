# Upload Project to EC2 Ubuntu Instance
# Run this from your Windows machine (PowerShell)

# Configuration - UPDATE THESE VALUES
$EC2_IP = "YOUR_EC2_PUBLIC_IP"
$KEY_FILE = "path\to\your-key.pem"
$LOCAL_PATH = "c:\Users\mohamedsamir\Documents\grafana_promtail"

# Upload entire project to EC2
Write-Host "Uploading project to EC2..." -ForegroundColor Green
scp -i $KEY_FILE -r $LOCAL_PATH ubuntu@${EC2_IP}:~/

Write-Host ""
Write-Host "Upload complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. SSH to your EC2 instance:" -ForegroundColor White
Write-Host "   ssh -i $KEY_FILE ubuntu@$EC2_IP" -ForegroundColor Cyan
Write-Host ""
Write-Host "2. Navigate to project directory:" -ForegroundColor White
Write-Host "   cd ~/grafana_promtail" -ForegroundColor Cyan
Write-Host ""
Write-Host "3. Run deployment script:" -ForegroundColor White
Write-Host "   chmod +x deploy-ubuntu.sh" -ForegroundColor Cyan
Write-Host "   ./deploy-ubuntu.sh" -ForegroundColor Cyan
Write-Host ""
Write-Host "4. Access Grafana:" -ForegroundColor White
Write-Host "   http://$EC2_IP:3000" -ForegroundColor Cyan
Write-Host ""
