namespace Leanfmt.Applicative

def whenSome [Applicative m] (o : Option α) (f : α → m Unit) : m Unit :=
  match o with
  | some a => f a
  | none => pure ()

end Leanfmt.Applicative