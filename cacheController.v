module cacheController(
//semnale de la cpu si spre
	input cpu_request,
	input write_request,
	input read_request,
	input clk,
	input reset,
	input [31:0]adresa,
//semnale de la cache si spre
	input  [19*4 - 1:0] tags_from_cache,
	input tags_delivered,
	output request_memory_tags,
	output [6:0]index
);
//								States
//		-IDLE       	000	Waiting for a new request
//      -COMPARE_TAG   	001	Comparing tag and decide HIT  or MISS
//		-READ HIT   	010	Accessing data for a read request found in the cache
//		-READ MISS  	011	Handling read requests when data is not in the cache
//		-WRITE HIT  	100	Managing write operations when data is found in the cache
//		-WRITE MISS 	101	Processing write operations when data is not found in the cache
//		-EVICT      	110	Evicting data from the cache according to the LRU policy

//CURRENT STATE
wire [2:0]data_current_state;
wire [2:0]out_reg_current_state;
//neg state
wire [2:0]neg_out_reg_current_state;
not(neg_out_reg_current_state[0],out_reg_current_state[0]);
not(neg_out_reg_current_state[1],out_reg_current_state[1]);
not(neg_out_reg_current_state[2],out_reg_current_state[2]);

//NEXT STATE
wire [2:0]data_next_state;

register #(
	.size_reg(3)
)current_state(
	.data(data_current_state),
	.write_data(clk),
	.out_reg(out_reg_current_state)
);
wire evict = 1'b0;
//Reset Logic
wire neg_reset;
not(neg_reset,reset);

//Caz 1 reset == 1 => neq reset = 0,
// 		deci data_current_state = fiecare bit & 0, adica transform toti bitii in 0
//Caz 2 reset == 0 => neq reset = 1,
// 		deci data_current_state = fiecare bit & 1, adica ramane la fel

and(data_current_state[0],data_next_state[0],neg_reset);
and(data_current_state[1],data_next_state[1],neg_reset);
and(data_current_state[2],data_next_state[2],neg_reset);


//										IDLE STATE

wire idle_state;//1 - esti in starea idle
//VERIFICARE STARE
//in tabelul portii nor doar cand input e 0 0 outputul e 1
nor(idle_state, out_reg_current_state[0], out_reg_current_state[1], out_reg_current_state[2]);
//salvez adresa si o impart
wire [31:0]wire_address;
wire [5:0]wire_offset;
wire [6:0]wire_index;
wire [18:0]wire_tag;

register #(
	.size_reg(32)
)address_reg(
	.data(adresa),
	.write_data(idle_state),
	.out_reg(address)
);
genvar i;
generate
	for(i = 0;i < 6; i = i + 1)
		begin : offsetblock
			buf(wire_offset[i],address[i]);
		end
endgenerate

generate
	for(i = 0;i < 7; i = i + 1)
		begin : indexblock
			buf(wire_index[i],address[i + 6]);
		end
endgenerate

generate
	for(i = 0;i < 19; i = i + 1)
		begin : tagblock
			buf(wire_tag[i],address[i + 13]);
		end
endgenerate

wire read_or_write_request;
wire tranz_compare_tag;
or(read_or_write_request,read_request,write_request);
and(tranz_compare_tag,cpu_request,read_or_write_request,idle_state);

//									COMPARE_TAG STATE
//VERIFICARE STARE
wire compare_tag_state;//COMPARE_TAG STATE 1 - esti in starea compare

and(
	compare_tag_state,//out
	neg_out_reg_current_state[2],
	neg_out_reg_current_state[1],
	out_reg_current_state[0]
);
and(
wire write_miss = 1'b0;
wire write_hit = 1'b0;
wire read_miss = 1'b0;
wire read_hit = 1'b0;

//logica de request
wire neg_tags_delivered;
not(neg_tags_delivered,tags_delivered);
and(request_memory_tags,compare_tag_state,neg_tags_delivered);

//trimit index la cache doar daca request_memory_tags e 1 altfel X
generate 
	genvar i;
	for(i = 0; i < 6; i = i + 1)
		begin : equal
			bufif1(index[i],wire_index[i],request_memory_tags);
		end
endgenerate

wire [3:0]out_comparatoare;
Comparator #(
	.size_data(19)
)primul_tag(
	.data_X(wire_tag),
	.data_Y(index),
	.result(out_comparatoare[0])
);

Comparator #(
	.size_data(19)
)al_doilea_tag(
	.data_X(wire_tag),
	.data_Y(index),
	.result(out_comparatoare[1])
);

Comparator #(
	.size_data(19)
)al_treilea_tag(
	.data_X(wire_tag),
	.data_Y(index),
	.result(out_comparatoare[2])
);

//										READ HIT
//VERIFICARE STARE
wire read_hit_state;

and(
	read_hit_state,//out
	neg_out_reg_current_state[2],
	out_reg_current_state[1],
	neg_out_reg_current_state[0]
);

//										READ MISS
//VERIFICARE STARE
wire read_miss_state;

	read_miss_state,//out
	neg_out_reg_current_state[2],
	out_reg_current_state[1],
	out_reg_current_state[0]
);

//										WRITE HIT
//VERIFICARE STARE
wire write_hit_state;

and(
	write_hit_state,//out
	out_reg_current_state[2],
	neg_out_reg_current_state[1],
	neg_out_reg_current_state[0]
);

//										WRITE MISS
//VERIFICARE STARE
wire write_miss_state;

and(
	write_miss_state,//out
	out_reg_current_state[2],
	neg_out_reg_current_state[1],
	out_reg_current_state[0]
);

//										  EVICT
//VERIFICARE STARE
wire evict_state;

and(
	evict_state,//out
	out_reg_current_state[2],
	out_reg_current_state[1],
	neg_out_reg_current_state[0]
);

//									TRANSITION STATES

//schimbarea tranzitilor se poate realiza identificand starile  unde biti sunt identici
//adica pentru bitul 0 vedem ca in COMPARE_TAG WRITE MISS si READ MISS observam ca sunt singurele
//stari unde lsb este 1

//transitia pt bitul 0
or(data_next_state[0],
	write_miss,			//trece in stare
	read_miss,			//trece in stare
	tranz_compare_tag,	//trece in stare
	compare_tag_state,	//pastreaza starea
	read_miss_state,	//pastreaza starea
	write_miss_state	//pastreaza starea
);

//transitia pt bitul 1
or(
	data_next_state[1],
	read_hit,		//trece in stare
	read_miss,		//trece in stare
	evict,			//trece in stare
	read_miss_state,//pastreaza starea
	read_hit_state,//pastreaza starea
	evict_state		//pastreaza starea
);

//transitia pt bitul 2
or(
	data_next_state[2],
	write_miss,		//trece in stare
	write_hit,		//trece in stare
	evict,			//trece in stare
	write_miss_state,//pastreaza starea
	write_hit_state,//pastreaza starea
	evict_state		//pastreaza starea
);
endmodule