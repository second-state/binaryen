;; NOTE: Assertions have been generated by update_lit_checks.py --all-items and should not be edited.
;; RUN: foreach %s %t wasm-opt -all --possible-types --nominal -S -o - | filecheck %s

(module
  ;; CHECK:      (type $struct (struct_subtype  data))
  (type $struct (struct))

  ;; CHECK:      (type $none_=>_none (func_subtype func))

  ;; CHECK:      (type $none_=>_ref|any| (func_subtype (result (ref any)) func))

  ;; CHECK:      (type $none_=>_i32 (func_subtype (result i32) func))

  ;; CHECK:      (type $none_=>_ref|$struct| (func_subtype (result (ref $struct)) func))

  ;; CHECK:      (type $i32_=>_none (func_subtype (param i32) func))

  ;; CHECK:      (func $no-non-null (type $none_=>_ref|any|) (result (ref any))
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (ref.null any)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (unreachable)
  ;; CHECK-NEXT: )
  (func $no-non-null (result (ref any))
    ;; Cast a null to non-null in order to get wasm to validate, but of course
    ;; this will trap at runtime. The possible-types pass will see that no
    ;; actual type can reach the function exit, and will add an unreachable
    ;; here. (Replacing the ref.as with an unreachable is not terribly useful in
    ;; this instance, but it checks that we properly infer things, and in other
    ;; cases replacing with an unreachable can be good.)
    (ref.as_non_null
      (ref.null any)
    )
  )

  ;; CHECK:      (func $nested (type $none_=>_i32) (result i32)
  ;; CHECK-NEXT:  (ref.is_null
  ;; CHECK-NEXT:   (block
  ;; CHECK-NEXT:    (block
  ;; CHECK-NEXT:     (nop)
  ;; CHECK-NEXT:     (block
  ;; CHECK-NEXT:      (block
  ;; CHECK-NEXT:       (drop
  ;; CHECK-NEXT:        (ref.null any)
  ;; CHECK-NEXT:       )
  ;; CHECK-NEXT:       (unreachable)
  ;; CHECK-NEXT:      )
  ;; CHECK-NEXT:      (unreachable)
  ;; CHECK-NEXT:     )
  ;; CHECK-NEXT:     (unreachable)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (unreachable)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $nested (result i32)
    ;; As above, but add other instructions on the outside, which can also be
    ;; replaced.
    (ref.is_null
      (loop (result (ref func))
        (nop)
        (ref.as_func
          (ref.as_non_null
            (ref.null any)
          )
        )
      )
    )
  )

  ;; CHECK:      (func $yes-non-null (type $none_=>_ref|any|) (result (ref any))
  ;; CHECK-NEXT:  (ref.as_non_null
  ;; CHECK-NEXT:   (struct.new_default $struct)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $yes-non-null (result (ref any))
    ;; Similar to the above but now there *is* an allocation, and so we have
    ;; nothing to optimize. (The ref.as is redundant, but we leave that for
    ;; other passes, and we keep it in this test to keep the testcase identical
    ;; to the above in all ways except for having a possible type.)
    (ref.as_non_null
      (struct.new $struct)
    )
  )

  ;; CHECK:      (func $breaks (type $none_=>_none)
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (block $block (result (ref any))
  ;; CHECK-NEXT:    (br $block
  ;; CHECK-NEXT:     (struct.new_default $struct)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (block $block0 (result anyref)
  ;; CHECK-NEXT:    (br $block0
  ;; CHECK-NEXT:     (block
  ;; CHECK-NEXT:      (drop
  ;; CHECK-NEXT:       (ref.null $struct)
  ;; CHECK-NEXT:      )
  ;; CHECK-NEXT:      (unreachable)
  ;; CHECK-NEXT:     )
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $breaks
    ;; Check that we notice values sent along breaks. We should optimize
    ;; nothing here.
    (drop
      (block $block (result (ref any))
        (br $block
          (struct.new $struct)
        )
      )
    )
    ;; But here we send a null so we can optimize.
    (drop
      (block $block (result (ref null any))
        (br $block
          (ref.as_non_null
            (ref.null $struct)
          )
        )
      )
    )
  )

  ;; CHECK:      (func $get-nothing (type $none_=>_ref|$struct|) (result (ref $struct))
  ;; CHECK-NEXT:  (unreachable)
  ;; CHECK-NEXT: )
  (func $get-nothing (result (ref $struct))
    ;; This function returns a non-nullable struct by type, but does not
    ;; actually return a value in practice, and our whole-program analysis
    ;; should pick that up in optimizing the callers.
    (unreachable)
  )

  ;; CHECK:      (func $get-nothing-calls (type $none_=>_none)
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (block
  ;; CHECK-NEXT:    (unreachable)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (ref.is_null
  ;; CHECK-NEXT:    (block
  ;; CHECK-NEXT:     (unreachable)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (block
  ;; CHECK-NEXT:    (block
  ;; CHECK-NEXT:     (unreachable)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (unreachable)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $get-nothing-calls
    ;; This should be optimized out since the call does not actually return any
    ;; type in practice.
    (drop
      (call $get-nothing)
    )
    ;; Test for the result of such a call reaching another instruction. We do
    ;; not optimize the ref.is_null here, because it returns an i32, and we do
    ;; not operate on such things in this pass, just references.
    (drop
      (ref.is_null
        (call $get-nothing)
      )
    )
    ;; As above, but an instruction that does return a reference, which we can
    ;; optimize away.
    (drop
      (ref.as_non_null
        (call $get-nothing)
      )
    )
  )

  ;; CHECK:      (func $two-inputs (type $i32_=>_none) (param $x i32)
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (select (result (ref any))
  ;; CHECK-NEXT:    (struct.new_default $struct)
  ;; CHECK-NEXT:    (block
  ;; CHECK-NEXT:     (unreachable)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (local.get $x)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (select (result (ref any))
  ;; CHECK-NEXT:    (block
  ;; CHECK-NEXT:     (unreachable)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (struct.new_default $struct)
  ;; CHECK-NEXT:    (local.get $x)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (select (result (ref any))
  ;; CHECK-NEXT:    (struct.new_default $struct)
  ;; CHECK-NEXT:    (struct.new_default $struct)
  ;; CHECK-NEXT:    (local.get $x)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (block
  ;; CHECK-NEXT:    (block
  ;; CHECK-NEXT:     (unreachable)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (block
  ;; CHECK-NEXT:     (unreachable)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (drop
  ;; CHECK-NEXT:     (local.get $x)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (unreachable)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $two-inputs (param $x i32)
    ;; As above, but now the outer instruction has two children, and some of
    ;; them may have a possible type - we check all 4 permutations. Only in the
    ;; case where both inputs are nothing can we optimize away the select, as
    ;; only then will the select never have anything.
    (drop
      (select (result (ref any))
        (struct.new $struct)
        (call $get-nothing)
        (local.get $x)
      )
    )
    (drop
      (select (result (ref any))
        (call $get-nothing)
        (struct.new $struct)
        (local.get $x)
      )
    )
    (drop
      (select (result (ref any))
        (struct.new $struct)
        (struct.new $struct)
        (local.get $x)
      )
    )
    (drop
      (select (result (ref any))
        (call $get-nothing)
        (call $get-nothing)
        (local.get $x)
      )
    )
  )

  ;; CHECK:      (func $locals (type $none_=>_none)
  ;; CHECK-NEXT:  (local $x anyref)
  ;; CHECK-NEXT:  (local $y anyref)
  ;; CHECK-NEXT:  (local $z anyref)
  ;; CHECK-NEXT:  (local.set $x
  ;; CHECK-NEXT:   (block
  ;; CHECK-NEXT:    (unreachable)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (local.set $z
  ;; CHECK-NEXT:   (struct.new_default $struct)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (block
  ;; CHECK-NEXT:    (drop
  ;; CHECK-NEXT:     (local.get $x)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (unreachable)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (block
  ;; CHECK-NEXT:    (drop
  ;; CHECK-NEXT:     (local.get $y)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (unreachable)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (ref.as_non_null
  ;; CHECK-NEXT:    (local.get $z)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $locals
    (local $x (ref null any))
    (local $y (ref null any))
    (local $z (ref null any))
    ;; Assign to x from a call that actually will not return anything.
    (local.set $x
      (call $get-nothing)
    )
    ;; Never assign to y.
    ;; Assign to z an actual value.
    (local.set $z
      (struct.new $struct)
    )
    ;; Get the 3 locals, to check that we optimize. We can remove x and y. Note
    ;; that we must wrap them in a cast as the locals are nullable themselves,
    ;; and it is only a cast to non-null that allows us to optimize away the
    ;; cases where there is no value possible.
    (drop
      (ref.as_non_null
        (local.get $x)
      )
    )
    (drop
      (ref.as_non_null
        (local.get $y)
      )
    )
    (drop
      (ref.as_non_null
        (local.get $z)
      )
    )
  )
)

(module
  ;; CHECK:      (type $struct (struct_subtype  data))
  (type $struct (struct))

  ;; CHECK:      (type $none_=>_none (func_subtype func))

  ;; CHECK:      (global $null anyref (ref.null any))
  (global $null (ref null any) (ref.null any))
  ;; CHECK:      (global $something anyref (struct.new_default $struct))
  (global $something (ref null any) (struct.new $struct))

  ;; CHECK:      (global $mut-null (mut anyref) (ref.null any))
  (global $mut-null (mut (ref null any)) (ref.null any))
  ;; CHECK:      (global $mut-something (mut anyref) (ref.null any))
  (global $mut-something (mut (ref null any)) (ref.null any))

  ;; CHECK:      (func $read-globals (type $none_=>_none)
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (block
  ;; CHECK-NEXT:    (drop
  ;; CHECK-NEXT:     (global.get $null)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (unreachable)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (ref.as_non_null
  ;; CHECK-NEXT:    (global.get $something)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (block
  ;; CHECK-NEXT:    (drop
  ;; CHECK-NEXT:     (global.get $mut-null)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (unreachable)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (ref.as_non_null
  ;; CHECK-NEXT:    (global.get $mut-something)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $read-globals
    ;; This global has no possible type written to it, so we can see this will
    ;; trap and optimize it away.
    (drop
      (ref.as_non_null
        (global.get $null)
      )
    )
    ;; This global has a possible type, so there is nothing to do.
    (drop
      (ref.as_non_null
        (global.get $something)
      )
    )
    ;; This mutable global has no possible types as we only write a null to it
    ;; in the function later down.
    (drop
      (ref.as_non_null
        (global.get $mut-null)
      )
    )
    ;; This function is written a non-null value later down.
    (drop
      (ref.as_non_null
        (global.get $mut-something)
      )
    )
  )

  ;; CHECK:      (func $write-globals (type $none_=>_none)
  ;; CHECK-NEXT:  (global.set $mut-null
  ;; CHECK-NEXT:   (ref.null $struct)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (global.set $mut-something
  ;; CHECK-NEXT:   (struct.new_default $struct)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $write-globals
    (global.set $mut-null
      (ref.null $struct)
    )
    (global.set $mut-something
      (struct.new $struct)
    )
  )
)

;; As above, but now with a chain of globals: A starts with a value, which is
;; copied to B, and then C, and then C is read. We will be able to optimize
;; away *-null (which is where A-null starts with null) but not *-something
;; (wihch is where A-something starts with a value).
(module
  ;; CHECK:      (type $none_=>_none (func_subtype func))

  ;; CHECK:      (type $struct (struct_subtype  data))
  (type $struct (struct))

  ;; CHECK:      (global $A-null anyref (ref.null any))
  (global $A-null (ref null any) (ref.null any))
  ;; CHECK:      (global $A-something anyref (struct.new_default $struct))
  (global $A-something (ref null any) (struct.new $struct))

  ;; CHECK:      (global $B-null (mut anyref) (ref.null any))
  (global $B-null (mut (ref null any)) (ref.null any))
  ;; CHECK:      (global $B-something (mut anyref) (ref.null any))
  (global $B-something (mut (ref null any)) (ref.null any))

  ;; CHECK:      (global $C-null (mut anyref) (ref.null any))
  (global $C-null (mut (ref null any)) (ref.null any))
  ;; CHECK:      (global $C-something (mut anyref) (ref.null any))
  (global $C-something (mut (ref null any)) (ref.null any))

  ;; CHECK:      (func $read-globals (type $none_=>_none)
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (block
  ;; CHECK-NEXT:    (drop
  ;; CHECK-NEXT:     (global.get $A-null)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (unreachable)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (ref.as_non_null
  ;; CHECK-NEXT:    (global.get $A-something)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (block
  ;; CHECK-NEXT:    (drop
  ;; CHECK-NEXT:     (global.get $B-null)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (unreachable)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (ref.as_non_null
  ;; CHECK-NEXT:    (global.get $B-something)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (block
  ;; CHECK-NEXT:    (drop
  ;; CHECK-NEXT:     (global.get $C-null)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (unreachable)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (ref.as_non_null
  ;; CHECK-NEXT:    (global.get $C-something)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $read-globals
    (drop
      (ref.as_non_null
        (global.get $A-null)
      )
    )
    (drop
      (ref.as_non_null
        (global.get $A-something)
      )
    )
    (drop
      (ref.as_non_null
        (global.get $B-null)
      )
    )
    (drop
      (ref.as_non_null
        (global.get $B-something)
      )
    )
    (drop
      (ref.as_non_null
        (global.get $C-null)
      )
    )
    (drop
      (ref.as_non_null
        (global.get $C-something)
      )
    )
  )

  ;; CHECK:      (func $write-globals (type $none_=>_none)
  ;; CHECK-NEXT:  (global.set $B-null
  ;; CHECK-NEXT:   (global.get $A-null)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (global.set $C-null
  ;; CHECK-NEXT:   (global.get $B-null)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (global.set $B-something
  ;; CHECK-NEXT:   (global.get $A-something)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (global.set $C-something
  ;; CHECK-NEXT:   (global.get $B-something)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $write-globals
    (global.set $B-null
      (global.get $A-null)
    )
    (global.set $C-null
      (global.get $B-null)
    )
    (global.set $B-something
      (global.get $A-something)
    )
    (global.set $C-something
      (global.get $B-something)
    )
  )
)

(module
  ;; CHECK:      (type $ref|any|_=>_ref|any| (func_subtype (param (ref any)) (result (ref any)) func))

  ;; CHECK:      (type $struct (struct_subtype  data))
  (type $struct (struct))

  ;; CHECK:      (type $ref|any|_ref|any|_ref|any|_=>_none (func_subtype (param (ref any) (ref any) (ref any)) func))

  ;; CHECK:      (type $none_=>_none (func_subtype func))

  ;; CHECK:      (func $never-called (type $ref|any|_=>_ref|any|) (param $x (ref any)) (result (ref any))
  ;; CHECK-NEXT:  (unreachable)
  ;; CHECK-NEXT: )
  (func $never-called (param $x (ref any)) (result (ref any))
    ;; This function is never called, so this non-nullable parameter cannot
    ;; contain any actual value, and we can optimize it away.
    (local.get $x)
  )

  ;; CHECK:      (func $recursion (type $ref|any|_=>_ref|any|) (param $x (ref any)) (result (ref any))
  ;; CHECK-NEXT:  (block
  ;; CHECK-NEXT:   (unreachable)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (unreachable)
  ;; CHECK-NEXT: )
  (func $recursion (param $x (ref any)) (result (ref any))
    ;; This function calls itself recursively. That forms a loop, but still, no
    ;; type is possible here, so we can optimize away.
    (call $recursion
      (local.get $x)
    )
  )

  ;; CHECK:      (func $called (type $ref|any|_ref|any|_ref|any|_=>_none) (param $x (ref any)) (param $y (ref any)) (param $z (ref any))
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (local.get $x)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (block
  ;; CHECK-NEXT:    (unreachable)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (local.get $z)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $called (param $x (ref any)) (param $y (ref any)) (param $z (ref any))
    ;; This function *is* called, with possible types in the first and last
    ;; parameter but not the middle, which can be optimized out.
    (drop
      (local.get $x)
    )
    (drop
      (local.get $y)
    )
    (drop
      (local.get $z)
    )
  )

  ;; CHECK:      (func $call-called (type $none_=>_none)
  ;; CHECK-NEXT:  (call $called
  ;; CHECK-NEXT:   (struct.new_default $struct)
  ;; CHECK-NEXT:   (block
  ;; CHECK-NEXT:    (drop
  ;; CHECK-NEXT:     (ref.null any)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (unreachable)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:   (block
  ;; CHECK-NEXT:    (drop
  ;; CHECK-NEXT:     (ref.null any)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (unreachable)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (call $called
  ;; CHECK-NEXT:   (block
  ;; CHECK-NEXT:    (drop
  ;; CHECK-NEXT:     (ref.null any)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (unreachable)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:   (block
  ;; CHECK-NEXT:    (drop
  ;; CHECK-NEXT:     (ref.null any)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (unreachable)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:   (struct.new_default $struct)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $call-called
    (call $called
      (struct.new $struct)
      (ref.as_non_null
        (ref.null any)
      )
      (ref.as_non_null
        (ref.null any)
      )
    )
    (call $called
      (ref.as_non_null
        (ref.null any)
      )
      (ref.as_non_null
        (ref.null any)
      )
      (struct.new $struct)
    )
  )
)

;; As above, but using indirect calls.
(module
  ;; CHECK:      (type $struct (struct_subtype  data))

  ;; CHECK:      (type $two-params (func_subtype (param (ref $struct) (ref $struct)) func))
  (type $two-params (func (param (ref $struct)) (param (ref $struct))))

  ;; CHECK:      (type $three-params (func_subtype (param (ref $struct) (ref $struct) (ref $struct)) func))
  (type $three-params (func (param (ref $struct)) (param (ref $struct)) (param (ref $struct))))

  (type $struct (struct))

  (table 10 funcref)

  (elem (i32.const 0) funcref
    (ref.func $func-2params-a)
    (ref.func $func-2params-b)
    (ref.func $func-3params)
  )

  ;; CHECK:      (table $0 10 funcref)

  ;; CHECK:      (elem (i32.const 0) $func-2params-a $func-2params-b $func-3params)

  ;; CHECK:      (func $func-2params-a (type $two-params) (param $x (ref $struct)) (param $y (ref $struct))
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (block
  ;; CHECK-NEXT:    (unreachable)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (local.get $y)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (call_indirect $0 (type $two-params)
  ;; CHECK-NEXT:   (block
  ;; CHECK-NEXT:    (drop
  ;; CHECK-NEXT:     (ref.null $struct)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (unreachable)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:   (struct.new_default $struct)
  ;; CHECK-NEXT:   (i32.const 0)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $func-2params-a (type $two-params) (param $x (ref $struct)) (param $y (ref $struct))
    (drop
      (local.get $x)
    )
    (drop
      (local.get $y)
    )
    ;; Send a value only to the second param.
    (call_indirect (type $two-params)
      (ref.as_non_null
        (ref.null $struct)
      )
      (struct.new $struct)
      (i32.const 0)
    )
  )

  ;; CHECK:      (func $func-2params-b (type $two-params) (param $x (ref $struct)) (param $y (ref $struct))
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (block
  ;; CHECK-NEXT:    (unreachable)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (local.get $y)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $func-2params-b (type $two-params) (param $x (ref $struct)) (param $y (ref $struct))
    ;; Another function with the same signature as before, which we should
    ;; optimize in the same way.
    (drop
      (local.get $x)
    )
    (drop
      (local.get $y)
    )
  )

  ;; CHECK:      (func $func-3params (type $three-params) (param $x (ref $struct)) (param $y (ref $struct)) (param $z (ref $struct))
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (local.get $x)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (block
  ;; CHECK-NEXT:    (unreachable)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (local.get $z)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (call_indirect $0 (type $three-params)
  ;; CHECK-NEXT:   (struct.new_default $struct)
  ;; CHECK-NEXT:   (block
  ;; CHECK-NEXT:    (drop
  ;; CHECK-NEXT:     (ref.null $struct)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (unreachable)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:   (block
  ;; CHECK-NEXT:    (drop
  ;; CHECK-NEXT:     (ref.null $struct)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (unreachable)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:   (i32.const 0)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (call_indirect $0 (type $three-params)
  ;; CHECK-NEXT:   (block
  ;; CHECK-NEXT:    (drop
  ;; CHECK-NEXT:     (ref.null $struct)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (unreachable)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:   (block
  ;; CHECK-NEXT:    (drop
  ;; CHECK-NEXT:     (ref.null $struct)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (unreachable)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:   (struct.new_default $struct)
  ;; CHECK-NEXT:   (i32.const 0)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $func-3params (type $three-params) (param $x (ref $struct)) (param $y (ref $struct)) (param $z (ref $struct))
    (drop
      (local.get $x)
    )
    (drop
      (local.get $y)
    )
    (drop
      (local.get $z)
    )
    ;; Send a value only to the first and third param. Do so in two separate
    ;; calls.
    (call_indirect (type $three-params)
      (struct.new $struct)
      (ref.as_non_null
        (ref.null $struct)
      )
      (ref.as_non_null
        (ref.null $struct)
      )
      (i32.const 0)
    )
    (call_indirect (type $three-params)
      (ref.as_non_null
        (ref.null $struct)
      )
      (ref.as_non_null
        (ref.null $struct)
      )
      (struct.new $struct)
      (i32.const 0)
    )
  )
)

;; As above, but using call_ref.
(module
  ;; CHECK:      (type $struct (struct_subtype  data))

  ;; CHECK:      (type $two-params (func_subtype (param (ref $struct) (ref $struct)) func))
  (type $two-params (func (param (ref $struct)) (param (ref $struct))))

  (type $struct (struct))

  ;; CHECK:      (func $func-2params-a (type $two-params) (param $x (ref $struct)) (param $y (ref $struct))
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (block
  ;; CHECK-NEXT:    (unreachable)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (local.get $y)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (call_ref
  ;; CHECK-NEXT:   (block
  ;; CHECK-NEXT:    (drop
  ;; CHECK-NEXT:     (ref.null $struct)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (unreachable)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:   (struct.new_default $struct)
  ;; CHECK-NEXT:   (block
  ;; CHECK-NEXT:    (unreachable)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $func-2params-a (type $two-params) (param $x (ref $struct)) (param $y (ref $struct))
    (drop
      (local.get $x)
    )
    (drop
      (local.get $y)
    )
    ;; Send a value only to the second param.
    (call_ref
      (ref.as_non_null
        (ref.null $struct)
      )
      (struct.new $struct)
      (ref.func $func-2params-a)
    )
  )
)

;; Array creation.
(module
  ;; CHECK:      (type $vector (array_subtype (mut f64) data))
  (type $vector (array (mut f64)))

  ;; CHECK:      (type $none_=>_none (func_subtype func))

  ;; CHECK:      (func $arrays (type $none_=>_none)
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (ref.as_non_null
  ;; CHECK-NEXT:    (array.new $vector
  ;; CHECK-NEXT:     (f64.const 3.14159)
  ;; CHECK-NEXT:     (i32.const 1)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (ref.as_non_null
  ;; CHECK-NEXT:    (array.init_static $vector
  ;; CHECK-NEXT:     (f64.const 1.1)
  ;; CHECK-NEXT:     (f64.const 2.2)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (block
  ;; CHECK-NEXT:    (drop
  ;; CHECK-NEXT:     (ref.null $vector)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (unreachable)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $arrays
    (drop
      (ref.as_non_null
        (array.new $vector
          (f64.const 3.14159)
          (i32.const 1)
        )
      )
    )
    (drop
      (ref.as_non_null
        (array.init_static $vector
          (f64.const 1.1)
          (f64.const 2.2)
        )
      )
    )
    ;; In the last case we have no possible type and can optimize.
    (drop
      (ref.as_non_null
        (ref.null $vector)
      )
    )
  )
)

;; Struct fields.
(module
  ;; CHECK:      (type $struct (struct_subtype  data))
  (type $struct (struct_subtype data))
  ;; CHECK:      (type $child (struct_subtype (field (mut (ref $struct))) (field (mut (ref $struct))) $parent))

  ;; CHECK:      (type $parent (struct_subtype (field (mut (ref $struct))) data))
  (type $parent (struct_subtype (field (mut (ref $struct))) data))
  (type $child (struct_subtype (field (mut (ref $struct))) (field (mut (ref $struct))) $parent))

  ;; CHECK:      (type $none_=>_none (func_subtype func))

  ;; CHECK:      (func $func (type $none_=>_none)
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (struct.get $child 0
  ;; CHECK-NEXT:    (struct.new $child
  ;; CHECK-NEXT:     (struct.new_default $struct)
  ;; CHECK-NEXT:     (block
  ;; CHECK-NEXT:      (drop
  ;; CHECK-NEXT:       (ref.null $struct)
  ;; CHECK-NEXT:      )
  ;; CHECK-NEXT:      (unreachable)
  ;; CHECK-NEXT:     )
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (block
  ;; CHECK-NEXT:    (drop
  ;; CHECK-NEXT:     (struct.new $child
  ;; CHECK-NEXT:      (struct.new_default $struct)
  ;; CHECK-NEXT:      (block
  ;; CHECK-NEXT:       (drop
  ;; CHECK-NEXT:        (ref.null $struct)
  ;; CHECK-NEXT:       )
  ;; CHECK-NEXT:       (unreachable)
  ;; CHECK-NEXT:      )
  ;; CHECK-NEXT:     )
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (unreachable)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (struct.get $parent 0
  ;; CHECK-NEXT:    (struct.new $parent
  ;; CHECK-NEXT:     (block
  ;; CHECK-NEXT:      (drop
  ;; CHECK-NEXT:       (ref.null $struct)
  ;; CHECK-NEXT:      )
  ;; CHECK-NEXT:      (unreachable)
  ;; CHECK-NEXT:     )
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $func
    ;; We create a child with a value in the first field and nothing in the
    ;; second. Getting the first field should not be optimized as if it
    ;; contains nothing.
    (drop
      (struct.get $child 0
        (struct.new $child
          (struct.new $struct)
          (ref.as_non_null
            (ref.null $struct)
          )
        )
      )
    )
    ;; Exactly the same but get field 1. This time we can optimize.
    (drop
      (struct.get $child 1
        (struct.new $child
          (struct.new $struct)
          (ref.as_non_null
            (ref.null $struct)
          )
        )
      )
    )
    ;; Create a parent with nothing. Even though the child wrote to the shared
    ;; field, it cannot alias here (since where we wrote the child we knew we
    ;; had an instance of the child and nothing else), so we can optimize.
    (drop
      (struct.get $parent 0
        (struct.new $parent
          (ref.as_non_null
            (ref.null $struct)
          )
        )
      )
    )
  )
)

;; As above, but with the writes to the parent and child partially flipped on
;; the shared field (see below).
(module
  ;; CHECK:      (type $struct (struct_subtype  data))
  (type $struct (struct_subtype data))
  ;; CHECK:      (type $parent (struct_subtype (field (mut (ref $struct))) data))
  (type $parent (struct_subtype (field (mut (ref $struct))) data))
  ;; CHECK:      (type $child (struct_subtype (field (mut (ref $struct))) (field i32) $parent))
  (type $child (struct_subtype (field (mut (ref $struct))) (field i32) $parent))

  ;; CHECK:      (type $none_=>_none (func_subtype func))

  ;; CHECK:      (func $func (type $none_=>_none)
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (struct.get $parent 0
  ;; CHECK-NEXT:    (struct.new $parent
  ;; CHECK-NEXT:     (struct.new_default $struct)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (struct.get $child 0
  ;; CHECK-NEXT:    (struct.new $child
  ;; CHECK-NEXT:     (block
  ;; CHECK-NEXT:      (drop
  ;; CHECK-NEXT:       (ref.null $struct)
  ;; CHECK-NEXT:      )
  ;; CHECK-NEXT:      (unreachable)
  ;; CHECK-NEXT:     )
  ;; CHECK-NEXT:     (i32.const 0)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $func
    ;; Allocate when writing to the parent's field. We cannot
    ;; optimize here.
    (drop
      (struct.get $parent 0
        (struct.new $parent
          (struct.new $struct)
        )
      )
    )
    ;; The child writes nothing to the first field. However, the parent did
    ;; write there, preventing optimization (although with a more precise
    ;; analysis we could do better in theory).
    (drop
      (struct.get $child 0
        (struct.new $child
          (ref.as_non_null
            (ref.null $struct)
          )
          (i32.const 0)
        )
      )
    )
  )
)

;; TODO: test big loop with all the things. then break it
