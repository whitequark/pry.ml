open Ocamlbuild_plugin

let () = dispatch (
  function
  | After_rules ->
    flag ["ocaml"; "compile"; "safe_string"] & A"-safe-string"

  | _ -> ())
