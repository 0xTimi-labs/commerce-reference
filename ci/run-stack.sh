#!/bin/sh
set -eu

stack=${1:-}
mode=${2:-quick}
case "$mode" in quick|full) ;; *) printf 'invalid CI mode: %s\n' "$mode" >&2; exit 2 ;; esac

case "$stack" in
  rust)
    command -v cargo >/dev/null 2>&1 || { printf '%s\n' 'cargo is required for Rust CI' >&2; exit 1; }
    [ -f Cargo.toml ] || { printf '%s\n' 'Cargo.toml is required for Rust CI' >&2; exit 1; }
    [ -f Cargo.lock ] || { printf '%s\n' 'Cargo.lock is required for deterministic Rust CI' >&2; exit 1; }
    [ -f rust-toolchain.toml ] || { printf '%s\n' 'rust-toolchain.toml is required to pin Rust CI' >&2; exit 1; }
    cargo fmt --all -- --check
    cargo clippy --locked --all-targets --all-features -- -D warnings
    if [ "$mode" = full ]; then
      cargo test --locked --all-targets --all-features
    else
      cargo test --locked --all-targets
    fi
    ;;
  node)
    command -v node >/dev/null 2>&1 || { printf '%s\n' 'node is required for Node CI' >&2; exit 1; }
    command -v npm >/dev/null 2>&1 || { printf '%s\n' 'npm is required for Node CI' >&2; exit 1; }
    [ -f package.json ] || { printf '%s\n' 'package.json is required for Node CI' >&2; exit 1; }
    [ -f package-lock.json ] || { printf '%s\n' 'package-lock.json is required for deterministic Node CI' >&2; exit 1; }
    [ -f .node-version ] || { printf '%s\n' '.node-version is required to pin Node CI' >&2; exit 1; }
    npm ci --ignore-scripts --no-audit --no-fund
    for task in format:check lint typecheck test; do
      TASK=$task node -e 'const p=require("./package.json"); process.exit(p.scripts?.[process.env.TASK] ? 0 : 1)' || {
        printf 'package.json must define script %s\n' "$task" >&2
        exit 1
      }
      npm run "$task"
    done
    if [ "$mode" = full ] && TASK=test:full node -e 'const p=require("./package.json"); process.exit(p.scripts?.[process.env.TASK] ? 0 : 1)'; then
      npm run test:full
    fi
    ;;
  *)
    printf 'unknown stack: %s\n' "$stack" >&2
    exit 2
    ;;
esac
