#!/bin/bash

set -e

# Trigger a GitHub Pages rebuild.
cd $(dirname "$0")
uuidgen > rebuild
git add rebuild && git commit -m 'Rebuild'
git push
