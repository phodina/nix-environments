{ pkgs ? import <nixpkgs> {} }:

let
  zephyrSdkVersion = "0.17.0";
  
  zephyrSdk = pkgs.stdenv.mkDerivation {
    pname = "zephyr-sdk";
    version = zephyrSdkVersion;
    
    src = pkgs.fetchurl {
      url = "https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v0.17.0/zephyr-sdk-0.17.0_linux-x86_64.tar.xz";
      hash = "sha256-51NrSHn2ic/U75wZOQadpsTPDjAwopQBddY1TnuLaeE=";
    };

    nativeBuildInputs = with pkgs; [ autoPatchelfHook ];

    buildInputs = with pkgs; [
      stdenv.cc.cc.lib
      python3
      cmake
      ninja
      dtc
      ncurses
    ];

    installPhase = ''
      mkdir -p $out
      cp -r * $out/
      
      cd $out
      ./setup.sh -t all -h -c
    '';

    dontConfigure = true;
    dontBuild = true;

    meta = with pkgs.lib; {
      description = "Zephyr SDK for embedded development";
      homepage = "https://github.com/zephyrproject-rtos/sdk-ng";
      license = licenses.asl20;
      platforms = platforms.linux;
    };
  };

  python = pkgs.python311;

  pythonEnv = python.withPackages (ps: with ps; [
    west
    pyelftools
    pyyaml
    pykwalify
    canopen
    packaging
    pyserial
    colorama
    pillow
    cbor
    intelhex
    psutil
    click
    pytest
    pytest-timeout
    tabulate
    anytree
    junitparser
  ]);

  commonTools = with pkgs; [
    # Build tools
    cmake
    ninja
    dtc
    git
    gperf
    ccache
    bzip2
    gnumake

    # Compilers and toolchains
    gcc
    clang
    llvm

    # Flashing tools
    dfu-util
    openocd

    # Documentation tools
    doxygen
    graphviz

    # Python environment
    python.pkgs.pip
    python.pkgs.virtualenv
    pythonEnv
  ];

  # Complete environment with SDK
  zephyrSdkEnv = pkgs.mkShell {
    buildInputs = commonTools ++ [ zephyrSdk ];
    shellHook = ''
      export ZEPHYR_SDK_INSTALL_DIR=${zephyrSdk}
      export ZEPHYR_TOOLCHAIN_VARIANT=zephyr

      echo "Zephyr SDK development environment activated!"
      echo "Zephyr SDK installed at: $ZEPHYR_SDK_INSTALL_DIR"
      echo ""
      echo "To initialize a new Zephyr workspace:"
      echo "  $ mkdir zephyr-workspace && cd zephyr-workspace"
      echo "  $ west init -m https://github.com/zephyrproject-rtos/zephyr --mr v4.1.0"
      echo "  $ west update"
      echo ""
      echo "To build a sample application:"
      echo "  $ cd zephyr"
      echo "  $ west build -b <board> samples/basic/blinky"
    '';
  };

  # Minimal environment without SDK, using system tools
  minimalEnv = pkgs.mkShell {
    buildInputs = commonTools;
    shellHook = ''
      export ZEPHYR_TOOLCHAIN_VARIANT=host
      
      echo "Minimal Zephyr development environment activated!"
      echo "Using host compiler toolchain for Zephyr development."
      echo "Note: This works for native development or with packaged cross-compilers."
      echo ""
      echo "To initialize a new Zephyr workspace:"
      echo "  $ mkdir zephyr-workspace && cd zephyr-workspace"
      echo "  $ west init -m https://github.com/zephyrproject-rtos/zephyr --mr v4.1.0"
      echo "  $ west update"
      echo ""
      echo "To build a sample application for host:"
      echo "  $ cd zephyr"
      echo "  $ west build -b native_posix samples/basic/blinky"
    '';
  };

  # Various cross-compiler packages
  crossCompilers = with pkgs; [
    gcc-arm-embedded     # ARM compiler (Cortex-M, etc.)
    xtensa-esp32-elf     # ESP32 compiler
  ];

  # ARM-specific environment
  armEnv = pkgs.mkShell {
    buildInputs = commonTools ++ [ pkgs.gcc-arm-embedded ];
    shellHook = ''
      export ZEPHYR_TOOLCHAIN_VARIANT=gnuarmemb
      export GNUARMEMB_TOOLCHAIN_PATH=${pkgs.gcc-arm-embedded}
      
      echo "Zephyr ARM development environment activated!"
      echo "Using GNU ARM Embedded Toolchain at: $GNUARMEMB_TOOLCHAIN_PATH"
      echo ""
      echo "To initialize a new Zephyr workspace:"
      echo "  $ mkdir zephyr-workspace && cd zephyr-workspace"
      echo "  $ west init -m https://github.com/zephyrproject-rtos/zephyr --mr v4.1.0"
      echo "  $ west update"
      echo ""
      echo "To build for an ARM board (e.g. nRF52):"
      echo "  $ cd zephyr"
      echo "  $ west build -b nrf52dk_nrf52832 samples/basic/blinky"
    '';
  };

in {
  default = minimalEnv;
  sdk = zephyrSdkEnv;
  minimal = minimalEnv;
  arm = armEnv;
}
