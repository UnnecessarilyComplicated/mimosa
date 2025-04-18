[working-directory: 'talos']
apply-control:
  talosctl apply-config \
    -f controlplane.yaml \
    -n mimosa-control \
    -e mimosa-control \
    --config-patch @./patches/gateway.patch.yaml \
    --config-patch @./patches/endpoint.patch.yaml \
    --config-patch @./patches/tailscale.patch.yaml \
    --config-patch @./hosts/mimosa-control.patch.yaml

[working-directory: 'talos']
apply-worker number:
  talosctl apply-config \
    -f worker.yaml \
    -n mimosa-worker-{{number}} \
    -e mimosa-worker-{{number}} \
    --config-patch @./patches/gateway.patch.yaml \
    --config-patch @./patches/endpoint.patch.yaml \
    --config-patch @./patches/tailscale.patch.yaml \
    --config-patch @./hosts/mimosa-worker-{{number}}.patch.yaml

[working-directory: 'talos']
apply-all: apply-control (apply-worker "1") (apply-worker "2") (apply-worker "3")

[working-directory: 'talos']
gen-talos-config:
  talosctl gen config --with-secrets secrets.yaml mimosa https://mimosa-control

alias enc := encrypt
encrypt input:
  #!/usr/bin/env bash
  set -euo pipefail
  if [ ! -f "{{input}}" ]; then
    echo "❌ Error: File '{{input}}' not found!"
    exit 1
  fi

  encrypted_path="$(echo "{{input}}" | sed 's/\(.*\)\.\([^./]*\)$/\1.enc.\2/')"
  sops encrypt --age "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJoH8OzhTREXOyjpCpHsYjrrWJB8lx5gj5kZZl+HR1Gs lyra@requiem.garden" "{{input}}" > "${encrypted_path}"

  if [ -f .gitignore ]; then
    if ! grep -Fxq "{{input}}" .gitignore; then
      echo "{{input}}" >> .gitignore
      echo "📌 Added secret file '{{input}}' to .gitignore"
    else
      echo "ℹ️ '{{input}}' is already in .gitignore"
    fi
  fi
  
  echo "✅ Done: Encrypted 1 file to ${encrypted_path}"

decrypt:
  #!/usr/bin/env bash
  set -euo pipefail
  files=$(find . -type f -name '*.enc.*')

  if [ -z "$files" ]; then
    echo "ℹ️  No encrypted files found!"
    exit 0
  fi

  for enc_path in $files; do
    output_path="$(echo "$enc_path" | sed 's/\.enc\././')"

    echo "🔓 Decrypting '$enc_path' → '$output_path' ..."
    sops --decrypt "$enc_path" > "$output_path"
  done

  echo "✅ Done."