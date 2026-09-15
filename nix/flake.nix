{
  description = "Pinned Apalache for veri temporal model checks";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/c7def046b9a883d46974757852106483d741586f";

  outputs = { self, nixpkgs }:
    let
      systems = [ "aarch64-darwin" "aarch64-linux" "x86_64-linux" ];
      forSystems = nixpkgs.lib.genAttrs systems;
    in {
      packages = forSystems (system:
        let pkgs = import nixpkgs { inherit system; };
        in rec {
          apalache = pkgs.stdenvNoCC.mkDerivation {
            pname = "apalache";
            version = "0.62.2";
            src = pkgs.fetchurl {
              url = "https://github.com/apalache-mc/apalache/releases/download/v0.62.2/apalache-0.62.2.tgz";
              sha256 = "765f610537281a0f25b8c30f2554f19523e2859c824e80e62276653ee23c10e2";
            };
            nativeBuildInputs = [ pkgs.makeWrapper ];
            dontBuild = true;
            installPhase = ''
              runHook preInstall
              mkdir -p $out/share/apalache $out/bin
              cp -R . $out/share/apalache/
              makeWrapper $out/share/apalache/bin/apalache-mc $out/bin/apalache-mc \
                --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.jdk21_headless pkgs.coreutils ]}
              runHook postInstall
            '';
            meta = {
              description = "Symbolic model checker for TLA+";
              homepage = "https://apalache-mc.org/";
              license = pkgs.lib.licenses.asl20;
              mainProgram = "apalache-mc";
            };
          };
          default = apalache;
        });
      apps = forSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.apalache}/bin/apalache-mc";
          meta.description = "Run the pinned Apalache model checker";
        };
      });
    };
}
