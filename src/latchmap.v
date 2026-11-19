module \$_DLATCH_P_ (input E, input D, output Q);
	reg val;
	always @*
	   if( E ) 
		val = D;
	assign Q = val;
endmodule
