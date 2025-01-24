### PXE images served over TFTP

ipxe.efi and undionly.kpxe served over TFTP-HPA

PXE images built to support:

```
DNS
HTTP
HTTPS
iSCSI
NFS
TFTP
FCoE
SRP
VLAN
AoE
EFI
Menu
```

### Image build

```bash
TAG=$(date -u +'%Y%m%d')
git tag -a $TAG
git push origin $TAG
```