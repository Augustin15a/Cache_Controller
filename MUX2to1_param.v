module MUX2to1_param #(
	parameter size_data
)(
	input [size_data - 1:0]x,
	input [size_data - 1:0]y,
	input sel,
	output [size_data - 1:0]out
);
genvar i;
generate
    for(i = 0; i < size_data; i = i + 1)
        begin : mux32
            MUX2to1 mux(
                .x(x[i]),
                .y(y[i]),
                .sel(sel),
                .out(out[i])
            );
        end
endgenerate
endmodule