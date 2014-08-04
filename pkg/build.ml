#!/usr/bin/env ocaml
#directory "pkg"
#use "topkg.ml"

let () =
  Pkg.describe "pry" ~builder:`OCamlbuild [
    Pkg.lib "pkg/META";
    Pkg.lib ~exts:(Exts.interface @ [".cma"]) "src/pry";
    Pkg.lib "src/libcamlrunpry.a";
    Pkg.doc "README.md";
    Pkg.doc "LICENSE.txt";
    Pkg.doc "CHANGELOG.md"; ]
