# Provision the Exchange Server SE Edge Transport VM.
#
# Run this from your own machine with the Azure CLI, NOT on the VM.
# Everything here is idempotent enough to re-run if a step fails part way.

$RG     = $env:RG     ; if (-not $RG)     { $RG     = 'rg-relay-demo' }
$LOC    = $env:LOC    ; if (-not $LOC)    { $LOC    = 'southeastasia' }
$VNET   = $env:VNET   ; if (-not $VNET)   { $VNET   = 'vnet-relay-demo' }
$SUBNET = 'snet-exch'
$PREFIX = '10.30.5.0/24'
$VM     = 'vm-exch'
$NAT    = $env:NAT    ; if (-not $NAT)    { $NAT    = 'nat-relay-demo' }
$APPNET = '10.30.3.0/24'   # the subnet the sending application lives on

# --- subnet -----------------------------------------------------------------
az network vnet subnet create -g $RG --vnet-name $VNET -n $SUBNET `
  --address-prefixes $PREFIX

# Outbound egress is REQUIRED, not optional: Exchange has to reach
# smtp.azurecomm.net:587 and a VM with no public IP has no route out.
az network vnet subnet update -g $RG --vnet-name $VNET -n $SUBNET `
  --nat-gateway $NAT

# --- virtual machine --------------------------------------------------------
# 64 GB RAM is Microsoft's documented minimum for the Edge Transport role.
# Premium storage is REQUIRED on any volume holding Exchange transport queues.
# No public IP and no inbound NSG rules - reach it through Azure Bastion.
az vm create -g $RG -n $VM `
  --image Win2022Datacenter `
  --size Standard_E8s_v5 `
  --vnet-name $VNET --subnet $SUBNET `
  --public-ip-address '""' `
  --nsg-rule NONE `
  --os-disk-size-gb 128 --storage-sku Premium_LRS `
  --admin-username azureuser `
  --admin-password $env:EXCH_ADMIN_PASSWORD

# --- let the application subnet reach Exchange on SMTP ----------------------
az network nsg rule create -g $RG --nsg-name nsg-app `
  -n allow-smtp-to-exch --priority 210 `
  --direction Outbound --access Allow --protocol Tcp `
  --destination-address-prefixes $PREFIX `
  --destination-port-ranges 25

Write-Output "Provisioned. Next: run 01-prereq.ps1 and 06-vcredist.ps1 on the VM."
