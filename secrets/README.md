# Secrets Directory

This directory contains encrypted secrets managed by [sops-nix](https://github.com/Mic92/sops-nix).

## Security Notes

⚠️ **IMPORTANT**: 
- Files here are **encrypted** with age and safe to commit
- **NEVER** commit `.dec` files (decrypted secrets)
- **NEVER** commit `keys.txt` or any `.key` files (private keys)
- Only **public keys** are in `.sops.yaml` - this is safe

## File Structure

- `common.yaml` - Secrets shared across all hosts (encrypted)
- `sukkub.yaml` - Sukkub-specific secrets (encrypted)
- `azazel.yaml` - Azazel-specific secrets (encrypted)

## Creating/Editing Secrets

```bash
# Edit secrets (opens in $EDITOR, automatically encrypts on save)
sops secrets/common.yaml

# View encrypted file
sops -d secrets/common.yaml
```

## Adding a New Host

1. Generate age key on the new host:
   ```bash
   age-keygen -o /var/lib/sops-nix/key.txt
   ```

2. Get the public key:
   ```bash
   age-keygen -y /var/lib/sops-nix/key.txt
   ```

3. Add public key to `.sops.yaml` in repository root

4. Re-encrypt all secrets:
   ```bash
   sops updatekeys secrets/*.yaml
   ```

## Example Secret File Format

```yaml
# secrets/common.yaml (will be encrypted)
example-password: "my-secret-password"
api-key: "1234567890abcdef"
```
