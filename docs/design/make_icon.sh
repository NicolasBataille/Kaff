#!/bin/sh
# Rasterise docs/design/app-icon.svg en 1024×1024 dans le catalogue d'icônes de l'app (watchOS masque en cercle).
set -eu
cd "$(dirname "$0")/../.."
rsvg-convert -w 1024 -h 1024 docs/design/app-icon.svg -o "Kaff Watch App/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
echo "écrit Kaff Watch App/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
