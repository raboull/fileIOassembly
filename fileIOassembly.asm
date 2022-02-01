

					fp .req x29												//use register equate to define fp
					lr .req x30												//use register equate to define lr

					buf_size = 8											//define the buf_size constant

																			//define registers that will be used often
					define(i_r, w19)										//define the i variable register
					define(argc_r, w20)										//define the argc variable register
					define(argv_r, x21)										//define the argv variable register
					define(fd_r, w22)										//define the fd variable register, file descriptor that is set by openat
					define(x_r, d23)										//define the x_r variable register
					define(negFlag_r, w24)									//define the negative flag register
					define(newestTerm_r, d25)								//define the newest term register
					define(num_r, d11)										//holds the expansion term numerator
					define(den_r, d12)										//holds the expansion term denominator
					define(temp_r, d13)										//holds a temporary double value
					define(tempW_r, w14)									//holds a temporary word value
					define(result_r, d16)									//holds the result of arctan(x) function

					.data													//define the numeric global constants used by this program
term_threshold_m:	.double 0r1.0e-13										//initialize term_threshold = 1.0e-13

					.text													//define the string constants used in the program
str_echo_path:		.string "Opening: %s\n"									//message that echoes the user input file path
str_err_numArg:		.string	"Incorrect number of arguments. Exiting...\n"	//message that specifies that the wrong number of arguments was entered
str_err_open:		.string "The specified file cannot be opened.\n"		//message that the specified file cannot be opened
str_echo_val:		.string "%13.10f\t"										//message that prints the latest x value read from the input file.
str_arctan_x:		.string "%13.10f\n"										//message the prints the arctan(x) value
str_out_header:		.string "x:\t\t arctan(x):\n"							//message that contains the output table heading

					alloc = -(16 + buf_size) & -16							//define the amount of memory to allocate for the frame record and local variables
					dealloc = -alloc										//define the amount of memory to deallocate on return from the main function

					buf_s = 16												//memory offset from the fp to reach the buf_size storage location

					.balign 4												//alligns the instructions we write to make sure they are divisible by 4
					.global main											//pseudo op which sets the start label to main, it wil make sure that the main label is picked by the linker

main:				stp	fp, lr, [sp, alloc]!								//creates a frame record and allocates memory for our local variables on the stack
					mov	fp, sp												//moves the fp to the current sp location

																			//First we will read the command line input by the user
					mov	argc_r, w0											//copy argc
					mov	argv_r, x1											//copy argv
					mov	i_r, 1												//i = 1 to read the provided file path

																			//check if we have too few arguments
					mov	w9, 2												//move 2 to w9
					cmp	argc_r, w9											//compare argc with 2
					b.eq	read_path										//branch to prnt_argNumErr if argc != 2

																			//print an error message if detected incorrect number of arguments
					adrp	x0, str_err_numArg								//store the address of str_err_numArg in register x0
					add	x0, x0, :lo12:str_err_numArg						//set up 1st argument
					bl	printf												//call printf
					b	end_main											//exit the program

read_path:			adrp	x0, str_echo_path								//store the address of str_echo_path in register x0
					add	x0, x0, :lo12:str_echo_path							//set up 1st argument
					ldr	x1, [argv_r, i_r, SXTW 3]							//set up 2nd argument
					bl	printf												//call printf

																			//open the input.bin file
					mov	w0, -100											//1st argument (use cwd to indicate that the pathname is relative to the program's current working directory)
					ldr	x1, [argv_r, i_r, SXTW 3]							//2nd argument (pathname)
					mov	w2, 0												//3rd arg (read only)
					mov	w3, 0												//4th arg (not used)
					mov	x8, 56												//openat I/O request
					svc	0													//call system function
					mov	fd_r, w0											//place the value returned by openat into our file descriptor register
					cmp	fd_r, 0												//error check (want a non-neg number) in the value returned by the system function
					b.ge	open_ok											//branch to open_ok label if w0 != 0

																			//file opening error handling code that prints a message and exits the program
					adrp	x0, str_err_open								//store the address of str_err_open in register x0
					add	x0, x0, :lo12:str_err_open							//set up 1st argument
					bl	printf												//call printf
					b	end_main											//exit the program

open_ok:																	//print the header of our output table string
					adrp	x0, str_out_header								//store the address of str_out_header in register x0
					add	x0, x0, :lo12:str_out_header						//set up 1st argument
					bl	printf												//call printf

read_input:																	//read the input file one double value at a time
					mov	w0, fd_r											//1st arg (fd)
					add	x1, fp, buf_s										//2nd arg (ptr to buf)
					mov	w2, buf_size										//3rd arg (n)
					mov	x8, 63												//read I/O request
					svc	0													//call sys function
					mov	x23, x0												//store the number of bytes that were read successfully

																			//test how many bytes were read from the file
					cmp	x0, buf_size										//compare x0 (number of bytes just read from the file) and buf_size
					b.ne	close_file										//branch to the close_file label if x0 != buf_size

																			//print out the x values and the corresponding arctan(x) values
					adrp	x0, str_echo_val								//store the address of str_echo_val in register x0
					add	x0, x0, :lo12:str_echo_val							//set up 1st argument
					ldr	d0, [fp, buf_s]										//set up 2nd argument
					bl	printf												//call the printf function

					ldr	d0, [fp, buf_s]										//set up the 1st argument
					bl	arctan_fun											//branch and link to the arctan_fun label

					b	read_input											//branch to the read_input label to read the next value from the input file

																			//close the input file
close_file:			mov	w0, fd_r											//1st arg (fd)
					mov	x8, 57												//close I/O request
					svc	0													//call sys function

end_main:			ldp	fp, lr, [sp], dealloc								//we end main by deallocation of stack memory
					ret														//return control to the calling code

																			//function that computes arctan(x)
arctan_fun:			stp	fp, lr, [sp, -16]!									//creates a frame record and allocates memory for our local variables on the stack
					mov	fp, sp												//moves the fp tto the current sp location

					fmov	x_r, d0											//store the input x value in x_r

					adrp	x10, term_threshold_m							//store the address of term_threshold_m in register x10
					add	x10, x10, :lo12:term_threshold_m					//set the lower bits of address stored in x10
					ldr	d10, [x10]											//d10 = term_threshold_m

					mov	negFlag_r, 1										//this flag value let's us know to add or subtract the newest term from the result
					fmov	newestTerm_r, 1.0								//initialize the latest computed value to be larger than threshold
					fmov	num_r, x_r										//initialize the term numerator register
					fmov	den_r, 1.0										//initialize the term denominator register
					fmov	result_r, x_r									//initialize the result register

top_arctan:																	//compute another term in the expansion
																			//first compute the numerator
					fmul	num_r, num_r, x_r								//x^(current) = x^current*x = x^(current+1)
					fmul	num_r, num_r, x_r								//x^(current) = x^current*x = x^(current+1)
																			//now compute the denominator
					fmov	temp_r, 2.0										//set the temp float register to 2.0
					fadd	den_r, den_r, temp_r							//den_r = den_r + 2.0
																			//now create the latest term
					fdiv	newestTerm_r, num_r, den_r						//newestTerm_r = num_r/den_r

																			//exit the function if the newest term is smaller than our threshold value
					fabs	temp_r, newestTerm_r							//temp_r = abs(newestTerm_r)
					fcmp	temp_r, d10										//compare temp_r and d10 values
					b.lt	end_arctan_fun									//branch to end_arctan_fun label if abs(temp_r)<term_threshold_m

																			//update our negation flag, just flip the sign every time a new term is computed
					mov	tempW_r, -1											// tempW_r = -1
					mul	negFlag_r, negFlag_r, tempW_r						//negFlag_r = negRlag_r * -1

																			//branch to either add or subtract the newest term
					cmp	negFlag_r, 0										//compare negFlag_r and 0
					b.lt	subtract_term									//branch to the subtract_term label if negFlag_r < 0

add_term:			fadd 	result_r, result_r, newestTerm_r				//result_r = result_r + newestTerm_r
					b	top_arctan											//branch to the top_arctan label

subtract_term:		fsub	result_r, result_r, newestTerm_r				//result_r = result_r - newestTerm_r
					b	top_arctan											//branch to the top_arctan label

end_arctan_fun:																//print the calculated arctan value and exit the function
					adrp	x0, str_arctan_x								//store the address of str_arctan_x in register x0
					add	x0, x0, :lo12:str_arctan_x							//set up the 1st argument
					fmov	d0, result_r									//set up the 2nd argument
					bl	printf												//branch and link to the printf function

					ldp	fp, lr, [sp], 16									//we end arctan_fun by deallocation of its frame record from the stack memory
					ret														//return control to the calling code
