{ lib
, stdenv
, makeWrapper
, tmux
, findutils
, coreutils
, gnused
, gnugrep
}:

stdenv.mkDerivation rec {
  pname = "nix-mc-cli";
  version = "1.0.0";

  src = ./.;

  nativeBuildInputs = [ makeWrapper ];

  buildInputs = [ tmux ];

  installPhase = ''
    runHook preInstall
    
    mkdir -p $out/bin
    cp nix-mc-cli.sh $out/bin/nix-mc-cli
    
    # Wrap the script to ensure required tools are in PATH
    wrapProgram $out/bin/nix-mc-cli \
      --prefix PATH : ${lib.makeBinPath [ 
        tmux 
        findutils 
        coreutils 
        gnused 
        gnugrep 
      ]}
    
    runHook postInstall
  '';

  meta = with lib; {
    description = "CLI tool for managing Minecraft servers via tmux sessions";
    longDescription = ''
      A command-line interface for managing Minecraft servers running under 
      the nix-mc NixOS module. Provides commands for listing servers, sending 
      commands, viewing logs, and connecting to interactive sessions.
    '';
    homepage = "https://github.com/aster-void/nix-mc";
    license = licenses.mit;
    maintainers = [ ];
    platforms = platforms.linux;
    mainProgram = "nix-mc-cli";
  };
}