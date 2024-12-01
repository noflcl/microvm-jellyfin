{ pkgs, inputs, ... }:
{
  imports =
    [
      inputs.sops-nix.nixosModules.sops
    ];
  ###
  # System
  ###
  system.stateVersion = "24.05";

  ###
  # Intel Hardware Acceleration
  ###
  nixpkgs.config.packageOverrides = pkgs: {
  vaapiIntel = pkgs.vaapiIntel.override { enableHybridCodec = true; };
  };
  hardware.opengl = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      vaapiIntel
      vaapiVdpau
      libvdpau-va-gl
      intel-compute-runtime # OpenCL filter support (hardware tonemapping and subtitle burn-in)
    ];
  };

  ###
  # Networking
  ###
  networking = {
    hostName = "vm-jellyfin";
    networkmanager.enable = true;
    firewall = {
      enable = true;
      trustedInterfaces = [ "tailscale0" ];
      allowedTCPPorts = [ ];
      allowedUDPPorts = [ ];
    };
  };

  systemd.services = {
    NetworkManager-wait-online.enable = false;
  };

  ###
  # Users
  ###
  users.users = {
    root = {
      password = "";
    };
    jellyfin = {
      isSystemUser = true;
      description = "Jellyfin user account";
      extraGroups = [ ];
    };
  };
  users.motd = ''

888b     d888 d8b                         888     888 888b     d888        888888          888 888           .d888 d8b
8888b   d8888 Y8P                         888     888 8888b   d8888          "88b          888 888          d88P"  Y8P
88888b.d88888                             888     888 88888b.d88888           888          888 888          888
888Y88888P888 888  .d8888b 888d888 .d88b. Y88b   d88P 888Y88888P888           888  .d88b.  888 888 888  888 888888 888 88888b.
888 Y888P 888 888 d88P"    888P"  d88""88b Y88b d88P  888 Y888P 888           888 d8P  Y8b 888 888 888  888 888    888 888 "88b
888  Y8P  888 888 888      888    888  888  Y88o88P   888  Y8P  888           888 88888888 888 888 888  888 888    888 888  888
888   "   888 888 Y88b.    888    Y88..88P   Y888P    888   "   888           88P Y8b.     888 888 Y88b 888 888    888 888  888
888       888 888  "Y8888P 888     "Y88P"     Y8P     888       888           888  "Y8888  888 888  "Y88888 888    888 888  888
                                                                            .d88P                       888
                                                                          .d88P"                   Y8b d88P
                                                                         888P"                      "Y88P"


    Intro Skipper is built and installed so use a client that supports it 🎉
  '';

  environment.interactiveShellInit = ''
    export PS1="\n\[\033[1;31m\][\[\e]0;\u@\h:\w\a\] \u @\[\033[0;35m\] \h\[\033[1;31m\]: \w]\n $ \[\033[0m\]"
    color_prompt=yes
    alias vi="vim"
    alias nano="vim"
    alias edit="vim"
  '';

  ###
  # Services
  ###
  services.tailscale.enable = true;

  services.jellyfin = {
    enable = true;
    openFirewall = true;
    user = "jellyfin";
    group = "users";
    cacheDir = "/jellyfin/cache";
    configDir = "/jellyfin/config";
    dataDir = "/jellyfin/data";
    logDir = "/jellyfin/logs";
  };

  # Skip intro overlay
  nixpkgs.overlays = with pkgs; [
    (
      final: prev:
        {
          jellyfin-web = prev.jellyfin-web.overrideAttrs (finalAttrs: previousAttrs: {
            installPhase = ''
              runHook preInstall

              # this is the important line
              sed -i "s#</head>#<script src=\"configurationpage?name=skip-intro-button.js\"></script></head>#" dist/index.html

              mkdir -p $out/share
              cp -a dist $out/share/jellyfin-web

              runHook postInstall
            '';
          });
        }
    )
  ];

  ###
  # Packages
  ###
  environment.systemPackages = with pkgs; [
    btop
    jellyfin
    jellyfin-web
    jellyfin-ffmpeg
    vim
  ];

  ###
  # Virtual Machine
  ###
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
      size = 8 * 1024;
    }];

    shares = [{
      proto = "9p";
      tag = "ro-store";
      source = "/nix/store";
      mountPoint = "/nix/.ro-store";
    } {
      proto = "9p";
      tag = "movies";
      source = "/home/shoci/Downloads/torrent/movies";
      mountPoint = "/mnt/media/movies";
    } {
      proto = "9p";
      tag = "series";
      source = "/home/shoci/Downloads/torrent/tv";
      mountPoint = "/mnt/media/series";
    }];

    # Intel iGPU for quick sync
    # devices = [ {
    #   bus = "pci";
    #   path = "00:02.0 0300";
    # } ];
  };
}
