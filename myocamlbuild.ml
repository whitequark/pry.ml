open Ocamlbuild_plugin

let () = dispatch (
  function
  | After_rules ->
    flag ["ocaml"; "compile"; "safe_string"] & A"-safe-string";

    rule "ocaml: o -> liba" ~prod:"src/libcamlrunpry.a" ~dep:"src/pry_stubs.o"
      (fun env builder -> Cmd(S[
        A"ar"; A"crs"; P"src/libcamlrunpry.a"; P"src/pry_stubs.o"
      ]));

    dep ["ocaml";"link";"link_pry"] ["src/libcamlrunpry.a"];
    let wrap names = "-Wl," ^ (String.concat "," (List.map (fun n -> "--wrap," ^ n) names)) in
    flag ["ocaml";"link";"link_pry"] & S[
      A"-cclib"; A(wrap ["caml_debugger_init";"caml_debugger";"caml_debugger_cleanup_fork"]);
      A"-cclib"; A"-lcamlrun";
    ];

    ocaml_lib "src/pry";
    flag ["ocaml";"link";"use_pry"] & S[A"-custom";A"-runtime-variant";A"pry";A"-I";A"src/"]

  | _ -> ())
