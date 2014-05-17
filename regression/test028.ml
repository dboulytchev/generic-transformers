open GT

@type ('a, 'b) t = (int * string * 'a * 'b) with show, map

class ['a, 'b] print =
  object 
    inherit ['a, unit, 'b, unit, unit, unit] @t
    method value _ _ x y a b = 
      Printf.printf "%d\n" x;
      Printf.printf "%s\n" y; 
      a.fx (); 
      b.fx ()
  end

let _ =
  Printf.printf "%s\n"
    (transform(t)
       (fun _ a -> string_of_int a)
       (fun _ -> function `B -> "`B")
       (new @show[t])
       ()
       (transform(t) (fun _ a -> int_of_string a) (fun _ x -> x) (new @map[t]) () (1, "2", "3", `B))
    );
  transform(t) 
    (fun _ a -> Printf.printf "%s\n" a) 
    (fun _ -> function `B -> Printf.printf "`B\n") 
    (new print) 
    () 
    (1, "2", "a", `B)