(* BuckleScript compiler
 * Copyright (C) 2015-2016 Bloomberg Finance L.P.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, with linking exception;
 * either version 2.1 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 *)

(* Author: Hongbo Zhang  *)


(* This module would  only work with js backend, since it requires 
   [nativeint] behaves as js  numbers 
 *)

open Nativeint
type t = { lo : nativeint ; hi : nativeint}


let min_int = { lo = 0n; hi =  0x80000000n }

let one = {lo = 1n; hi = 0n}

let not {lo; hi }  = {lo = lognot lo; hi = lognot hi } 

let of_int32 (lo : nativeint) = 
  if lo < 0n then 
    {lo ; hi = -1n }
  else {lo ; hi = 0n }


let add 
    ({lo = this_low_; hi = this_high_} : t ) 
    ({lo = other_low_; hi = other_high_} : t ) = 

  let a48 = shift_right_logical this_high_  16 in
  let a32 = logand this_high_  0xFFFFn in
  let a16 = shift_right_logical this_low_  16 in
  let a00 = logand this_low_  0xFFFFn in

  let b48 = shift_right_logical other_high_  16 in
  let b32 = logand other_high_   0xFFFFn in
  let b16 = shift_right_logical other_low_  16 in
  let b00 = logand other_low_  0xFFFFn in

  let c48 = ref 0n in 
  let c32 = ref 0n in 
  let c16 = ref 0n in 
  let c00 = ref 0n in
  begin 
    c00 := add a00  b00;
    c16 := shift_right_logical !c00  16;
    c00 := logand !c00  0xFFFFn;

    c16 := add (add !c16 a16)  b16;
    c32 := shift_right_logical  !c16  16;
    c16 := logand !c16  0xFFFFn;

    c32 := add (add !c32 a32)  b32;
    c48 := shift_right_logical !c32 16;
    c32 := logand !c32  0xFFFFn;

    c48 := add (add !c48 a48)  b48;
    c48 := logand !c48 0xFFFFn;

    {lo = logor (shift_left !c16  16)  !c00; 
     hi =  logor (shift_left !c48  16)  !c32
    }
  end 
let neg ({lo; hi} as x) =
  if x == min_int then 
    min_int 
  else add (not x) one


let sub x y = 
  add x (neg y)

let lsl_ ({lo; hi} as x) numBits = 
  if numBits = 0 then
    x 
  else if numBits >= 32 then 
    {lo =0n; hi = Nativeint.shift_left lo (numBits - 32) }
  else 
    {lo = Nativeint.shift_left lo numBits; 
     hi = 
       Nativeint.logor 
         (Nativeint.shift_right_logical lo (32 - numBits))
         (Nativeint.shift_left hi numBits)
    }

let lsr_ ({lo; hi} as x) numBits =   
  if numBits = 0 then x 
  else 
    let offset = numBits - 32 in
    if offset = 0 then  
      {hi = 0n; lo = hi}
    else if offset > 0 then 
      {hi = 0n; lo = Nativeint.shift_right_logical hi offset  }
    else 
      { hi = Nativeint.shift_right_logical hi numBits;
        lo = 
          Nativeint.logor 
            (Nativeint.shift_left hi (-offset))
            (Nativeint.shift_right_logical lo numBits)
      }      

let asr_ ({lo; hi } as x) numBits = 
  if numBits = 0  then
    x 
  else
  if numBits < 32  then
    {
      hi = Nativeint.shift_right hi numBits;
      lo = 
       Nativeint.logor
         (Nativeint.shift_left hi (32 - numBits)) (* zero filled *)
         (Nativeint.shift_right_logical lo numBits);

    }    
  else 
    {
      hi = if hi >= 0n then  0n  else -1n;
      lo = Nativeint.shift_right hi (numBits - 32)
    }
  
  
(* Dispatched by the compiler, idea: should we do maximum sharing 
*)
(* let xor {lo = this_lo; hi= this_hi} {lo = other_lo; hi = other_hi} =  *)
(*   { *)
(*     lo = Nativeint.logxor this_lo other_lo;  *)
(*    hi = Nativeint.logxor this_hi other_hi  *)
(*   } *)
