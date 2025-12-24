#############################################
# Main Orchestration File
# Azure Hyper-V Migration Lab
#############################################

# Keep only locals here; resources moved to network.tf, hyperv.tf and sqlvm.tf
locals {
  common_tags = {
    Environment = "Migration-Lab"
    Owner       = "Cloud-Team"
    Platform    = "Azure"
    ManagedBy   = "Terraform"
  }
  install_script_b64 = base64encode(file("${path.module}/scripts/install-hyperv.ps1"))
}
