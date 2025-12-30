# Configuring ssh to use GNOME Keyring's askpass for password prompts
{
  config,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    seahorse
    libsecret
  ];

  # Set SSH_ASKPASS env variable
  home.sessionVariables = {
    SSH_ASKPASS = "${pkgs.seahorse}/libexec/seahorse/ssh-askpass";
    SSH_ASKPASS_REQUIRE = "prefer";
  };
}
