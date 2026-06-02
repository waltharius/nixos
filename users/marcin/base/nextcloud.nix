# users/marcin/base/nextcloud.nix
#
# Nextcloud desktop client configuration for marcin.
# Declaratively manages the sync-exclusion list so that build artefacts,
# VCS metadata, and editor temporary files are never uploaded.
{ ... }: {
  xdg.configFile."Nextcloud/sync-exclude.lst".text = ''
    *.part
    .~lock.*
    ~$*
    .*.sw?
    .*~
    Desktop.ini
    Thumbs.db
    .dropbox
    .dropbox.attr

    .stfolder
    .stignore
    .stversions/

    .stfolder/
    .stversions/
    */.stfolder
    */.stignore
    */.stversions/

    .git/
    */.git/
    *.orig
    *.rej
    .git/index.lock

    node_modules/
    */node_modules/
    __pycache__/
    */__pycache__/
    .pytest_cache/
    */.pytest_cache/
    target/
    */target/
    build/
    */build/
    dist/
    */dist/

    *.tmp
    *.temp
    *.log
    .DS_Store
  '';
}
