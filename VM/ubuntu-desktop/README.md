### VM Config
- CPU: 8 Cores
- RAM: 8 GB
- Disk: 64 GB
    - Use `Cache: Writeback` for best performance on HDD
    - Additionally after creating run `zfs set sync=disabled rpool/data/vm-<vmid>-disk-0`
- OS: Ubuntu Desktop˜

### To get running

- Add Ubuntu Desktop ISO
- Install Ubuntu Desktop
- Remove CD Drive
- Restart VM
- Login and Use!