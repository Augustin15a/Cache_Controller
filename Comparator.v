module Comparator #(
	parameter size_data
)(
	input [size_data - 1:0]data_X,
	input [size_data - 1:0]data_Y,
	output  result
);
//acest module compara cate un bit din data_X cu data_Y, folosind poarta XNOR 
//incarcand rezultatul in result_per_bit. La final prim mai multe porti and aflam result
wire [size_data - 1:0]result_per_bit;//partial result
wire [size_data - 2:0]partial_result;
genvar i,j;
generate 
	for(i = 0; i < size_data; i = i + 1)
		begin : equal
			xnor(result_per_bit[i],data_X[i],data_Y[i]);
		end
endgenerate
generate
    for(j = 0; j < size_data - 1; j = j + 1)
		begin : and_for_partial_result
			if(j == 0)
				begin
					and(partial_result[0], result_per_bit[0], result_per_bit[1]);
				end
			else
				begin
					and(partial_result[j], partial_result[j-1], result_per_bit[j+1]);
				end
		end
endgenerate
buf(result,partial_result[size_data - 2]);
endmodule