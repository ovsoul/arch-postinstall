#!/bin/bash

# Script de optimización post-instalación para AMD A8-7600B
# Autor: Script de optimización personalizado
# Hardware: AMD A8-7600B, 14GB RAM, SSD, KDE

set -e

echo "=============================================="
echo "🚀 Optimización Post-Instalación Arch Linux"
echo "   Hardware: AMD A8-7600B + KDE"
echo "=============================================="

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar si se ejecuta como root
if [[ $EUID -eq 0 ]]; then
   log_error "No ejecutes este script como root"
   exit 1
fi

# 1. ACTUALIZAR SISTEMA
log_info "Actualizando sistema..."
sudo pacman -Syu --noconfirm

# 2. LIMPIAR DRIVERS INNECESARIOS Y OPTIMIZAR GRÁFICOS
log_info "Limpiando drivers innecesarios y optimizando gráficos AMD..."

# Eliminar drivers propietarios AMD si existen (conflicto con mesa)
sudo pacman -Rns catalyst catalyst-utils --noconfirm 2>/dev/null || true
sudo pacman -Rns xf86-video-ati --noconfirm 2>/dev/null || true

# Instalar stack gráfico optimizado para Kaveri APU
sudo pacman -S --needed --noconfirm \
    mesa lib32-mesa \
    vulkan-radeon lib32-vulkan-radeon \
    vulkan-icd-loader lib32-vulkan-icd-loader \
    vulkan-tools \
    libva-mesa-driver lib32-libva-mesa-driver \
    mesa-vdpau lib32-mesa-vdpau \
    opencl-rusticl-mesa

log_success "Drivers gráficos optimizados instalados"

# 3. KERNEL OPTIMIZADO
log_info "Instalando kernel zen optimizado..."
sudo pacman -S --needed --noconfirm linux-zen linux-zen-headers

# 4. CONFIGURAR MAKEPKG PARA COMPILACIÓN OPTIMIZADA
log_info "Configurando makepkg para AMD Kaveri..."
sudo cp /etc/makepkg.conf /etc/makepkg.conf.backup

sudo tee -a /etc/makepkg.conf.new > /dev/null << 'EOF'

#########################################################################
# OPTIMIZACIONES ESPECÍFICAS PARA AMD A8-7600B (KAVERI)
#########################################################################
CPPFLAGS="-D_FORTIFY_SOURCE=2"
CFLAGS="-march=kaveri -mtune=kaveri -O2 -pipe -fno-plt -fexceptions \
        -Wp,-D_FORTIFY_SOURCE=2 -Wformat -Werror=format-security \
        -fstack-clash-protection -fcf-protection"
CXXFLAGS="$CFLAGS -Wp,-D_GLIBCXX_ASSERTIONS"
LDFLAGS="-Wl,-O1,--sort-common,--as-needed,-z,relro,-z,now"
RUSTFLAGS="-C opt-level=2 -C target-cpu=kaveri"
MAKEFLAGS="-j8"
DEBUG_CFLAGS="-g -fvar-tracking-assignments"
DEBUG_CXXFLAGS="-g -fvar-tracking-assignments"
BUILDENV=(!distcc color !ccache check !sign)
OPTIONS=(strip docs !libtool !staticlibs emptydirs zipman purge !debug lto)
INTEGRITY_CHECK=(md5)
STRIP_BINARIES="--strip-all"
STRIP_SHARED="--strip-unneeded"
STRIP_STATIC="--strip-debug"
COMPRESSGZ=(pigz -c -f -n)
COMPRESSBZ2=(pbzip2 -c -f)
COMPRESSXZ=(xz -c -z - --threads=0)
COMPRESSZST=(zstd -c -z -q - --threads=0)
COMPRESSLZ=(lzip -c -f)
COMPRESSLRZ=(lrzip -q)
COMPRESSLZO=(lzop -q)
COMPRESSZ=(compress -c -f)
COMPRESSLZ4=(lz4 -q)
EOF

sudo mv /etc/makepkg.conf.new /etc/makepkg.conf
log_success "Configuración de makepkg optimizada"

# 5. OPTIMIZACIONES DE SISTEMA
log_info "Aplicando optimizaciones de sistema..."

# Optimizaciones de kernel y memoria
sudo tee /etc/sysctl.d/99-performance.conf > /dev/null << 'EOF'
# Optimizaciones para AMD A8-7600B con 14GB RAM y SSD

# Memoria y swap
vm.swappiness=10
vm.vfs_cache_pressure=50
vm.dirty_ratio=15
vm.dirty_background_ratio=5
vm.dirty_expire_centisecs=3000
vm.dirty_writeback_centisecs=500

# Red
net.core.rmem_default=1048576
net.core.rmem_max=16777216
net.core.wmem_default=1048576
net.core.wmem_max=16777216
net.core.netdev_max_backlog=5000

# Seguridad y rendimiento
kernel.sysrq=1
kernel.panic=10
fs.file-max=2097152
EOF

# 6. CONFIGURACIÓN DE SSD
log_info "Optimizando SSD..."
sudo systemctl enable fstrim.timer

# 7. VARIABLES DE ENTORNO PARA AMD
log_info "Configurando variables de entorno para GPU AMD..."
sudo tee /etc/environment >> /dev/null << 'EOF'

# Optimizaciones AMD Radeon
RADV_PERFTEST=aco
MESA_LOADER_DRIVER_OVERRIDE=radeonsi
LIBVA_DRIVER_NAME=radeonsi
VDPAU_DRIVER=radeonsi
# Para mejor rendimiento en juegos
RADV_DEBUG=nohiz
EOF

# Variables para sesión actual
echo 'export RADV_PERFTEST=aco' >> ~/.bashrc
echo 'export MESA_LOADER_DRIVER_OVERRIDE=radeonsi' >> ~/.bashrc
echo 'export LIBVA_DRIVER_NAME=radeonsi' >> ~/.bashrc
echo 'export VDPAU_DRIVER=radeonsi' >> ~/.bashrc

# 8. INSTALAR HERRAMIENTAS ESENCIALES
log_info "Instalando herramientas esenciales..."
sudo pacman -S --needed --noconfirm \
    base-devel git curl wget \
    htop btop neofetch \
    auto-cpufreq \
    radeontop \
    mesa-utils \
    paru \
    reflector \
    pkgfile \
    man-db man-pages \
    bash-completion \
    zram-generator

# 9. CONFIGURAR AUTO-CPUFREQ
log_info "Configurando gestión automática de CPU..."
sudo systemctl enable auto-cpufreq
sudo systemctl start auto-cpufreq

# 10. CONFIGURAR ZRAM (swap comprimido en RAM)
log_info "Configurando ZRAM..."
sudo tee /etc/systemd/zram-generator.conf > /dev/null << 'EOF'
[zram0]
zram-size = ram / 4
compression-algorithm = zstd
EOF

sudo systemctl daemon-reload
sudo systemctl start systemd-zram-setup@zram0.service

# 11. OPTIMIZAR MIRRORS
log_info "Actualizando mirrors..."
sudo reflector --country Chile,Argentina,Brazil --age 12 --protocol https --sort rate --save /etc/pacman.d/mirrorlist

# 12. CONFIGURAR PACMAN
log_info "Optimizando pacman..."
sudo sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 10/' /etc/pacman.conf
sudo sed -i 's/#Color/Color/' /etc/pacman.conf

# 13. INSTALAR AUR HELPER Y PAQUETES ÚTILES
log_info "Instalando paquetes AUR útiles..."
if ! command -v paru &> /dev/null; then
    git clone https://aur.archlinux.org/paru.git /tmp/paru
    cd /tmp/paru
    makepkg -si --noconfirm
    cd -
fi

paru -S --needed --noconfirm \
    ananicy-cpp \
    irqbalance \
    prelockd \
    systemd-swap

# 14. CONFIGURAR ANANICY (gestión inteligente de procesos)
log_info "Configurando Ananicy..."
sudo systemctl enable ananicy-cpp
sudo systemctl start ananicy-cpp

# 15. CONFIGURAR PRELOCKD (preload inteligente)
sudo systemctl enable prelockd
sudo systemctl start prelockd

# 16. CONFIGURAR IRQBALANCE
sudo systemctl enable irqbalance
sudo systemctl start irqbalance

# 17. KDE OPTIMIZATIONS
log_info "Aplicando optimizaciones específicas de KDE..."

# Deshabilitar efectos pesados por defecto
kwriteconfig5 --file kwinrc --group Compositing --key Enabled true
kwriteconfig5 --file kwinrc --group Compositing --key Backend OpenGL
kwriteconfig5 --file kwinrc --group Compositing --key GLCore true
kwriteconfig5 --file kwinrc --group Compositing --key HiddenPreviews 6
kwriteconfig5 --file kwinrc --group Compositing --key OpenGLIsUnsafe false
kwriteconfig5 --file kwinrc --group Compositing --key WindowsBlockCompositing false

# Optimizar Dolphin
kwriteconfig5 --file dolphinrc --group General --key ShowFullPath true
kwriteconfig5 --file dolphinrc --group General --key ShowSpaceInfo true

# 18. CREAR SCRIPT DE MONITOREO
log_info "Creando script de monitoreo del sistema..."
cat > ~/monitor_system.sh << 'EOF'
#!/bin/bash
echo "=== MONITOREO DEL SISTEMA ==="
echo "CPU: $(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2)"
echo "Temperatura CPU: $(sensors | grep 'temp1' | head -1)"
echo "GPU: $(lspci | grep VGA)"
echo "Memoria: $(free -h | grep Mem)"
echo "Uptime: $(uptime)"
echo "=== PROCESOS TOP CPU ==="
ps aux --sort=-%cpu | head -6
echo "=== PROCESOS TOP MEMORIA ==="
ps aux --sort=-%mem | head -6
EOF
chmod +x ~/monitor_system.sh

# 19. CONFIGURACIÓN FINAL
log_info "Aplicando configuraciones finales..."

# Actualizar base de datos de archivos
sudo pkgfile --update

# Regenerar initramfs para nuevo kernel
sudo mkinitcpio -P

# Actualizar grub si existe
if [ -f /boot/grub/grub.cfg ]; then
    sudo grub-mkconfig -o /boot/grub/grub.cfg
fi

# 20. INFORMACIÓN FINAL
echo ""
echo "=============================================="
log_success "🎉 OPTIMIZACIÓN COMPLETADA"
echo "=============================================="
echo ""
log_info "Cambios aplicados:"
echo "  ✓ Drivers AMD optimizados instalados"
echo "  ✓ Kernel zen instalado"
echo "  ✓ Makepkg optimizado para Kaveri"
echo "  ✓ Optimizaciones de memoria y SSD"
echo "  ✓ Auto-cpufreq configurado"
echo "  ✓ ZRAM habilitado"
echo "  ✓ Ananicy para gestión de procesos"
echo "  ✓ Variables AMD configuradas"
echo "  ✓ KDE optimizado"
echo ""
log_warning "IMPORTANTE:"
echo "  • Reinicia el sistema para aplicar todos los cambios"
echo "  • Selecciona linux-zen en GRUB"
echo "  • Ejecuta ~/monitor_system.sh para monitorear el sistema"
echo "  • Usa 'radeontop' para monitorear GPU"
echo ""
log_info "Comandos útiles post-reinicio:"
echo "  • radeontop           - Monitor GPU"
echo "  • auto-cpufreq --stats - Estado CPU"
echo "  • sudo systemctl status ananicy-cpp"
echo "  • glxinfo | grep 'OpenGL renderer'"
echo ""
echo "¡Disfruta tu sistema optimizado! 🚀"
