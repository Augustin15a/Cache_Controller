module MUX2to1(
	input x,
	input y,
	input sel,
	output out
);
wire not_sel, and_x, and_y;
not(not_sel, sel);
and(and_x, x, not_sel);
and(and_y, y, sel);
or(out, and_x, and_y);
endmodule