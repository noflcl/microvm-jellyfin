# MicroVM Jellyfin

Using MicroVM to deploy a minimal virtual machine of Jellyfin running on NixOS.

[Official MicroVM docs](https://astro.github.io/microvm.nix/intro.html)

VM Specs:
  - NixOS 24.05 Uakari
  - 4 vcpu cores
  - 4 GB memory
  - 256 MB of disk
  - Intel iGPU for Quick Sync
  - Jellyfin stable
  - Intro Skipper


### PCI Passthrough

Make sure `IOMMU` is enabled first.

`lspci -nn | grep -Ei "3d|display|vga"` to get the `vendor_id`

Use the `vendor_id` to match the appropriate PCI `device_id`

`lspci -n | grep vendor_id` which returned in my case `00:02.0 0300: 8086:9a49`

```nix
devices = [ {
      bus = "pci";
      path = "00:02.0";
    }];
```

### Virtual Machine

```nix
  microvm = {
    hypervisor = "qemu";
    socket = "control.socket";
    mem = 4 * 1024;
    vcpu = 4;

    interfaces = [ {
      type = "user";
      id = "qemu";
      mac = "02:00:00:01:01:01";
    } ];

    volumes = [{
      mountPoint = "/";
      image = "vm-jellyfin.img";
      size = 256;
    }];

    shares = [{
      proto = "9p";
      tag = "ro-store";
      source = "/nix/store";
      mountPoint = "/nix/.ro-store";
    } {
      proto = "9p";
      tag = "movies";
      source = "/storage/media/movies";
      mountPoint = "/mnt/media/movies";
    } {
      proto = "9p";
      tag = "series";
      source = "/storage/media/series";
      mountPoint = "/mnt/media/series";
    }];

    # Intel iGPU for quick sync
    # devices = [ {
    #   bus = "pci";
    #   path = "00:02.0";
    # } ];
  };
```

### Running
You will need flakes enabled on the system then: `nix run .#vm-jellyfin`

This will build a `256 MB` VM image that shares your hosts `nix store` in a `r/o` state which helps drastically reduce image size and build time and the MicroVM docs touch on it [here](https://astro.github.io/microvm.nix/shares.html#sharing-a-hosts-nixstore).

There are no passwords set within the VM so your first task should be to login as `root` and run `passwd`. You can update the `jellyfin` user as well with `passwd jellyfin`


### Intro Skipper
Plugins cannot modify contents of files in the `nix store` so in order to enable Intro Skipper we must modify `jellyfin-web`. NixOS Jellyfin wiki explains it [here](https://wiki.nixos.org/wiki/Jellyfin#Intro_Skipper_plugin).

#### Enable

<u>Login with admin account</u> navigate to your `Dashboard` and go to `Plugins`

Add the repository
  - `https://manifest.intro-skipper.org/manifest.json`

Install Plugin
  - `Catalog` -> `Intro Skipper` -> Install

You need to restart the Jellyfin service now `systemctl restart jellyfin`
