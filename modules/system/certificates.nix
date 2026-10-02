{...}: {
  # Internal Certificates Authorities
  # These certificates are required for accessing internal infrastructure (homelab)

  security.pki.certificates = [
    # FreeIPA CA
    # Domain: home.lan
    # Used by: Atuin server (atuin.home.lan), the Proxmox web UI and API
    # (pveproxy certificate issued by FreeIPA; read by the pve exporter,
    # modules/servers/monitoring/pve.nix)
    # The PEM lives in certs/freeipa-ca.crt so modules can also point at it
    # as a file. readFile yields the same string the inline certificate did,
    # so the system CA bundle is unchanged.
    # To update: curl -o certs/freeipa-ca.crt http://ipa.home.lan/ipa/config/ca.crt
    (builtins.readFile ../../certs/freeipa-ca.crt)
  ];
}
