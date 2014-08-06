let rec fact n =
  if n > 1
  then (Pry.breakpoint (); n) * fact (n - 1)
  else n

let _ =
  fact 5
