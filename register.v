module register #(
	parameter size_reg
)(
	input [size_reg - 1:0]data,
	input write_data,
	output [size_reg - 1:0]out_reg
);
wire [size_reg - 1:0]output_flip_flop;
generate
	genvar i;
	for(i = 0;i < size_reg;i = i + 1)
		begin : D_Flip_Flop_blocks
			D_Flip_Flop block(
				.C(write_data),
				.D(data[i]),
				.Q(output_flip_flop[i])
			);
			buf(out_reg[i],output_flip_flop[i]);
		end
endgenerate

endmodule