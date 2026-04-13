#!/bin/bash
set -euo pipefail

case "${1:-}" in
    post)
        systemctl start awg-resume-restart.service
        ;;
esac
