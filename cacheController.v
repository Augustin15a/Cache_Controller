module cacheController(
	//semnale de la cpu si spre
	input cpu_request,
	input write_request,
	input read_request,
	input clk,
	input reset,
	input [31:0]address,
	
//semnale de la cache si spre COMPARE_TAG state
	input [19*4 - 1:0]tags_from_cache,
	input tags_delivered,
	output request_memory_tags,
	output [6:0]index,
	
//semnale de la cache si spre Read HIT state
	//input de la cache
	input block_delivered,//cache ul imi spune daca a trimis| 1  = a trimis
	input [511:0]block_data,
	
	//output catre cache
	output request_block,//cer de la cache sa mi trimita blockul
	output [1:0]way_out,//al catelea din cele 4
	
	//output catre procesor
	output [31:0]data_for_cpu,//data ceruta de cpu
	output data_ready,

//semnale de la cache si ram cand Read MISS state
	//cache
	input newBlock_delivered,
	output send_block_from_ram,
	output [511:0]block_data_ram_to_cache,
	output [18:0]tag_to_cache,
	output [6:0]index_to_cache,
	output [1:0]way_to_cache,
	//ram
	input block_delivered_ram,
	input [511:0]block_data_ram,
	output [31:0]memory_address_to_ram,
	output request_block_ram,

//semnale  WRITE HIT state
	//catre cache
	//index ul il pastrez de la starea READ MISS si way
	input write_done_cache,
	output write_hit_semnal_cache,
	output [31:0]data_cache,
	output dirty_bit,
	output [3:0]word_offset,
	
	//de la cpu
	input [31:0]data_for_cpu_write,
	output write_done_cpu,
//semnale pentru starea EVICT și WRITE MISS
	//de la cache
	input [1:0] lru_way,
	input victim_dirty,
	input [18:0] victim_tag,
	// către RAM
	output request_write_ram
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
wire [2:0]state_input_cleared;
//Reset Logic
wire neg_reset;
not(neg_reset,reset);

and(state_input_cleared[0], data_next_state[0], neg_reset);
and(state_input_cleared[1], data_next_state[1], neg_reset);
and(state_input_cleared[2], data_next_state[2], neg_reset);

register #(
	.size_reg(3)
)current_state(
	.data(state_input_cleared),
	.write_data(clk),
	.out_reg(out_reg_current_state)
);

//Caz 1 reset == 1 => neq reset = 0,
// 		deci data_current_state = fiecare bit & 0, adica transform toti bitii in 0
//Caz 2 reset == 0 => neq reset = 1,
// 		deci data_current_state = fiecare bit & 1, adica ramane la fel

and(data_current_state[0],data_next_state[0],neg_reset);
and(data_current_state[1],data_next_state[1],neg_reset);
and(data_current_state[2],data_next_state[2],neg_reset);
//stari declarate ca wire
wire read_miss_state;
wire final_request_block_ram;
wire final_send_block_from_ram;

//										IDLE STATE

//VERIFICARE STARE
//in tabelul portii nor doar cand input e 0 0 outputul e 1
wire idle_state;
nor(idle_state, out_reg_current_state[0], out_reg_current_state[1], out_reg_current_state[2]);
//salvez adresa si o impart
wire [31:0]wire_address;
wire [5:0]wire_offset;
wire [6:0]wire_index;
wire [18:0]wire_tag;

wire load_address;
and(load_address, idle_state, cpu_request);
genvar i,j;
wire [31:0] address_mux_out;
generate
    for(i = 0; i < 32; i = i + 1)
        begin : addr_mux
            MUX2to1 mux_addr(
                .x(wire_address[i]),
                .y(address[i]),
                .sel(load_address),
                .out(address_mux_out[i])
            );
        end
endgenerate

wire [31:0] address_to_reg;
generate
    for(j = 0; j < 32; j = j + 1) begin : clear_address
        and(address_to_reg[j], address_mux_out[j], neg_reset);
    end
endgenerate

register #(
	.size_reg(32)
) address_reg(
    .data(address_to_reg),
    .write_data(clk),
    .out_reg(wire_address)
);
generate
	for(i = 0;i < 6; i = i + 1)
		begin : offsetblock
			buf(wire_offset[i],wire_address[i]);
		end
endgenerate

generate
	for(i = 0;i < 7; i = i + 1)
		begin : indexblock
			buf(wire_index[i],wire_address[i + 6]);
		end
endgenerate

generate
	for(i = 0;i < 19; i = i + 1)
		begin : tagblock
			buf(wire_tag[i],wire_address[i + 13]);
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

//logica de request
wire neg_tags_delivered;
not(neg_tags_delivered,tags_delivered);
and(request_memory_tags,compare_tag_state,neg_tags_delivered);

//trimit index la cache doar daca request_memory_tags e 1 altfel X
generate 
	for(i = 0; i < 7; i = i + 1)
		begin : send_to_cache1
			bufif1(index[i],wire_index[i],request_memory_tags);
		end
endgenerate

//split input tags_from_cache in 4
wire [18:0]tag_compare_in[3:0];
generate 
	for(i = 0; i < 19; i = i + 1)
		begin : split_tags
			buf(tag_compare_in[0][i],tags_from_cache[i]);
			buf(tag_compare_in[1][i],tags_from_cache[i + 19]);
			buf(tag_compare_in[2][i],tags_from_cache[i + 38]);
			buf(tag_compare_in[3][i],tags_from_cache[i + 57]);
		end
endgenerate


wire [3:0]out_comparatoare;
Comparator #(
	.size_data(19)
)primul_tag(
	.data_X(wire_tag),
	.data_Y(tag_compare_in[0]),
	.result(out_comparatoare[0])
);

Comparator #(
	.size_data(19)
)al_doilea_tag(
	.data_X(wire_tag),
	.data_Y(tag_compare_in[1]),
	.result(out_comparatoare[1])
);

Comparator #(
	.size_data(19)
)al_treilea_tag(
	.data_X(wire_tag),
	.data_Y(tag_compare_in[2]),
	.result(out_comparatoare[2])
);

Comparator #(
	.size_data(19)
)al_patrulea_tag(
	.data_X(wire_tag),
	.data_Y(tag_compare_in[3]),
	.result(out_comparatoare[3])
);

//mentinerea wayului pentru viitoare stari
wire [3:0]out_reg_comparatoare;
wire load_way;
and(load_way, compare_tag_state, tags_delivered);

wire [3:0] mux_way_out;
generate
    for(i = 0; i < 4; i = i + 1)
        begin : way_mux_block
            MUX2to1 mux_w(
                .x(out_reg_comparatoare[i]),
                .y(out_comparatoare[i]),
                .sel(load_way),
                .out(mux_way_out[i])
            );
        end
endgenerate
register #(
    .size_reg(4)
) way_hit_reg (
    .data(mux_way_out),
    .write_data(clk),
    .out_reg(out_reg_comparatoare)
);

//logica de gasire a tagului cerut
wire result_comparatoare;
or(result_comparatoare,
	out_comparatoare[0],
	out_comparatoare[1],
	out_comparatoare[2],
	out_comparatoare[3]
);
wire neg_result_comparatoare;
not(neg_result_comparatoare,result_comparatoare);

//calcul pt read si write
wire write_miss;
wire write_hit;
wire read_miss;
wire read_hit;

and(write_hit,write_request,result_comparatoare,compare_tag_state,tags_delivered);
and(write_miss,write_request,neg_result_comparatoare,compare_tag_state,tags_delivered);
and(read_hit,read_request,result_comparatoare,compare_tag_state,tags_delivered);
and(read_miss,read_request,neg_result_comparatoare,compare_tag_state,tags_delivered);

//
wire stay_compare_tag;
and(stay_compare_tag,neg_tags_delivered,compare_tag_state);

//										READ HIT
//VERIFICARE STARE
wire read_hit_state;
and(
	read_hit_state,//out
	neg_out_reg_current_state[2],
	out_reg_current_state[1],
	neg_out_reg_current_state[0]
);
//encoder pentru way_out

wire out_or1;
wire out_or2;
wire [1:0]wire_way;
or(out_or1, out_reg_comparatoare[1], out_reg_comparatoare[3]);
or(out_or2, out_reg_comparatoare[2], out_reg_comparatoare[3]);

buf(wire_way[0], out_or1);
buf(wire_way[1], out_or2);

//cer cacheului blockul
wire neg_block_delivered;
not(neg_block_delivered,block_delivered);
and(request_block,read_hit_state,neg_block_delivered);
//trimit indexul si way ul
generate 
	for(i = 0; i < 7; i = i + 1)
		begin : send_to_cache2
			bufif1(index[i],wire_index[i],request_block);
		end
endgenerate
bufif1(way_out[0], wire_way[0], read_hit_state);
bufif1(way_out[1], wire_way[1], read_hit_state);

//				LOGICA IMPLEMENTATA SI LA HIT SI MISS
//la miss trimit la cache blockul de date si ar trebuii sa revin in starea hit pentru a
//cere de la cache block ul pe care doar ce l am avut, asa ca in starea read miss cand il am 
//il trimit la cache si data de care am nevoie la cpu
//logica pt alegerea wordului din block.O sa fac mai multe muxuri care compara 2 numere a cate 32
//biti pe 4 nivele, select ul va fi wire_offset[nivel + 2  pentru ca primii 2 biti din wire_offset 
//sunt cei  byte offset]

//alegem blocul pe care sa l comparam
wire [511:0]block_input;
MUX2to1_param #(.size_data(512)) mux_block_select(
    .x(block_data),        // de la cache - READ HIT
    .y(block_data_ram),    // de la RAM   - READ MISS
    .sel(read_miss_state), // 0 = HIT, 1 = MISS
    .out(block_input)
);
wire [31:0]mux_out[14:0];

generate
    for(i = 1; i <= 4; i = i + 1)
        begin : nivel
            for(j = 1; j <= 16 >> i; j = j + 1)
                begin : mux_nivel
					if(i == 1)
						begin
							MUX2to1_param #(.size_data(32)) mux_level(
								.x(block_input[(32 * (2 * j - 1)) - 1 : 32 * (2 * j - 2)]),
								.y(block_input[(32 * (2 * j)) - 1 : 32 * (2 * j - 1)]),
								.sel(wire_offset[i + 1]),
								.out(mux_out[j - 1])
							);
						end
					else
						begin
                            MUX2to1_param #(.size_data(32)) mux_level(
                                .x(mux_out[(16 - (16 >> (i-2))) + 2*j - 2]),
                                .y(mux_out[(16 - (16 >> (i-2))) + 2*j - 1]),
                                .sel(wire_offset[i + 1]),
                                .out(mux_out[(16 - (16 >> (i-1))) + j - 1])
                            );
                        end
                end
        end
endgenerate
//logica de trimitere a wordului cerut de cpu
//datele se trimit doar atunci cand ma aflu in read hit state si blockul a fost trimis 
//de cache la mine pentru a selecta wordul cerut
wire data_ready_hit;
wire data_ready_miss;

and(data_ready_hit, read_hit_state, block_delivered);
and(data_ready_miss, read_miss_state, block_delivered_ram);
or(data_ready, data_ready_hit, data_ready_miss);

generate
	for(i = 0;i < 32;i = i + 1)
		begin : buf_mux_out_and_data_for_cpu
			bufif1(data_for_cpu[i],mux_out[14][i],data_ready);
		end
endgenerate
//conditia de a ramane in stare
wire neg_data_ready;
not(neg_data_ready, data_ready);

wire stay_read_hit;
and(stay_read_hit, read_hit_state, neg_data_ready,  neg_block_delivered);
//logica pentru a merge in idle
wire back_to_idle_from_read_hit;
and(back_to_idle_from_read_hit,read_hit_state, data_ready, block_delivered);

//										READ MISS
//VERIFICARE STARE
and(
	read_miss_state,//out
	neg_out_reg_current_state[2],
	out_reg_current_state[1],
	out_reg_current_state[0]
);
//logica pentru a trimite adresa catre ram pentru a primi blockul

wire neg_block_delivered_ram;
not(neg_block_delivered_ram, block_delivered_ram);
and(request_block_ram, read_miss_state, neg_block_delivered_ram);

generate
    for(i = 0; i < 32; i = i + 1)
        begin : send_address_to_ram
            bufif1(memory_address_to_ram[i], wire_address[i], final_request_block_ram);
        end
endgenerate

//ram a trimis blockul
wire neg_newBlock_delivered;
not(neg_newBlock_delivered,newBlock_delivered);
and(send_block_from_ram, read_miss_state, block_delivered_ram,neg_newBlock_delivered);

//trimite blockul la cache
generate
    for(i = 0; i < 512; i = i + 1)
        begin : send_block_to_cache
            bufif1(block_data_ram_to_cache[i], block_data_ram[i], final_send_block_from_ram);
        end
endgenerate

generate
    for(i = 0; i < 19; i = i + 1)
        begin : send_tag_to_cache
            bufif1(tag_to_cache[i], wire_tag[i], final_send_block_from_ram);
        end
endgenerate

generate
    for(i = 0; i < 7; i = i + 1)
        begin : send_index_to_cache
            bufif1(index_to_cache[i], wire_index[i], final_send_block_from_ram);
        end
endgenerate

bufif1(way_to_cache[0],lru_way[0], final_send_block_from_ram);
bufif1(way_to_cache[1],lru_way[1], final_send_block_from_ram);

//tranzitiile read miss 
//ramane in stare
wire stay_read_miss;
and(stay_read_miss, read_miss_state, neg_newBlock_delivered);
//trece la idle
wire back_to_idle_from_read_miss;
and(back_to_idle_from_read_miss, read_miss_state, newBlock_delivered);

//										WRITE HIT
//VERIFICARE STARE
wire write_hit_state;
and(
	write_hit_state,//out
	out_reg_current_state[2],
	neg_out_reg_current_state[1],
	neg_out_reg_current_state[0]
);
//logica pentru a trimite adresa catre cache data
wire neg_write_done_cache;
not(neg_write_done_cache, write_done_cache);
and(write_hit_semnal_cache,write_hit_state,neg_write_done_cache);

//index
generate
    for(i = 0; i < 7; i = i + 1)
        begin : send_index_write_hit
            bufif1(index[i], wire_index[i], write_hit_semnal_cache);
        end
endgenerate

//way
bufif1(way_out[0], wire_way[0], write_hit_semnal_cache);
bufif1(way_out[1], wire_way[1], write_hit_semnal_cache);

//word offset
generate
    for(i = 0; i < 4; i = i + 1)
        begin : send_word_offset_write_hit
            bufif1(word_offset[i], wire_offset[i + 2], write_hit_semnal_cache);
        end
endgenerate

//dirty bit
bufif1(dirty_bit, 1'b1, write_hit_semnal_cache);

//data de la cpu
generate
    for(i = 0; i < 32; i = i + 1)
        begin : send_data_write_hit
            bufif1(data_cache[i], data_for_cpu_write[i], write_hit_semnal_cache);
        end
endgenerate

// write done catre cpu
and(write_done_cpu, write_hit_state, write_done_cache);

//conditia de a ramane in stare
wire neg_write_done_cpu;
not(neg_write_done_cpu,write_done_cpu);
wire stay_write_hit;
and(stay_write_hit, write_hit_state, neg_write_done_cpu);

// back to idle
wire back_to_idle_from_write_hit;
and(back_to_idle_from_write_hit, write_hit_state, write_done_cache);

//										WRITE MISS
//VERIFICARE STARE
wire write_miss_state;

and(
	write_miss_state,//out
	out_reg_current_state[2],
	neg_out_reg_current_state[1],
	out_reg_current_state[0]
);
// Cerem blocul din RAM
wire request_block_ram_write_miss;
and(request_block_ram_write_miss, write_miss_state, neg_block_delivered_ram);

// cerem block de la ram
or(final_request_block_ram, request_block_ram, request_block_ram_write_miss);

// trimit blockul la cache
wire send_block_from_ram_write_miss;
and(send_block_from_ram_write_miss, write_miss_state, block_delivered_ram, neg_newBlock_delivered);

or(final_send_block_from_ram, send_block_from_ram, send_block_from_ram_write_miss);


// Tranzitiile stării WRITE MISS
//ramane in stare
wire stay_write_miss;
and(stay_write_miss, write_miss_state, neg_newBlock_delivered);

//merge la idle
wire back_to_idle_from_write_miss;
and(back_to_idle_from_write_miss, write_miss_state, newBlock_delivered);

//										  EVICT
//VERIFICARE STARE
wire evict_state;

and(
	evict_state,//out
	out_reg_current_state[2],
	out_reg_current_state[1],
	neg_out_reg_current_state[0]
);
// Cerem scriere în RAM
and(request_write_ram, evict_state, neg_block_delivered_ram);
generate
    for(i = 0; i < 7; i = i + 1)
        begin : send_index_evict
            bufif1(index[i], wire_index[i], evict_state);
        end
endgenerate
bufif1(way_out[0], lru_way[0], evict_state);
bufif1(way_out[1], lru_way[1], evict_state);

// Adresa trimisă la RAM
generate
    for(i = 0; i < 6; i = i + 1)
        begin : evict_addr_offset
            bufif1(memory_address_to_ram[i], 1'b0, request_write_ram);
        end
    for(i = 0; i < 7; i = i + 1)
        begin : evict_addr_index
            bufif1(memory_address_to_ram[i + 6], wire_index[i], request_write_ram);
        end
    for(i = 0; i < 19; i = i + 1)
        begin : evict_addr_tag
            bufif1(memory_address_to_ram[i + 13], victim_tag[i], request_write_ram);
        end
endgenerate

// mergem în READ MISS sau WRITE MISS pentru a aduce noul bloc cerut de cpu
wire evict_done = block_delivered_ram;

wire stay_evict;
and(stay_evict, evict_state, neg_block_delivered_ram);

wire evict_to_read_miss;
and(evict_to_read_miss, evict_state, evict_done, read_request);

wire evict_to_write_miss;
and(evict_to_write_miss, evict_state, evict_done, write_request);

//									TRANSITION STATES

//schimbarea tranzitilor se poate realiza identificand starile  unde biti sunt identici
//adica pentru bitul 0 vedem ca in COMPARE_TAG WRITE MISS si READ MISS observam ca sunt singurele
//stari unde lsb este 1

//logica de intoarcere in idle,se intampla la hit si fsm ul revine la starea de asteptare,
//pentru a face asta o sa am o variabila back_to_idle_from_read_hit care daca e 1 starea se face  000

wire back_to_idle;
or(
	back_to_idle,
	back_to_idle_from_read_hit,
	back_to_idle_from_read_miss,
	back_to_idle_from_write_hit,
	back_to_idle_from_write_miss
);

wire neg_back_to_idle;
not(neg_back_to_idle,back_to_idle);

//tranzitii la stari
wire neg_victim_dirty;
not(neg_victim_dirty, victim_dirty);
wire go_to_evict;
and(
	go_to_evict,
	compare_tag_state,
	tags_delivered,
	neg_result_comparatoare,
	victim_dirty
);

wire go_to_read_miss;
and(
	go_to_read_miss,
	compare_tag_state,
	tags_delivered,
	neg_result_comparatoare,
	read_request,
	neg_victim_dirty
);

wire go_to_write_miss;
and(
	go_to_write_miss,
	compare_tag_state,
	tags_delivered,
	neg_result_comparatoare,
	write_request,
	neg_victim_dirty
);

//tranzitia pt bitul 0
wire [2:0]wire_data_next_state;
or(
	wire_data_next_state[0],
	tranz_compare_tag,
	stay_compare_tag,
	go_to_read_miss,
	go_to_write_miss,
	evict_to_read_miss,
	evict_to_write_miss,
	stay_read_miss,
	stay_write_miss
);
and(data_next_state[0],wire_data_next_state[0],neg_back_to_idle);
//tranzitia pt bitul 1
or(
	wire_data_next_state[1],
	read_hit,
	go_to_read_miss,
	go_to_evict,
	evict_to_read_miss,
	stay_read_hit,
	stay_read_miss,
	stay_evict
);
and(data_next_state[1],wire_data_next_state[1],neg_back_to_idle);
//tranzitia pt bitul 2
or(
	wire_data_next_state[2],
	write_hit,
	go_to_write_miss,
	go_to_evict,
	evict_to_write_miss,
	stay_write_hit,
	stay_write_miss,
	stay_evict
);
and(data_next_state[2],wire_data_next_state[2],neg_back_to_idle);
endmodule