module \$_DLATCH_P_ (input E, input D, output Q);
        //sg13g2_dlhq_1 _TECHMAP_DLATCH_P ( .D(D), .Q(Q), .GATE(E));
	reg val;
	always @*
	   if( E ) 
		val = D;
	assign Q = val;
endmodule
