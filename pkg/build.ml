#!/usr/bin/env ocaml
#directory "pkg"
#use "topkg.ml"

let () =
  Pkg.describe "ppx_deriving_protobuf" ~builder:`OCamlbuild [
    Pkg.bin "src/pry.byte" ~dst:"pry-ml";
    Pkg.doc "README.md";
    Pkg.doc "LICENSE.txt";
    Pkg.doc "CHANGELOG.md"; ]
