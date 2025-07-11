#!/bin/bash

# Script para arreglar problemas de blur/pantalla negra en KDE 6 después del suspend
# Para AMD A8-7600 con Arch Linux + KDE Plasma 6

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== KDE 6 Suspend Fix Script ===${NC}"
echo "Aplicando fixes para problemas de suspend/resume en KDE Plasma 6 con AMD"
echo

# 1. Configurar compositor KDE
echo -e "${YELLOW}[1/4]${NC} Configurando compositor KDE..."
KWIN_CONFIG="$HOME/.config/kwinrc"

# Backup del archivo original
if [ -f "$KWIN_CONFIG" ]; then
    cp "$KWIN_CONFIG" "$KWIN_CONFIG.backup.$(date +%Y%m%d_%H%M%S)"
    echo "Backup creado: $KWIN_CONFIG.backup"
fi

# Crear/modificar configuración del compositor
cat >> "$KWIN_CONFIG" << EOF

[Compositing]
Backend=OpenGL2
GLCore=false
HiddenPreviews=5
OpenGLIsUnsafe=false
WindowsBlockCompositing=true
EOF

echo "✓ Compositor configurado"

# 2. Crear script de systemd para post-resume
echo -e "${YELLOW}[2/4]${NC} Creando script systemd post-resume..."

# Obtener usuario actual
CURRENT_USER=$(whoami)

sudo tee /usr/lib/systemd/system-sleep/kde-fix << EOF > /dev/null
#!/bin/bash
# KDE Fix script para post-resume

case \$1 in
    post)
        # Esperar un momento para que el sistema se estabilice
        sleep 2
        
        # Reiniciar compositor KDE 6
        su - $CURRENT_USER -c "
            export DISPLAY=:0
            export XDG_RUNTIME_DIR=/run/user/\$(id -u $CURRENT_USER)
            
            # Para KDE 6 - usar kwin_wayland o kwin_x11 según la sesión
            if pgrep -x kwin_wayland > /dev/null; then
                kquitapp6 kwin_wayland 2>/dev/null
                sleep 1
                kwin_wayland --replace &
            else
                kquitapp6 kwin_x11 2>/dev/null
                sleep 1
                kwin_x11 --replace &
            fi
            
            # Reiniciar plasmashell para KDE 6 si es necesario
            # kquitapp6 plasmashell 2>/dev/null
            # sleep 1
            # plasmashell &
        " 2>/dev/null &
        ;;
esac
EOF

sudo chmod +x /usr/lib/systemd/system-sleep/kde-fix
echo "✓ Script systemd creado"

# 3. Actualizar GRUB con parámetros AMD
echo -e "${YELLOW}[3/4]${NC} Configurando parámetros del kernel..."

GRUB_FILE="/etc/default/grub"
GRUB_BACKUP="/etc/default/grub.backup.$(date +%Y%m%d_%H%M%S)"

# Backup de GRUB
sudo cp "$GRUB_FILE" "$GRUB_BACKUP"
echo "Backup GRUB creado: $GRUB_BACKUP"

# Verificar si ya existen los parámetros
if ! grep -q "amd_iommu=off" "$GRUB_FILE"; then
    # Agregar parámetros AMD al final de GRUB_CMDLINE_LINUX_DEFAULT
    sudo sed -i '/GRUB_CMDLINE_LINUX_DEFAULT/ s/"$/ amd_iommu=off radeon.dpm=1"/' "$GRUB_FILE"
    
    # Regenerar configuración GRUB
    echo "Regenerando configuración GRUB..."
    sudo grub-mkconfig -o /boot/grub/grub.cfg
    echo "✓ GRUB actualizado"
else
    echo "✓ Parámetros AMD ya configurados en GRUB"
fi

# 4. Crear script manual de emergencia
echo -e "${YELLOW}[4/4]${NC} Creando script de emergencia..."

cat > "$HOME/fix-display.sh" << 'EOF'
#!/bin/bash
# Script de emergencia para problemas de pantalla después del suspend en KDE 6
# Ejecutar si la pantalla sigue con problemas

echo "Aplicando fix de emergencia para KDE 6..."

# Detectar si estamos en Wayland o X11 y actuar en consecuencia
if [ "$XDG_SESSION_TYPE" = "wayland" ]; then
    echo "Detectada sesión Wayland..."
    # Para Wayland
    kquitapp6 kwin_wayland
    sleep 2
    kwin_wayland --replace &
else
    echo "Detectada sesión X11..."
    # Para X11
    kquitapp6 kwin_x11
    sleep 2
    kwin_x11 --replace &
    
    # Resetear xrandr solo en X11
    xrandr --auto
fi

echo "Fix aplicado. Si el problema persiste:"
echo "- X11: presiona Alt+Shift+F12"
echo "- Wayland: reinicia la sesión"
EOF

chmod +x "$HOME/fix-display.sh"
echo "✓ Script de emergencia creado en: $HOME/fix-display.sh"

echo
echo -e "${GREEN}=== INSTALACIÓN COMPLETADA ===${NC}"
echo
echo -e "${YELLOW}Pasos siguientes:${NC}"
echo "1. Reinicia el sistema para aplicar cambios de GRUB"
echo "2. Prueba suspend/resume"
echo "3. Si hay problemas, ejecuta: ~/fix-display.sh"
echo "4. O presiona Alt+Shift+F12 para resetear compositor"
echo
echo -e "${YELLOW}Archivos creados:${NC}"
echo "- Configuración KDE: $KWIN_CONFIG"
echo "- Script systemd: /usr/lib/systemd/system-sleep/kde-fix"
echo "- Script emergencia: $HOME/fix-display.sh"
echo "- Backups en: *.backup.*"
echo
echo -e "${RED}IMPORTANTE:${NC} Reinicia el sistema ahora para aplicar todos los cambios"
