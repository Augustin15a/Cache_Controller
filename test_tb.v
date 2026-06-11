`timescale 1ns / 1ps

module cacheController_tb;

    // --- Semnale de intrare (Regs) ---
    reg cpu_request;
    reg write_request;
    reg read_request;
    reg clk;
    reg reset;
    reg [31:0] address;
    
    reg [75:0] tags_from_cache; // 19 biți * 4 căi = 76 biți
    reg tags_delivered;
    reg block_delivered;
    reg [511:0] block_data;
    reg newBlock_delivered;
    reg block_delivered_ram;
    reg [511:0] block_data_ram;
    reg write_done_cache;
    reg [31:0] data_for_cpu_write;
    reg [1:0] lru_way;
    reg victim_dirty;
    reg [18:0] victim_tag;

    // --- Semnale de ieșire (Wires) ---
    wire request_memory_tags;
    wire [6:0] index;
    wire request_block;
    wire [1:0] way_out;
    wire [31:0] data_for_cpu;
    wire data_ready;
    wire send_block_from_ram;
    wire [511:0] block_data_ram_to_cache;
    wire [18:0] tag_to_cache;
    wire [6:0] index_to_cache;
    wire [1:0] way_to_cache;
    wire [31:0] memory_address_to_ram;
    wire request_block_ram;
    wire write_hit_semnal_cache;
    wire [31:0] data_cache;
    wire dirty_bit;
    wire [3:0] word_offset;
    wire write_done_cpu;
    wire request_write_ram;

    // --- Instanțierea UUT (Unit Under Test) ---
    cacheController uut (
        .cpu_request(cpu_request),
        .write_request(write_request),
        .read_request(read_request),
        .clk(clk),
        .reset(reset),
        .address(address),
        .tags_from_cache(tags_from_cache),
        .tags_delivered(tags_delivered),
        .request_memory_tags(request_memory_tags),
        .index(index),
        .block_delivered(block_delivered),
        .block_data(block_data),
        .request_block(request_block),
        .way_out(way_out),
        .data_for_cpu(data_for_cpu),
        .data_ready(data_ready),
        .newBlock_delivered(newBlock_delivered),
        .send_block_from_ram(send_block_from_ram),
        .block_data_ram_to_cache(block_data_ram_to_cache),
        .tag_to_cache(tag_to_cache),
        .index_to_cache(index_to_cache),
        .way_to_cache(way_to_cache),
        .block_delivered_ram(block_delivered_ram),
        .block_data_ram(block_data_ram),
        .memory_address_to_ram(memory_address_to_ram),
        .request_block_ram(request_block_ram),
        .write_done_cache(write_done_cache),
        .write_hit_semnal_cache(write_hit_semnal_cache),
        .data_cache(data_cache),
        .dirty_bit(dirty_bit),
        .word_offset(word_offset),
        .data_for_cpu_write(data_for_cpu_write),
        .write_done_cpu(write_done_cpu),
        .lru_way(lru_way),
        .victim_dirty(victim_dirty),
        .victim_tag(victim_tag),
        .request_write_ram(request_write_ram)
    );

    // --- Generare Ceas ---
    always begin
        #5 clk = ~clk;
    end

    // --- Blocul de Stimuli Complet ---
    initial begin
        // ==========================================
        // 1. INIȚIALIZARE ȘI RESET
        // ==========================================
        clk = 0;
        reset = 1;
        cpu_request = 0;
        write_request = 0;
        read_request = 0;
        address = 32'b0;
        tags_from_cache = 76'b0;
        tags_delivered = 0;
        block_delivered = 0;
        block_data = 512'b0;
        newBlock_delivered = 0;
        block_delivered_ram = 0;
        block_data_ram = 512'b0;
        write_done_cache = 0;
        data_for_cpu_write = 32'b0;
        lru_way = 2'b00;
        victim_dirty = 0;
        victim_tag = 19'b0;

        #20;
        @(negedge clk);
        reset = 0; // Scoatere din reset
        #10;

        // ==========================================
        // TEST 1: READ MISS (Bloc curat în RAM)
        // ==========================================
        $display("\n========== TEST 1: READ MISS ==========");
        @(negedge clk);
        cpu_request = 1;
        read_request = 1;
        address = 32'h00002048; // Tag căutat = 19'h00001
        
        @(negedge clk);
        cpu_request = 0;
        tags_from_cache = {19'h7FFFF, 19'h5AAAA, 19'h3CCCC, 19'h11111}; // Forțăm MISS
        tags_delivered = 1;

        @(negedge clk);
        tags_delivered = 0;
        #30; 

        @(negedge clk);
        block_delivered_ram = 1;
        block_data_ram = {16{32'hAABBCCDD}}; 

        @(negedge clk);
        block_delivered_ram = 0;
        newBlock_delivered = 1; 

        @(negedge clk);
        newBlock_delivered = 0; 
        #20;
		// ==========================================
        // TEST 2: READ HIT
        // ==========================================
        $display("\n========== TEST 2: READ HIT ==========");
        @(negedge clk);
        cpu_request = 1;
        read_request = 1;
        address = 32'h00002048; 
        
        // Generăm HIT pe Calea 2
        @(negedge clk);
        cpu_request = 0;
        tags_from_cache = {19'h7FFFF, 19'h00001, 19'h3CCCC, 19'h11111};
        tags_delivered = 1;

        @(negedge clk);
        tags_delivered = 0;
        
        // FSM a intrat în starea 010 (READ HIT) și cere blocul (request_block = 1)
        // Îi simulăm răspunsul de la Cache Array:
        @(negedge clk);
        block_delivered = 1;
        block_data = {16{32'h55667788}}; // Date fictive din Cache

        @(negedge clk);
        block_delivered = 0; // Confirmare terminată, FSM revine în IDLE
        #20;

        // ==========================================
        // TEST 3: READ MISS CU EVICT (DIRTY)
        // ==========================================
        $display("\n========== TEST 3: READ MISS CU EVICT (DIRTY) ==========");
        @(negedge clk);
        cpu_request = 1;
        read_request = 1;
        address = 32'h00004048; 
        
        @(negedge clk);
        cpu_request = 0;
        tags_from_cache = {19'h7FFFF, 19'h5AAAA, 19'h3CCCC, 19'h11111}; 
        victim_dirty = 1;       // Linia este Dirty!
        victim_tag = 19'h00009;   
        lru_way = 2'b01;        
        tags_delivered = 1;

        @(negedge clk);
        tags_delivered = 0;
        
        // FSM se duce în EVICT (110)
        @(negedge clk);
        block_delivered_ram = 1; // RAM confirmă scrierea blocului vechi

        @(negedge clk);
        block_delivered_ram = 0;
        // FSM trece automat în READ MISS (011) pentru a aduce noul bloc
        #20;
        
        @(negedge clk);
        block_delivered_ram = 1;
        block_data_ram = {16{32'h11223344}};

        @(negedge clk);
        block_delivered_ram = 0;
        newBlock_delivered = 1;

        @(negedge clk);
        newBlock_delivered = 0; 
        #20;

        // ==========================================
        // TEST 4: WRITE HIT (Scriere de la CPU)
        // ==========================================
        $display("\n========== TEST 4: WRITE HIT ==========");
        @(negedge clk);
        cpu_request = 1;
        write_request = 1; 
        read_request = 0;   // Ne asigurăm că e oprit
        victim_dirty = 0;   // <--- IMPORTANT: Oprim forțat semnalul dirty de la Testul 3!
        address = 32'h00002048; 
        data_for_cpu_write = 32'hDEADBEEF; 

        @(negedge clk);
        cpu_request = 0;
        // Punem tag-ul potrivit pe TOATE căile ca să fim 100% siguri că dă HIT pe ceva
        tags_from_cache = {19'h00001, 19'h00001, 19'h00001, 19'h00001};
        tags_delivered = 1;

        @(negedge clk);
        tags_delivered = 0;
        
        // FSM ar trebui să treacă acum corect în WRITE HIT (100)
        @(negedge clk);
        write_done_cache = 1; 

        @(negedge clk);
        write_done_cache = 0;
        
        #50;
        $display("\n========== TOATE TESTELE AU FOST EXECUTATE ==========");
        $stop;
    end

    // --- Monitorizare în consolă ---
    initial begin
        $monitor("[CLK %0d] STATE=%b | REQ_TAGS=%b TAGS_DEL=%b REQ_BLK_RAM=%b REQ_BLK=%b DATA_READY=%b | addr=%h wire_tag=%h", 
                 $time/10, uut.out_reg_current_state, request_memory_tags, tags_delivered, request_block_ram, request_block, data_ready, address, uut.wire_tag);
    end

endmodule