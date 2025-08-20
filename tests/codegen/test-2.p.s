.text
.balign 4
.globl _main
_main:
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w0, #11
	bl	_f1
	ldp	x29, x30, [sp], 16
	ret
/* end function main */

.data
.balign 8
_n:
	.int 19
/* end data */

.text
.balign 4
.globl _f1
_f1:
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
	mov	w0, #3
	bl	_f2
	ldp	x29, x30, [sp], 16
	ret
/* end function f1 */

