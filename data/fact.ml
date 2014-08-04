external ( > ) : 'a -> 'a -> bool = "%greaterthan"
external ( * ) : int -> int -> int = "%mulint"
external ( - ) : int -> int -> int = "%subint"

let rec fact n =
  if n > 1
  then n * fact (n - 1)
  else n

let _ =
  fact 5
